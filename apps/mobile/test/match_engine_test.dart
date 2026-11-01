import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/models/lab_biomarker.dart';
import 'package:femm_app/models/symptom_chip.dart';
import 'package:femm_app/services/match_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _answers(List<String> keys) {
  final out = <String, String>{};
  for (final key in keys) {
    final chip = SymptomChip.tryParse(key);
    expect(chip, isNotNull, reason: 'unknown chip $key');
    out[key] = chip!.label;
  }
  return out;
}

void main() {
  const engine = MatchEngine();

  test('hot flushes / night sweats map toward menopause-aware GP', () {
    final r = engine.recommend(
      surveyAnswers: _answers(const <String>['hot_flushes', 'night_sweats']),
    );
    expect(r.specialty, ClinicalSpecialty.menopauseAwareGp);
    expect(r.whyCopy.toLowerCase(), contains('not a diagnosis'));
  });

  test('poor sleep + mood map to sleep_mood', () {
    final r = engine.recommend(
      surveyAnswers: _answers(const <String>['poor_sleep', 'mood']),
    );
    expect(r.specialty, ClinicalSpecialty.sleepMood);
  });

  test('cycle / bleeding maps to gynae_endocrine', () {
    final r = engine.recommend(
      surveyAnswers: _answers(const <String>['cycle_bleeding']),
    );
    expect(r.specialty, ClinicalSpecialty.gynaeEndocrine);
  });

  test('bone/heart chip + flagged lipid lab stay on bone_heart_risk', () {
    final r = engine.recommend(
      surveyAnswers: _answers(const <String>['bone_heart']),
      biomarkers: <LabBiomarker>[
        LabBiomarker(
          sortOrder: 0,
          name: 'LDL Cholesterol',
          value: 4.2,
          unit: 'mmol/L',
          flag: 'H',
        ),
      ],
    );
    expect(r.specialty, ClinicalSpecialty.boneHeartRisk);
    expect(r.whyCopy, contains('LDL'));
  });

  test('flagged lipid lab can nudge bone_heart without that chip', () {
    final r = engine.recommend(
      surveyAnswers: _answers(const <String>['fatigue']),
      biomarkers: <LabBiomarker>[
        LabBiomarker(
          sortOrder: 0,
          name: 'LDL Cholesterol',
          value: 4.2,
          unit: 'mmol/L',
          flag: 'H',
        ),
      ],
    );
    expect(r.specialty, ClinicalSpecialty.boneHeartRisk);
  });

  test('why-copy is canned and non-empty', () {
    final r = engine.recommend(
      surveyAnswers: _answers(const <String>['bone_heart', 'joint_aches']),
    );
    expect(r.specialty, ClinicalSpecialty.boneHeartRisk);
    expect(r.whyCopy.length, greaterThan(40));
    expect(r.whyCopy, isNot(contains('LLM')));
  });

  test('primaryGoalForSpecialty covers all specialties', () {
    for (final s in ClinicalSpecialty.values) {
      expect(primaryGoalForSpecialty(s), isNotEmpty);
    }
  });
}
