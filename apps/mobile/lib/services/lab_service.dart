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

  static const String signedOutMessage =
      "You're signed out. Sign in again to upload your lab PDF.";

  /// Refresh when the access token is missing, already expired, or within
  /// [skewSeconds] of expiry so Storage / Edge Function JWT checks pass.
  static const int refreshSkewSeconds = 60;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError(signedOutMessage);
    }
    return id;
  }

  /// True when Storage rejected the request because the JWT `exp` claim is stale.
  static bool isExpiredJwtStorageError(Object error) {
    if (error is! StorageException) return false;
    final code = error.statusCode;
    final msg = error.message.toLowerCase();
    final unauthorized = error.error?.toLowerCase() == 'unauthorized' ||
        code == '403' ||
        code == '401';
    final expClaim = msg.contains('exp') &&
        (msg.contains('timestamp') || msg.contains('claim'));
    return unauthorized && (expClaim || msg.contains('jwt'));
  }

  /// Map auth / expired-JWT failures to a short user-facing line.
  static String userFacingError(Object error) {
    if (error is StateError && error.message == signedOutMessage) {
      return signedOutMessage;
    }
    if (error is AuthException) {
      return signedOutMessage;
    }
    if (isExpiredJwtStorageError(error)) {
      return signedOutMessage;
    }
    if (error is StorageException) {
      final code = error.statusCode;
      if (code == '401' || code == '403') {
        return signedOutMessage;
      }
    }
    return error.toString();
  }

  Future<void> ensureFreshSession({bool force = false}) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError(signedOutMessage);
    }

    final expiresAt = session.expiresAt;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final stale =
        expiresAt == null || expiresAt <= nowSec + refreshSkewSeconds;
    if (!force && !stale) {
      return;
    }

    try {
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session == null && _client.auth.currentSession == null) {
        throw StateError(signedOutMessage);
      }
    } on AuthException {
      throw StateError(signedOutMessage);
    }
  }

  Future<T> _withFreshAuth<T>(Future<T> Function() action) async {
    await ensureFreshSession();
    try {
      return await action();
    } on StorageException catch (error) {
      if (!isExpiredJwtStorageError(error)) {
        rethrow;
      }
      // Access token went stale mid-flow — force refresh and retry once.
      await ensureFreshSession(force: true);
      try {
        return await action();
      } on StorageException catch (retryError) {
        if (isExpiredJwtStorageError(retryError) ||
            retryError.statusCode == '401' ||
            retryError.statusCode == '403') {
          throw StateError(signedOutMessage);
        }
        rethrow;
      }
    }
  }

  /// Upload PDF bytes under `{uid}/{documentId}.pdf`, insert `lab_documents`,
  /// invoke extract-lab-pdf, return document + biomarker rows.
  Future<({LabDocument document, List<LabBiomarker> biomarkers})> uploadAndExtract({
    required Uint8List bytes,
    required String originalFilename,
  }) async {
    await ensureFreshSession();
    final uid = _uid;
    final documentId = _uuid.v4();
    final storagePath = '$uid/$documentId.pdf';

    await _withFreshAuth(() {
      return _client.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );
    });

    await ensureFreshSession();
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

    await ensureFreshSession();
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
    await ensureFreshSession();
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
