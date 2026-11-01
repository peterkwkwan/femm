/// Shared care-navigation disclaimer copy (Phase 6 audit).
/// Sticky surfaces use [stickyMatch]; Path C packs use [pathCOneLiner].
abstract final class FemmDisclaimers {
  /// Sticky footer on the match screen (and home Path A blurb companion).
  static const String stickyMatch =
      'Care-navigation only — not a diagnosis. femm does not prescribe, '
      'interpret imaging, or replace clinical advice.';

  /// Short gate / home one-liner.
  static const String oneLiner = 'Care-navigation only — not a diagnosis.';

  /// Must match `summary_packs.disclaimer` default + Path C pack generation.
  static const String pathCOneLiner =
      'Care-navigation only — not a diagnosis or medical advice.';

  /// True when copy still carries the locked liability signal.
  static bool assertsNotDiagnosis(String copy) {
    final lower = copy.toLowerCase();
    return lower.contains('not a diagnosis') ||
        lower.contains('care-navigation');
  }
}
