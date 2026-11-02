import 'package:flutter/material.dart';

/// Shallow wave from Brand-Forward femm login mockup (canvas 320×640).
///
/// Path: `M0,0 H320 V340 C250,400 140,300 0,360 Z`
class WelcomeWaveClipper extends CustomClipper<Path> {
  const WelcomeWaveClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * (340 / 640))
      ..cubicTo(
        w * (250 / 320),
        h * (400 / 640),
        w * (140 / 320),
        h * (300 / 640),
        0,
        h * (360 / 640),
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Soft cream stroke along the wave edge (matches mockup SVG outline).
class WelcomeWaveEdgePainter extends CustomPainter {
  const WelcomeWaveEdgePainter({required this.color, this.strokeWidth = 3});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * (360 / 640))
      ..cubicTo(
        w * (140 / 320),
        h * (300 / 640),
        w * (250 / 320),
        h * (400 / 640),
        w,
        h * (340 / 640),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WelcomeWaveEdgePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
