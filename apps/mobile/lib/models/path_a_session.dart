import 'spend_bucket.dart';

/// Path A intake session after labs confirm (Phase 3).
class PathASession {
  PathASession({
    required this.id,
    required this.labDocumentId,
    this.spendCompletedAt,
    this.surveyCompletedAt,
    this.spendBuckets = const <SpendBucket>[],
    this.surveyAnswers = const <String, String>{},
  });

  final String id;
  final String labDocumentId;
  final DateTime? spendCompletedAt;
  final DateTime? surveyCompletedAt;
  final List<SpendBucket> spendBuckets;
  final Map<String, String> surveyAnswers;

  bool get hasSpend => spendCompletedAt != null && spendBuckets.isNotEmpty;

  bool get hasSurvey =>
      surveyCompletedAt != null && surveyAnswers.isNotEmpty;

  /// Match (Phase 4) may start only when spend + survey are done.
  bool get readyForMatch => hasSpend && hasSurvey;

  factory PathASession.fromJson(
    Map<String, dynamic> json, {
    List<SpendBucket> spendBuckets = const <SpendBucket>[],
    Map<String, String> surveyAnswers = const <String, String>{},
  }) {
    return PathASession(
      id: json['id'].toString(),
      labDocumentId: json['lab_document_id'].toString(),
      spendCompletedAt: _parseTs(json['spend_completed_at']),
      surveyCompletedAt: _parseTs(json['survey_completed_at']),
      spendBuckets: spendBuckets,
      surveyAnswers: surveyAnswers,
    );
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}
