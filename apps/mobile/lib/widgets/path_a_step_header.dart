import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';

/// Path A stepped journey (login excluded): Labs → Routine → Symptoms → Match.
enum PathAStep {
  labs(1, 'Labs'),
  routine(2, 'Routine'),
  symptoms(3, 'Symptoms'),
  match(4, 'Match');

  const PathAStep(this.number, this.label);

  final int number;
  final String label;
}

/// Icon-node + dots step rail (Petal Soft). Active = elongated icon pill;
/// past = solid accent dots; future = muted hollow dots. Caption: `LABS · STEP 1 OF 4`.
class PathAStepHeader extends StatelessWidget {
  const PathAStepHeader({
    super.key,
    required this.step,
  });

  /// Named Path A step (1–4). Confirm uses [PathAStep.labs]; unified Match uses match.
  final PathAStep step;

  static const int totalSteps = 4;

  String get _caption =>
      '${step.label.toUpperCase()} · STEP ${step.number} OF $totalSteps';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = step.number;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _caption,
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: PetalSoft.accent,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackLeft = 10.0;
                final trackRight = 10.0;
                final trackWidth =
                    (constraints.maxWidth - trackLeft - trackRight)
                        .clamp(0.0, double.infinity);
                final progressFrac = (active - 1) / (totalSteps - 1);
                final progressWidth = trackWidth * progressFrac;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: trackLeft,
                      right: trackRight,
                      top: 17,
                      child: Container(
                        height: 2,
                        color: PetalSoft.ink.withValues(alpha: 0.14),
                      ),
                    ),
                    Positioned(
                      left: trackLeft,
                      top: 17,
                      child: Container(
                        width: progressWidth,
                        height: 2,
                        color: PetalSoft.accent,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final s in PathAStep.values)
                          _StepNode(
                            kind: s,
                            state: s.number == active
                                ? _NodeState.active
                                : s.number < active
                                    ? _NodeState.done
                                    : _NodeState.future,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${step.number} · ${step.label}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: PetalSoft.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

enum _NodeState { active, done, future }

class _StepNode extends StatelessWidget {
  const _StepNode({required this.kind, required this.state});

  final PathAStep kind;
  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    if (state == _NodeState.active) {
      return Container(
        width: 34,
        height: 26,
        decoration: const BoxDecoration(
          color: PetalSoft.accent,
          borderRadius: BorderRadius.all(Radius.circular(13)),
        ),
        alignment: Alignment.center,
        child: _StepIcon(kind: kind, color: Colors.white),
      );
    }

    final done = state == _NodeState.done;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? PetalSoft.accent : PetalSoft.accentSoft,
          border: done
              ? null
              : Border.all(color: PetalSoft.ink.withValues(alpha: 0.14)),
        ),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.kind, required this.color});

  final PathAStep kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case PathAStep.labs:
        return Icon(Icons.description_outlined, size: 14, color: color);
      case PathAStep.routine:
        return Icon(Icons.schedule, size: 14, color: color);
      case PathAStep.symptoms:
        return Icon(Icons.favorite_border, size: 14, color: color);
      case PathAStep.match:
        return Icon(Icons.trending_up, size: 14, color: color);
    }
  }
}
