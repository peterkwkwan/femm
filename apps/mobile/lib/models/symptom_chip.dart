import 'clinical_specialty.dart';

/// Menopause-relevant symptom chip for Path A multi-select (replaces ≤8 Q survey).
class SymptomChip {
  const SymptomChip({
    required this.key,
    required this.label,
    required this.specialtyWeights,
  });

  final String key;
  final String label;

  /// Rule-based match weights keyed by specialty dbValue / enum.
  final Map<ClinicalSpecialty, int> specialtyWeights;

  static SymptomChip? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final c in kSymptomChips) {
      if (c.key == raw) return c;
    }
    return null;
  }
}

/// Meta row stored alongside chips so Path C still has a primary goal string.
const String kPrimaryGoalAnswerKey = 'primary_goal';

/// Locked menopause-relevant chips shown on the symptoms step.
const List<SymptomChip> kSymptomChips = <SymptomChip>[
  SymptomChip(
    key: 'hot_flushes',
    label: 'Hot flushes',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 3,
    },
  ),
  SymptomChip(
    key: 'night_sweats',
    label: 'Night sweats',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 3,
    },
  ),
  SymptomChip(
    key: 'poor_sleep',
    label: 'Poor sleep',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.sleepMood: 4,
    },
  ),
  SymptomChip(
    key: 'mood',
    label: 'Mood / anxiety / irritability',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.sleepMood: 4,
    },
  ),
  SymptomChip(
    key: 'brain_fog',
    label: 'Brain fog',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 2,
    },
  ),
  SymptomChip(
    key: 'fatigue',
    label: 'Fatigue',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 2,
    },
  ),
  SymptomChip(
    key: 'cycle_bleeding',
    label: 'Cycle / bleeding changes',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.gynaeEndocrine: 5,
    },
  ),
  SymptomChip(
    key: 'vaginal_dryness',
    label: 'Vaginal dryness',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.gynaeEndocrine: 3,
    },
  ),
  SymptomChip(
    key: 'low_libido',
    label: 'Low libido',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.gynaeEndocrine: 2,
    },
  ),
  SymptomChip(
    key: 'joint_aches',
    label: 'Joint / muscle aches',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 2,
    },
  ),
  SymptomChip(
    key: 'weight_changes',
    label: 'Weight changes',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 2,
    },
  ),
  SymptomChip(
    key: 'skin',
    label: 'Skin changes',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 1,
    },
  ),
  SymptomChip(
    key: 'hair',
    label: 'Hair thinning',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.menopauseAwareGp: 1,
    },
  ),
  SymptomChip(
    key: 'bone_heart',
    label: 'Bone or heart concerns',
    specialtyWeights: <ClinicalSpecialty, int>{
      ClinicalSpecialty.boneHeartRisk: 5,
    },
  ),
];

/// Human primary-goal label derived from the winning specialty (Path C).
String primaryGoalForSpecialty(ClinicalSpecialty specialty) {
  return switch (specialty) {
    ClinicalSpecialty.menopauseAwareGp =>
      'General midlife / menopause navigation',
    ClinicalSpecialty.gynaeEndocrine => 'Hormones / cycle / gynae review',
    ClinicalSpecialty.sleepMood => 'Sleep or mood',
    ClinicalSpecialty.boneHeartRisk => 'Bone or heart risk concerns',
  };
}

/// Selected chip keys present in persisted survey_answers (excludes meta).
Set<String> selectedSymptomKeysFromAnswers(Map<String, String> answers) {
  final keys = <String>{};
  for (final entry in answers.entries) {
    if (entry.key == kPrimaryGoalAnswerKey) continue;
    if (entry.value.trim().isEmpty) continue;
    if (SymptomChip.tryParse(entry.key) != null) {
      keys.add(entry.key);
    }
  }
  return keys;
}

List<String> selectedSymptomLabelsFromAnswers(Map<String, String> answers) {
  final labels = <String>[];
  for (final chip in kSymptomChips) {
    final value = answers[chip.key]?.trim();
    if (value != null && value.isNotEmpty) {
      labels.add(chip.label);
    }
  }
  return labels;
}
