import 'package:flutter/material.dart';

import '../theme/petal_soft.dart';

/// Locked Calmness bloom mark (soft concentric layers + quiet figure).
///
/// Paths match the logo / nav canvas SVG (viewBox 0 0 120 120).
class CalmnessMark extends StatelessWidget {
  const CalmnessMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: 'femm',
        image: true,
        child: CustomPaint(painter: _CalmnessMarkPainter()),
      ),
    );
  }
}

class _CalmnessMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 120;
    canvas.scale(s, s);

    final outer = Paint()..color = PetalSoft.accentSoft;
    final mid = Paint()..color = PetalSoft.blush;
    final core = Paint()..color = PetalSoft.accent;
    final figure = Paint()
      ..color = PetalSoft.surface
      ..style = PaintingStyle.fill;
    final armStroke = Paint()
      ..color = PetalSoft.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(60, 10)
        ..cubicTo(78, 12, 102, 28, 106, 52)
        ..cubicTo(110, 76, 92, 104, 60, 110)
        ..cubicTo(28, 104, 10, 76, 14, 52)
        ..cubicTo(18, 28, 42, 12, 60, 10)
        ..close(),
      outer,
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 22)
        ..cubicTo(74, 24, 92, 36, 94, 54)
        ..cubicTo(96, 72, 82, 94, 60, 98)
        ..cubicTo(38, 94, 24, 72, 26, 54)
        ..cubicTo(28, 36, 46, 24, 60, 22)
        ..close(),
      mid,
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 34)
        ..cubicTo(70, 36, 82, 44, 83, 56)
        ..cubicTo(84, 68, 74, 84, 60, 86)
        ..cubicTo(46, 84, 36, 68, 37, 56)
        ..cubicTo(38, 44, 50, 36, 60, 34)
        ..close(),
      core,
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 44)
        ..cubicTo(59, 48, 57, 54, 56.5, 60)
        ..cubicTo(55, 68, 53, 76, 52, 84)
        ..cubicTo(56, 82, 64, 82, 68, 84)
        ..cubicTo(67, 76, 65, 68, 63.5, 60)
        ..cubicTo(63, 54, 61, 48, 60, 44)
        ..close(),
      figure,
    );
    canvas.drawPath(
      Path()
        ..moveTo(56.5, 60)
        ..cubicTo(48, 58, 40, 54, 36, 50),
      armStroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(63.5, 60)
        ..cubicTo(72, 58, 80, 54, 84, 50),
      armStroke,
    );
    canvas.drawCircle(const Offset(60, 40), 5, figure);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
