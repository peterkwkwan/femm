import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';

/// Path A step counter after labs confirm: Routine → Symptoms → Match.
/// Tone: `STEP 2 OF 3 · SYMPTOMS` with Petal Soft progress rail.
class PathAStepHeader extends StatelessWidget {
  const PathAStepHeader({
    super.key,
    required this.step,
    required this.label,
  });

  /// 1-based step index within the post-labs Path A flow.
  final int step;

  /// Short step name (e.g. Routine, Symptoms, Match).
  final String label;

  static const int totalSteps = 3;

  String get _text =>
      'STEP $step OF $totalSteps · ${label.toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _text,
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: PetalSoft.accent,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 1; i <= totalSteps; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i <= step
                          ? PetalSoft.accent
                          : PetalSoft.ink.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
