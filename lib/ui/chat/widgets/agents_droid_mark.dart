import 'package:flutter/material.dart';

class AgentsDroidMark extends StatelessWidget {
  const AgentsDroidMark({super.key, required this.color, this.size = 48});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AgentsDroidMarkPainter(color)),
    );
  }
}

class _AgentsDroidMarkPainter extends CustomPainter {
  const _AgentsDroidMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final brackets = Path()
      ..moveTo(38, 34)
      ..lineTo(24, 54)
      ..lineTo(38, 74)
      ..moveTo(70, 34)
      ..lineTo(84, 54)
      ..lineTo(70, 74);
    canvas.drawPath(brackets, paint);

    final letterA = Path()
      ..moveTo(45, 74)
      ..lineTo(54, 34)
      ..lineTo(63, 74)
      ..moveTo(49, 57)
      ..lineTo(59, 57);
    canvas.drawPath(letterA, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AgentsDroidMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
