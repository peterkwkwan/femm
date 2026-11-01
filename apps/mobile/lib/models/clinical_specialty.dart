/// Locked clinical specialties (Phase 1 enum / Phase 4 match targets).
enum ClinicalSpecialty {
  menopauseAwareGp(
    'menopause_aware_gp',
    'Menopause-aware GP',
  ),
  gynaeEndocrine(
    'gynae_endocrine',
    'Gynae / endocrine',
  ),
  sleepMood(
    'sleep_mood',
    'Sleep / mood',
  ),
  boneHeartRisk(
    'bone_heart_risk',
    'Bone / heart risk consult',
  );

  const ClinicalSpecialty(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static ClinicalSpecialty? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ClinicalSpecialty.values) {
      if (s.dbValue == raw) return s;
    }
    return null;
  }

  static ClinicalSpecialty parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw ArgumentError('Unknown clinical specialty: $raw');
    }
    return parsed;
  }
}
