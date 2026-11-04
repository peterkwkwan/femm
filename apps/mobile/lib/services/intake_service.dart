import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/investor_demo_auth.dart';
import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import '../models/symptom_chip.dart';
import 'match_engine.dart';

/// Persist Path A spend + symptoms and gate readiness for match.
class IntakeService {
  IntakeService({SupabaseClient? client, MatchEngine matchEngine = const MatchEngine()})
      : _client = client ?? Supabase.instance.client,
        _matchEngine = matchEngine;

  final SupabaseClient _client;
  final MatchEngine _matchEngine;

  /// TEMP / investor-demo: in-memory sessions when there is no Supabase JWT.
  /// Static so Path A screens that recreate [IntakeService] still share state.
  static final Map<String, PathASession> _demoSessionsById =
      <String, PathASession>{};
  static final Map<String, String> _demoSessionIdByLabDoc = <String, String>{};

  /// Test / reset helper for the investor-demo in-memory store.
  static void clearInvestorDemoStore() {
    _demoSessionsById.clear();
    _demoSessionIdByLabDoc.clear();
    clearInvestorDemoLabConfirmStore();
  }

  bool get _offline => isInvestorDemoOffline(_client);

  String get _uid => resolveDemoOrAuthUserId(_client);

  /// Ensure a session row exists for this confirmed lab document.
  Future<PathASession> ensureSessionForLab({required String labDocumentId}) async {
    if (_offline) {
      final existingId = _demoSessionIdByLabDoc[labDocumentId];
      if (existingId != null) {
        final existing = _demoSessionsById[existingId];
        if (existing != null) return existing;
      }
      // Confirm labs is local offline — treat ensure as confirm+session.
      markInvestorDemoLabConfirmed(labDocumentId);
      final session = buildInvestorDemoSession(labDocumentId: labDocumentId);
      _demoSessionsById[session.id] = session;
      _demoSessionIdByLabDoc[labDocumentId] = session.id;
      return session;
    }

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
    if (_offline) {
      if (_demoSessionsById.isEmpty) return null;
      return _demoSessionsById.values.last;
    }

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
    if (_offline) {
      return _demoSessionsById[sessionId];
    }

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

    if (_offline) {
      final prior = _demoSessionsById[sessionId];
      if (prior == null) {
        throw StateError('Session missing after spend save');
      }
      final updated = PathASession(
        id: prior.id,
        labDocumentId: prior.labDocumentId,
        spendCompletedAt: DateTime.now().toUtc(),
        surveyCompletedAt: prior.surveyCompletedAt,
        spendBuckets: buckets.toList(),
        surveyAnswers: prior.surveyAnswers,
      );
      _demoSessionsById[sessionId] = updated;
      return updated;
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

  /// Persist selected symptom chips into `path_a_survey_answers` and mark complete.
  ///
  /// Storage map (reuse existing table, no new columns):
  /// - one row per selected chip: `question_key` = chip key, `answer` = chip label
  /// - one `primary_goal` row derived from the rule-based specialty for Path C
  Future<PathASession> saveSymptoms({
    required String sessionId,
    required Set<String> selectedKeys,
  }) async {
    if (selectedKeys.isEmpty) {
      throw ArgumentError('Select at least one symptom');
    }

    final chips = <SymptomChip>[];
    for (final key in selectedKeys) {
      final chip = SymptomChip.tryParse(key);
      if (chip == null) {
        throw ArgumentError('Unknown symptom chip: $key');
      }
      chips.add(chip);
    }
    // Stable insert order matching locked chip list.
    chips.sort(
      (a, b) => kSymptomChips
          .indexWhere((c) => c.key == a.key)
          .compareTo(kSymptomChips.indexWhere((c) => c.key == b.key)),
    );

    final provisionalAnswers = <String, String>{
      for (final chip in chips) chip.key: chip.label,
    };
    final recommendation = _matchEngine.recommend(
      surveyAnswers: provisionalAnswers,
    );
    provisionalAnswers[kPrimaryGoalAnswerKey] =
        primaryGoalForSpecialty(recommendation.specialty);

    if (_offline) {
      final prior = _demoSessionsById[sessionId];
      if (prior == null) {
        throw StateError('Session missing after symptoms save');
      }
      final updated = PathASession(
        id: prior.id,
        labDocumentId: prior.labDocumentId,
        spendCompletedAt: prior.spendCompletedAt,
        surveyCompletedAt: DateTime.now().toUtc(),
        spendBuckets: prior.spendBuckets,
        surveyAnswers: provisionalAnswers,
      );
      _demoSessionsById[sessionId] = updated;
      return updated;
    }

    final uid = _uid;
    final now = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('path_a_survey_answers')
        .delete()
        .eq('session_id', sessionId)
        .eq('user_id', uid);

    await _client.from('path_a_survey_answers').insert(
          provisionalAnswers.entries
              .map(
                (e) => <String, dynamic>{
                  'session_id': sessionId,
                  'user_id': uid,
                  'question_key': e.key,
                  'answer': e.value,
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
      throw StateError('Session missing after symptoms save');
    }
    return session;
  }

  /// True only when linked labs are confirmed and spend + symptoms are complete.
  Future<bool> isReadyForMatch(String sessionId) async {
    final session = await fetchSession(sessionId);
    if (session == null || !session.readyForMatch) return false;
    return labsConfirmedForSession(session);
  }

  /// Labs must be confirmed before match (Phase 3.3 gate).
  Future<bool> labsConfirmedForSession(PathASession session) async {
    if (_offline) {
      return isInvestorDemoLabConfirmed(session.labDocumentId);
    }

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
