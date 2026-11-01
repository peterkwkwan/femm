import '../models/clinical_specialty.dart';
import '../models/lab_biomarker.dart';
import '../models/match_result.dart';

/// Deterministic survey (+ optional flagged labs) → specialty + canned why-copy.
/// No LLM. Pure Dart so it can be unit-tested offline.
class MatchEngine {
  const MatchEngine();

  /// Biomarker name substrings that nudge bone/heart when flagged H/L.
  static const List<String> boneHeartNameHints = <String>[
    'ldl',
    'hdl',
    'cholesterol',
    'triglyceride',
    'glucose',
    'hba1c',
    'calcium',
    'vitamin d',
    'vit d',
    'alp',
    'alkaline phosphatase',
  ];

  /// Biomarker name substrings that nudge gynae/endocrine when flagged H/L.
  static const List<String> gynaeNameHints = <String>[
    'fsh',
    'lh',
    'estradiol',
    'oestradiol',
    'progesterone',
    'amh',
    'tsh',
    'free t4',
    'testosterone',
  ];

  MatchRecommendation recommend({
    required Map<String, String> surveyAnswers,
    List<LabBiomarker> biomarkers = const <LabBiomarker>[],
  }) {
    final scores = <ClinicalSpecialty, int>{
      for (final s in ClinicalSpecialty.values) s: 0,
    };
    final reasons = <ClinicalSpecialty, List<String>>{
      for (final s in ClinicalSpecialty.values) s: <String>[],
    };

    void bump(ClinicalSpecialty s, int points, String reason) {
      scores[s] = (scores[s] ?? 0) + points;
      if (reason.isNotEmpty) {
        reasons[s]!.add(reason);
      }
    }

    final primary = surveyAnswers['primary_goal'] ?? '';
    switch (primary) {
      case 'General midlife / menopause navigation':
        bump(
          ClinicalSpecialty.menopauseAwareGp,
          10,
          'Your primary goal is general midlife / menopause navigation.',
        );
      case 'Hormones / cycle / gynae review':
        bump(
          ClinicalSpecialty.gynaeEndocrine,
          10,
          'Your primary goal is hormones / cycle / gynae review.',
        );
      case 'Sleep or mood':
        bump(
          ClinicalSpecialty.sleepMood,
          10,
          'Your primary goal is sleep or mood support.',
        );
      case 'Bone or heart risk concerns':
        bump(
          ClinicalSpecialty.boneHeartRisk,
          10,
          'Your primary goal is bone or heart risk discussion.',
        );
      default:
        bump(
          ClinicalSpecialty.menopauseAwareGp,
          4,
          'Defaulting toward menopause-aware GP for general care-navigation.',
        );
    }

    final hot = surveyAnswers['hot_flushes'] ?? '';
    if (hot == 'Severe' || hot == 'Moderate') {
      bump(
        ClinicalSpecialty.menopauseAwareGp,
        hot == 'Severe' ? 3 : 2,
        'Hot flushes / night sweats are ${hot.toLowerCase()}.',
      );
    }

    final sleep = surveyAnswers['sleep'] ?? '';
    if (sleep == 'Consistently difficult' || sleep == 'Often poor') {
      bump(
        ClinicalSpecialty.sleepMood,
        sleep == 'Consistently difficult' ? 4 : 3,
        'Sleep is ${sleep.toLowerCase()}.',
      );
    }

    final mood = surveyAnswers['mood'] ?? '';
    if (mood == 'A main concern' || mood == 'Often affected') {
      bump(
        ClinicalSpecialty.sleepMood,
        mood == 'A main concern' ? 4 : 3,
        'Mood / anxiety is ${mood.toLowerCase()}.',
      );
    }

    final cycle = surveyAnswers['cycle_bleeding'] ?? '';
    if (cycle == 'Urgent to discuss' || cycle == 'Noticeable changes') {
      bump(
        ClinicalSpecialty.gynaeEndocrine,
        cycle == 'Urgent to discuss' ? 5 : 3,
        'Cycle / bleeding changes: ${cycle.toLowerCase()}.',
      );
    }

    final boneHeart = surveyAnswers['bone_heart'] ?? '';
    if (boneHeart == 'Labs already flagged concern' ||
        boneHeart == 'Yes, a priority') {
      bump(
        ClinicalSpecialty.boneHeartRisk,
        boneHeart == 'Labs already flagged concern' ? 5 : 4,
        'Bone / heart risk is a stated priority.',
      );
    }

    // Optional lab flags: H/L only when present — never invent meaning.
    final flagged = biomarkers
        .where(
          (b) =>
              !b.isDeleted &&
              b.flag != null &&
              (b.flag == 'H' || b.flag == 'L'),
        )
        .toList();

    for (final row in flagged) {
      final name = row.name.toLowerCase();
      if (boneHeartNameHints.any(name.contains)) {
        bump(
          ClinicalSpecialty.boneHeartRisk,
          2,
          'A flagged lab row mentions ${row.name} (${row.flag}).',
        );
      }
      if (gynaeNameHints.any(name.contains)) {
        bump(
          ClinicalSpecialty.gynaeEndocrine,
          2,
          'A flagged lab row mentions ${row.name} (${row.flag}).',
        );
      }
    }

    // Deterministic tie-break: highest score, then specialty enum order.
    ClinicalSpecialty best = ClinicalSpecialty.menopauseAwareGp;
    var bestScore = -1;
    for (final s in ClinicalSpecialty.values) {
      final score = scores[s] ?? 0;
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }

    final why = _cannedWhy(
      specialty: best,
      bulletReasons: reasons[best] ?? const <String>[],
    );

    return MatchRecommendation(specialty: best, whyCopy: why);
  }

  String _cannedWhy({
    required ClinicalSpecialty specialty,
    required List<String> bulletReasons,
  }) {
    final lead = switch (specialty) {
      ClinicalSpecialty.menopauseAwareGp =>
        'Matched to a menopause-aware GP for first-line midlife care-navigation.',
      ClinicalSpecialty.gynaeEndocrine =>
        'Matched to gynae / endocrine review for hormonal and reproductive history.',
      ClinicalSpecialty.sleepMood =>
        'Matched to a sleep / mood consult based on your survey priorities.',
      ClinicalSpecialty.boneHeartRisk =>
        'Matched to a bone / heart risk consult based on your goals and any flagged labs.',
    };

    final unique = <String>[];
    for (final r in bulletReasons) {
      if (!unique.contains(r)) unique.add(r);
    }
    final detail = unique.take(3).join(' ');
    if (detail.isEmpty) {
      return '$lead This is care-navigation only — not a diagnosis.';
    }
    return '$lead $detail This is care-navigation only — not a diagnosis.';
  }
}
