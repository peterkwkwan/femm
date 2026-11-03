import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';

/// Dawn Mist soft wash — layered ellipses with calm continuous drift + bounce.
///
/// Matches centered-login canvas SoftAtmosphere mood="mist". Motion is slow
/// easeInOut reverse loops (not noisy).
class DawnMistAtmosphere extends StatefulWidget {
  const DawnMistAtmosphere({super.key});

  @override
  State<DawnMistAtmosphere> createState() => _DawnMistAtmosphereState();
}

class _DawnMistAtmosphereState extends State<DawnMistAtmosphere>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    )..repeat(reverse: true);
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _bounce]),
        builder: (context, _) {
          return CustomPaint(
            painter: _DawnMistPainter(
              driftT: Curves.easeInOut.transform(_drift.value),
              bounceT: Curves.easeInOut.transform(_bounce.value),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _DawnMistPainter extends CustomPainter {
  _DawnMistPainter({required this.driftT, required this.bounceT});

  final double driftT;
  final double bounceT;

  // Canvas SoftAtmosphere mist viewBox 320×640.
  static const double _vw = 320;
  static const double _vh = 640;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vw;
    final sy = size.height / _vh;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = PetalSoft.mist,
    );

    final driftX = lerpDouble(-10, 10, driftT)!;
    final driftY = lerpDouble(-6, 6, driftT)!;
    final bounce = lerpDouble(0.97, 1.04, bounceT)!;

    _orb(
      canvas,
      sx: sx,
      sy: sy,
      cx: 160 + driftX * 0.55,
      cy: 210 + driftY * 0.4,
      rx: 170 * bounce,
      ry: 160 * bounce,
      color: PetalSoft.accentSoft.withValues(alpha: 0.55),
    );
    _orb(
      canvas,
      sx: sx,
      sy: sy,
      cx: 60 - driftX * 0.7,
      cy: 120 + driftY * 0.55,
      rx: 110 * lerpDouble(0.98, 1.05, bounceT)!,
      ry: 100 * lerpDouble(0.98, 1.05, bounceT)!,
      color: PetalSoft.sky.withValues(alpha: 0.4),
    );
    _orb(
      canvas,
      sx: sx,
      sy: sy,
      cx: 270 + driftX * 0.45,
      cy: 160 - driftY * 0.5,
      rx: 100 * lerpDouble(1.03, 0.96, bounceT)!,
      ry: 90 * lerpDouble(1.03, 0.96, bounceT)!,
      color: PetalSoft.surface.withValues(alpha: 0.45),
    );
    _orb(
      canvas,
      sx: sx,
      sy: sy,
      cx: 160 - driftX * 0.25,
      cy: 520 + driftY * 0.2,
      rx: 200 * lerpDouble(0.99, 1.02, bounceT)!,
      ry: 140 * lerpDouble(0.99, 1.02, bounceT)!,
      color: PetalSoft.bg.withValues(alpha: 0.85),
    );
    _orb(
      canvas,
      sx: sx,
      sy: sy,
      cx: 160 + driftX * 0.15,
      cy: 580,
      rx: 180,
      ry: 90,
      color: PetalSoft.surface.withValues(alpha: 0.9),
    );
  }

  void _orb(
    Canvas canvas, {
    required double sx,
    required double sy,
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Color color,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx * sx, cy * sy),
        width: rx * 2 * sx,
        height: ry * 2 * sy,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DawnMistPainter oldDelegate) =>
      oldDelegate.driftT != driftT || oldDelegate.bounceT != bounceT;
}
