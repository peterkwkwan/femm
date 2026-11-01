/// Locked spend / upsell buckets from prototype-lock (Phase 1 enum + Phase 3 UI).
enum SpendBucket {
  skincareAesthetics(
    'skincare_aesthetics',
    'Skincare / aesthetics',
    chipLabel: 'Skincare',
  ),
  gymPhysio('gym_physio', 'Gym / physio'),
  supplements('supplements', 'Supplements'),
  wellnessSpa('wellness_spa', 'Wellness / spa'),
  mentalHealth('mental_health', 'Mental health'),
  privateGp('private_gp', 'Private GP');

  const SpendBucket(this.dbValue, this.label, {String? chipLabel})
      : chipLabel = chipLabel ?? label;

  final String dbValue;
  final String label;

  /// Shorter Path A chip label (Petal Soft mockups).
  final String chipLabel;

  static const List<SpendBucket> all = SpendBucket.values;

  static SpendBucket? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final b in SpendBucket.values) {
      if (b.dbValue == raw) return b;
    }
    return null;
  }
}
