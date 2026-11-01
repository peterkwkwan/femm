import 'package:flutter/material.dart';

/// Path A step counter after labs confirm: Spend → Symptoms → Match.
/// Tone: `STEP 2 OF 3 · SYMPTOMS`
class PathAStepHeader extends StatelessWidget {
  const PathAStepHeader({
    super.key,
    required this.step,
    required this.label,
  });

  /// 1-based step index within the post-labs Path A flow.
  final int step;

  /// Short step name (e.g. Spend, Symptoms, Match).
  final String label;

  static const int totalSteps = 3;

  String get _text =>
      'STEP $step OF $totalSteps · ${label.toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _text,
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
