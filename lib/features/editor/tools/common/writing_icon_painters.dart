import 'package:flutter/material.dart';

class PenTipPainter extends CustomPainter {
  const PenTipPainter({this.color = Colors.white});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .75, size.height * .15)
      ..lineTo(size.width * .35, size.height * .6)
      ..lineTo(size.width * .25, size.height * .8)
      ..lineTo(size.width * .45, size.height * .7)
      ..lineTo(size.width * .85, size.height * .25)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * .25, size.height * .8),
      Offset(size.width * .45, size.height * .55),
      paint..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(size.width * .15, size.height * .9),
      Offset(size.width * .5, size.height * .9),
      paint..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant PenTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class PencilTipPainter extends CustomPainter {
  const PencilTipPainter({this.color = Colors.white});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .75, size.height * .1)
      ..lineTo(size.width * .88, size.height * .23)
      ..lineTo(size.width * .4, size.height * .75)
      ..lineTo(size.width * .2, size.height * .82)
      ..lineTo(size.width * .27, size.height * .62)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * .36, size.height * .66),
      Offset(size.width * .45, size.height * .75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PencilTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class HighlighterTipPainter extends CustomPainter {
  const HighlighterTipPainter({this.color = Colors.white});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(size.width * .3, size.height * .35)
      ..lineTo(size.width * .55, size.height * .1)
      ..lineTo(size.width * .8, size.height * .35)
      ..lineTo(size.width * .55, size.height * .6)
      ..close();
    canvas.drawPath(body, paint);
    final nib = Path()
      ..moveTo(size.width * .3, size.height * .35)
      ..lineTo(size.width * .18, size.height * .65)
      ..lineTo(size.width * .32, size.height * .8)
      ..lineTo(size.width * .55, size.height * .6);
    canvas.drawPath(nib, paint);
    canvas.drawLine(
      Offset(size.width * .38, size.height * .88),
      Offset(size.width * .85, size.height * .88),
      paint..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant HighlighterTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TapeStripPainter extends CustomPainter {
  const TapeStripPainter({this.color = Colors.white});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .15, size.height * .4)
      ..lineTo(size.width * .22, size.height * .3)
      ..lineTo(size.width * .15, size.height * .2)
      ..lineTo(size.width * .22, size.height * .1)
      ..lineTo(size.width * .85, size.height * .6)
      ..lineTo(size.width * .78, size.height * .7)
      ..lineTo(size.width * .85, size.height * .8)
      ..lineTo(size.width * .78, size.height * .9)
      ..lineTo(size.width * .15, size.height * .4)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TapeStripPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DrawShapePainter extends CustomPainter {
  const DrawShapePainter({this.color = Colors.white});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * .35, size.height * .38),
      size.width * .22,
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .44,
        size.height * .18,
        size.width * .38,
        size.height * .38,
      ),
      paint,
    );
    final tri = Path()
      ..moveTo(size.width * .5, size.height * .54)
      ..lineTo(size.width * .78, size.height * .9)
      ..lineTo(size.width * .22, size.height * .9)
      ..close();
    canvas.drawPath(tri, paint);
  }

  @override
  bool shouldRepaint(covariant DrawShapePainter oldDelegate) =>
      oldDelegate.color != color;
}
