import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../models/survey_question.dart';

/// Persist Path A spend + survey (Phase 3) and gate readiness for match.
class IntakeService {
  IntakeService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Not signed in');
    }
    return id;
  }

  /// Ensure a session row exists for this confirmed lab document.
  Future<PathASession> ensureSessionForLab({required String labDocumentId}) async {
    final uid = _uid;
    final existing = await _client
        .from('path_a_sessions')
        .select()
        .eq('lab_document_id', labDocumentId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      return _hydrate(Map<String, dynamic>.from(existing));
    }

    final inserted = await _client
        .from('path_a_sessions')
        .insert(<String, dynamic>{
          'user_id': uid,
          'lab_document_id': labDocumentId,
        })
        .select()
        .single();

    return PathASession.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<PathASession?> fetchLatestSession() async {
    final uid = _uid;
    final row = await _client
        .from('path_a_sessions')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _hydrate(Map<String, dynamic>.from(row));
  }

  Future<PathASession?> fetchSession(String sessionId) async {
    final uid = _uid;
    final row = await _client
        .from('path_a_sessions')
        .select()
        .eq('id', sessionId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return _hydrate(Map<String, dynamic>.from(row));
  }

  /// Replace spend selections (≥1 required) and mark spend complete.
  Future<PathASession> saveSpend({
    required String sessionId,
    required Set<SpendBucket> buckets,
  }) async {
    if (buckets.isEmpty) {
      throw ArgumentError('Select at least one spend category');
    }
    final uid = _uid;
    final now = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('path_a_spend_selections')
        .delete()
        .eq('session_id', sessionId)
        .eq('user_id', uid);

    await _client.from('path_a_spend_selections').insert(
          buckets
              .map(
                (b) => <String, dynamic>{
                  'session_id': sessionId,
                  'user_id': uid,
                  'spend_bucket': b.dbValue,
                },
              )
              .toList(),
        );

    await _client.from('path_a_sessions').update(<String, dynamic>{
      'spend_completed_at': now,
      'updated_at': now,
    }).eq('id', sessionId).eq('user_id', uid);

    final session = await fetchSession(sessionId);
    if (session == null) {
      throw StateError('Session missing after spend save');
    }
    return session;
  }

  /// Persist all survey answers (must cover every locked question) and mark complete.
  Future<PathASession> saveSurvey({
    required String sessionId,
    required Map<String, String> answers,
  }) async {
    for (final q in kSurveyQuestions) {
      final a = answers[q.key]?.trim();
      if (a == null || a.isEmpty) {
        throw ArgumentError('Missing answer for ${q.key}');
      }
      if (!q.options.contains(a)) {
        throw ArgumentError('Invalid answer for ${q.key}');
      }
    }
    if (answers.length != kSurveyQuestions.length) {
      throw ArgumentError('Survey must answer exactly ${kSurveyQuestions.length} questions');
    }

    final uid = _uid;
    final now = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('path_a_survey_answers')
        .delete()
        .eq('session_id', sessionId)
        .eq('user_id', uid);

    await _client.from('path_a_survey_answers').insert(
          kSurveyQuestions
              .map(
                (q) => <String, dynamic>{
                  'session_id': sessionId,
                  'user_id': uid,
                  'question_key': q.key,
                  'answer': answers[q.key]!.trim(),
                  'updated_at': now,
                },
              )
              .toList(),
        );

    await _client.from('path_a_sessions').update(<String, dynamic>{
      'survey_completed_at': now,
      'updated_at': now,
    }).eq('id', sessionId).eq('user_id', uid);

    final session = await fetchSession(sessionId);
    if (session == null) {
      throw StateError('Session missing after survey save');
    }
    return session;
  }

  /// True only when linked labs are confirmed and spend + survey are complete.
  Future<bool> isReadyForMatch(String sessionId) async {
    final session = await fetchSession(sessionId);
    if (session == null || !session.readyForMatch) return false;
    return labsConfirmedForSession(session);
  }

  /// Labs must be confirmed before match (Phase 3.3 gate).
  Future<bool> labsConfirmedForSession(PathASession session) async {
    final uid = _uid;
    final row = await _client
        .from('lab_documents')
        .select('status')
        .eq('id', session.labDocumentId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return false;
    return (row['status']?.toString() ?? '') == 'confirmed';
  }

  Future<PathASession> _hydrate(Map<String, dynamic> row) async {
    final sessionId = row['id'].toString();
    final uid = _uid;

    final spendRows = await _client
        .from('path_a_spend_selections')
        .select('spend_bucket')
        .eq('session_id', sessionId)
        .eq('user_id', uid);

    final buckets = <SpendBucket>[];
    for (final r in spendRows as List<dynamic>) {
      final parsed = SpendBucket.tryParse(
        Map<String, dynamic>.from(r as Map)['spend_bucket']?.toString(),
      );
      if (parsed != null) buckets.add(parsed);
    }

    final answerRows = await _client
        .from('path_a_survey_answers')
        .select('question_key, answer')
        .eq('session_id', sessionId)
        .eq('user_id', uid);

    final answers = <String, String>{};
    for (final r in answerRows as List<dynamic>) {
      final m = Map<String, dynamic>.from(r as Map);
      final key = m['question_key']?.toString();
      final answer = m['answer']?.toString();
      if (key != null && answer != null) {
        answers[key] = answer;
      }
    }

    return PathASession.fromJson(
      row,
      spendBuckets: buckets,
      surveyAnswers: answers,
    );
  }
}
