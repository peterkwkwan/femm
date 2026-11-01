import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/lab_biomarker.dart';

/// Storage upload + Edge Function extract + confirm persistence (Phase 2).
class LabService {
  LabService({SupabaseClient? client, Uuid? uuid})
      : _client = client ?? Supabase.instance.client,
        _uuid = uuid ?? const Uuid();

  final SupabaseClient _client;
  final Uuid _uuid;

  static const String bucket = 'lab-pdfs';
  static const String extractFunction = 'extract-lab-pdf';

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Not signed in');
    }
    return id;
  }

  /// Upload PDF bytes under `{uid}/{documentId}.pdf`, insert `lab_documents`,
  /// invoke extract-lab-pdf, return document + biomarker rows.
  Future<({LabDocument document, List<LabBiomarker> biomarkers})> uploadAndExtract({
    required Uint8List bytes,
    required String originalFilename,
  }) async {
    final uid = _uid;
    final documentId = _uuid.v4();
    final storagePath = '$uid/$documentId.pdf';

    await _client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
          ),
        );

    final inserted = await _client
        .from('lab_documents')
        .insert(<String, dynamic>{
          'id': documentId,
          'user_id': uid,
          'storage_path': storagePath,
          'original_filename': originalFilename,
          'status': 'uploaded',
        })
        .select()
        .single();

    final document = LabDocument.fromJson(inserted);

    final response = await _client.functions.invoke(
      extractFunction,
      body: <String, dynamic>{'document_id': documentId},
    );

    if (response.status >= 400) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Extract failed (HTTP ${response.status})';
      throw StateError(message);
    }

    final biomarkers = await fetchBiomarkers(documentId);
    final refreshed = await fetchDocument(documentId) ?? document;
    return (document: refreshed, biomarkers: biomarkers);
  }

  Future<LabDocument?> fetchDocument(String documentId) async {
    final row = await _client
        .from('lab_documents')
        .select()
        .eq('id', documentId)
        .maybeSingle();
    if (row == null) return null;
    return LabDocument.fromJson(row);
  }

  Future<List<LabBiomarker>> fetchBiomarkers(String documentId) async {
    final rows = await _client
        .from('lab_biomarker_rows')
        .select()
        .eq('lab_document_id', documentId)
        .eq('is_deleted', false)
        .order('sort_order');
    return (rows as List<dynamic>)
        .map((e) => LabBiomarker.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Persist edited rows (including soft-deletes) and mark document confirmed.
  Future<void> confirmLabs({
    required String documentId,
    required List<LabBiomarker> rows,
  }) async {
    final uid = _uid;
    final now = DateTime.now().toUtc().toIso8601String();

    for (final row in rows) {
      if (row.id == null) continue;
      await _client.from('lab_biomarker_rows').update(<String, dynamic>{
        'name': row.name,
        'value': row.value,
        'unit': row.unit,
        'ref_range': row.refRange,
        'flag': row.flag,
        'is_deleted': row.isDeleted,
        'sort_order': row.sortOrder,
        'updated_at': now,
      }).eq('id', row.id!).eq('user_id', uid);
    }

    await _client.from('lab_documents').update(<String, dynamic>{
      'status': 'confirmed',
      'confirmed_at': now,
      'updated_at': now,
    }).eq('id', documentId).eq('user_id', uid);
  }
}
