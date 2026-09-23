import 'package:flutter/material.dart';

class PaddleDuelPreview extends CustomPainter {
  const PaddleDuelPreview();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF22394A),
    );
    final line = Paint()
      ..color = Colors.white12
      ..strokeWidth = 2;
    for (double x = 12; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 8, size.height / 2),
        line,
      );
    }
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      38,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .55, 30, 80, 12),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFFF968A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .2, 138, 80, 12),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF9DF5CF),
    );
    canvas.drawLine(
      Offset(size.width * .42, 108),
      Offset(size.width * .56, 75),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(size.width * .56, 75),
      9,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant PaddleDuelPreview oldDelegate) => false;
}
