import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';

/// Flat layered rolling hills for Deep Accent Dusk login (canvas HillsDusk).
///
/// Soft ocean-like horizontal drift + vertical pulsate; layers parallax slightly.
/// Paths extend past the viewBox and painting is clipped so drift never leaves
/// vertical color slivers at the left/right edges.
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
    return ClipRect(
      child: RepaintBoundary(
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
      ),
    );
  }
}

class _DuskHillsPainter extends CustomPainter {
  _DuskHillsPainter({required this.driftT, required this.pulseT});

  final double driftT;
  final double pulseT;

  // Canvas HillsDusk viewBox 320×380, with horizontal bleed for drift.
  static const double _vw = 320;
  static const double _vh = 380;
  /// Extra path width beyond 0…320 so translate±drift never exposes a vertical edge.
  static const double _bleed = 48;
  static const double _maxDrift = 14;

  static const Color _sky = Color(0xFFE8D5CE);
  static const Color _midRose = Color(0xFFC97A76);
  static const Color _deepDusk = Color(0xFF8F4545);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vw;
    final sy = size.height / _vh;
    final bounds = Offset.zero & size;

    canvas.drawRect(bounds, Paint()..color = _sky);

    canvas.save();
    canvas.clipRect(bounds);

    final drift = lerpDouble(-_maxDrift, _maxDrift, driftT)!;
    final pulse = lerpDouble(0.988, 1.018, pulseT)!;

    final layers =
        <({Path Function(double, double) path, Color color, double factor})>[
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

    canvas.restore();
  }

  /// Ridge sealed from -bleed…vw+bleed so horizontal drift stays covered.
  Path _ridge({
    required double sx,
    required double sy,
    required double yL,
    required double c1x,
    required double c1y,
    required double c2x,
    required double c2y,
    required double midX,
    required double midY,
    required double c3x,
    required double c3y,
    required double c4x,
    required double c4y,
    required double yR,
  }) {
    const left = -_bleed;
    const right = _vw + _bleed;
    return _scaled(
      sx,
      sy,
      (p) => p
        ..moveTo(left, yL)
        ..lineTo(0, yL)
        ..cubicTo(c1x, c1y, c2x, c2y, midX, midY)
        ..cubicTo(c3x, c3y, c4x, c4y, _vw, yR)
        ..lineTo(right, yR)
        ..lineTo(right, _vh + _bleed)
        ..lineTo(left, _vh + _bleed)
        ..close(),
    );
  }

  Path _farSoft(double sx, double sy) => _ridge(
        sx: sx,
        sy: sy,
        yL: 160,
        c1x: 60,
        c1y: 120,
        c2x: 100,
        c2y: 200,
        midX: 165,
        midY: 145,
        c3x: 230,
        c3y: 95,
        c4x: 275,
        c4y: 175,
        yR: 130,
      );

  Path _midWarm(double sx, double sy) => _ridge(
        sx: sx,
        sy: sy,
        yL: 210,
        c1x: 75,
        c1y: 165,
        c2x: 120,
        c2y: 250,
        midX: 185,
        midY: 195,
        c3x: 245,
        c3y: 145,
        c4x: 280,
        c4y: 235,
        yR: 190,
      );

  Path _accentBand(double sx, double sy) => _ridge(
        sx: sx,
        sy: sy,
        yL: 265,
        c1x: 85,
        c1y: 220,
        c2x: 135,
        c2y: 310,
        midX: 195,
        midY: 255,
        c3x: 250,
        c3y: 210,
        c4x: 285,
        c4y: 290,
        yR: 250,
      );

  Path _nearDusk(double sx, double sy) => _ridge(
        sx: sx,
        sy: sy,
        yL: 320,
        c1x: 95,
        c1y: 285,
        c2x: 145,
        c2y: 350,
        midX: 205,
        midY: 315,
        c3x: 255,
        c3y: 285,
        c4x: 290,
        c4y: 340,
        yR: 310,
      );

  Path _creamDivide(double sx, double sy) => _ridge(
        sx: sx,
        sy: sy,
        yL: 365,
        c1x: 110,
        c1y: 348,
        c2x: 165,
        c2y: 378,
        midX: 225,
        midY: 358,
        c3x: 275,
        c3y: 342,
        c4x: 300,
        c4y: 368,
        yR: 355,
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
