import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';

/// Flat layered rolling hills for Deep Accent Dusk login (canvas HillsDusk).
///
/// Soft ocean-like horizontal drift + vertical pulsate; layers parallax slightly.
class DeepAccentDuskHills extends StatefulWidget {
  const DeepAccentDuskHills({super.key});

  @override
  State<DeepAccentDuskHills> createState() => _DeepAccentDuskHillsState();
}

class _DeepAccentDuskHillsState extends State<DeepAccentDuskHills>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat(reverse: true);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _pulse]),
        builder: (context, _) {
          return CustomPaint(
            painter: _DuskHillsPainter(
              driftT: Curves.easeInOut.transform(_drift.value),
              pulseT: Curves.easeInOut.transform(_pulse.value),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _DuskHillsPainter extends CustomPainter {
  _DuskHillsPainter({required this.driftT, required this.pulseT});

  final double driftT;
  final double pulseT;

  // Canvas HillsDusk viewBox 320×380.
  static const double _vw = 320;
  static const double _vh = 380;

  static const Color _sky = Color(0xFFE8D5CE);
  static const Color _midRose = Color(0xFFC97A76);
  static const Color _deepDusk = Color(0xFF8F4545);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vw;
    final sy = size.height / _vh;

    canvas.drawRect(Offset.zero & size, Paint()..color = _sky);

    final drift = lerpDouble(-14, 14, driftT)!;
    final pulse = lerpDouble(0.988, 1.018, pulseT)!;

    final layers = <({Path Function(double, double) path, Color color, double factor})>[
      (path: _farSoft, color: PetalSoft.accentSoft, factor: 0.35),
      (path: _midWarm, color: _midRose, factor: 0.55),
      (path: _accentBand, color: PetalSoft.accent, factor: 0.75),
      (path: _nearDusk, color: _deepDusk, factor: 0.95),
      (path: _creamDivide, color: PetalSoft.surface, factor: 1.0),
    ];

    for (final layer in layers) {
      canvas.save();
      final dx = drift * layer.factor;
      final dy = (1 - pulse) * 10 * layer.factor;
      canvas.translate(dx, dy);
      // Gentle vertical scale from the bottom edge so ridges “breathe”.
      final originY = size.height;
      canvas.translate(0, originY);
      canvas.scale(1.0, pulse);
      canvas.translate(0, -originY);
      canvas.drawPath(layer.path(sx, sy), Paint()..color = layer.color);
      canvas.restore();
    }
  }

  Path _farSoft(double sx, double sy) => _scaled(
        sx,
        sy,
        (p) => p
          ..moveTo(0, 160)
          ..cubicTo(60, 120, 100, 200, 165, 145)
          ..cubicTo(230, 95, 275, 175, 320, 130)
          ..lineTo(320, 380)
          ..lineTo(0, 380)
          ..close(),
      );

  Path _midWarm(double sx, double sy) => _scaled(
        sx,
        sy,
        (p) => p
          ..moveTo(0, 210)
          ..cubicTo(75, 165, 120, 250, 185, 195)
          ..cubicTo(245, 145, 280, 235, 320, 190)
          ..lineTo(320, 380)
          ..lineTo(0, 380)
          ..close(),
      );

  Path _accentBand(double sx, double sy) => _scaled(
        sx,
        sy,
        (p) => p
          ..moveTo(0, 265)
          ..cubicTo(85, 220, 135, 310, 195, 255)
          ..cubicTo(250, 210, 285, 290, 320, 250)
          ..lineTo(320, 380)
          ..lineTo(0, 380)
          ..close(),
      );

  Path _nearDusk(double sx, double sy) => _scaled(
        sx,
        sy,
        (p) => p
          ..moveTo(0, 320)
          ..cubicTo(95, 285, 145, 350, 205, 315)
          ..cubicTo(255, 285, 290, 340, 320, 310)
          ..lineTo(320, 380)
          ..lineTo(0, 380)
          ..close(),
      );

  Path _creamDivide(double sx, double sy) => _scaled(
        sx,
        sy,
        (p) => p
          ..moveTo(0, 365)
          ..cubicTo(110, 348, 165, 378, 225, 358)
          ..cubicTo(275, 342, 300, 368, 320, 355)
          ..lineTo(320, 380)
          ..lineTo(0, 380)
          ..close(),
      );

  Path _scaled(double sx, double sy, void Function(Path) build) {
    final path = Path();
    build(path);
    return path.transform(Matrix4.diagonal3Values(sx, sy, 1).storage);
  }

  @override
  bool shouldRepaint(covariant _DuskHillsPainter oldDelegate) =>
      oldDelegate.driftT != driftT || oldDelegate.pulseT != pulseT;
}
