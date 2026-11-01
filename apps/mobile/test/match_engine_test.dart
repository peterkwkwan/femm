import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/models/lab_biomarker.dart';
import 'package:femm_app/services/match_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _baseAnswers({
  String primary = 'General midlife / menopause navigation',
  String sleep = 'Fine',
  String mood = 'Stable',
  String cycle = 'No / not relevant',
  String boneHeart = 'Not now',
  String hot = 'Not an issue',
}) {
  return <String, String>{
    'primary_goal': primary,
    'hot_flushes': hot,
    'sleep': sleep,
    'mood': mood,
    'cycle_bleeding': cycle,
    'bone_heart': boneHeart,
    'skin': 'None',
    'hair': 'None',
  };
}

void main() {
  const engine = MatchEngine();

  test('primary goal maps to menopause-aware GP', () {
    final r = engine.recommend(surveyAnswers: _baseAnswers());
    expect(r.specialty, ClinicalSpecialty.menopauseAwareGp);
    expect(r.whyCopy.toLowerCase(), contains('not a diagnosis'));
  });

  test('primary sleep/mood maps to sleep_mood', () {
    final r = engine.recommend(
      surveyAnswers: _baseAnswers(primary: 'Sleep or mood'),
    );
    expect(r.specialty, ClinicalSpecialty.sleepMood);
  });

  test('urgent cycle overrides toward gynae when primary is general', () {
    final r = engine.recommend(
      surveyAnswers: _baseAnswers(
        primary: 'General midlife / menopause navigation',
        cycle: 'Urgent to discuss',
      ),
    );
    expect(r.specialty, ClinicalSpecialty.gynaeEndocrine);
  });

  test('flagged lipid lab nudges bone_heart_risk', () {
    final r = engine.recommend(
      surveyAnswers: _baseAnswers(
        primary: 'General midlife / menopause navigation',
        boneHeart: 'Somewhat interested',
      ),
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

  test('why-copy is canned and non-empty', () {
    final r = engine.recommend(
      surveyAnswers: _baseAnswers(primary: 'Bone or heart risk concerns'),
    );
    expect(r.specialty, ClinicalSpecialty.boneHeartRisk);
    expect(r.whyCopy.length, greaterThan(40));
    expect(r.whyCopy, isNot(contains('LLM')));
  });
}
