import 'dart:math' as math;

import 'package:flutter/material.dart';

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint,
  double dashWidth,
  double dashSpace,
) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final length = math.min(dashWidth, metric.length - distance);
      canvas.drawPath(metric.extractPath(distance, distance + length), paint);
      distance += dashWidth + dashSpace;
    }
  }
}

class EraserIconPainter extends CustomPainter {
  const EraserIconPainter({this.color = Colors.white, this.accentColor});
  final Color color;
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-size.width / 2, -size.height / 2);

    final w = size.width * 0.58;
    final h = size.height * 0.9;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4.5));

    if (accentColor != null) {
      final topRect = Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        rect.top + h * 0.45,
      );
      final topRRect = RRect.fromRectAndCorners(
        topRect,
        topLeft: const Radius.circular(4.5),
        topRight: const Radius.circular(4.5),
      );
      canvas.drawRRect(
        topRRect,
        Paint()
          ..color = accentColor!
          ..style = PaintingStyle.fill,
      );
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(rrect, strokePaint);

    final lineY = rect.top + h * 0.45;
    canvas.drawLine(
      Offset(rect.left, lineY),
      Offset(rect.right, lineY),
      strokePaint..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EraserIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}

class LineHeightIconPainter extends CustomPainter {
  const LineHeightIconPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Vertical double arrow on the left
    final arrowX = size.width * 0.28;
    canvas.drawLine(
      Offset(arrowX, size.height * 0.2),
      Offset(arrowX, size.height * 0.8),
      paint,
    );
    // Top arrow head
    canvas.drawLine(
      Offset(arrowX - 2.5, size.height * 0.35),
      Offset(arrowX, size.height * 0.2),
      paint,
    );
    canvas.drawLine(
      Offset(arrowX + 2.5, size.height * 0.35),
      Offset(arrowX, size.height * 0.2),
      paint,
    );
    // Bottom arrow head
    canvas.drawLine(
      Offset(arrowX - 2.5, size.height * 0.65),
      Offset(arrowX, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(arrowX + 2.5, size.height * 0.65),
      Offset(arrowX, size.height * 0.8),
      paint,
    );

    // Horizontal bars on the right
    final lineStartX = size.width * 0.52;
    final lineEndX = size.width * 0.88;
    canvas.drawLine(
      Offset(lineStartX, size.height * 0.3),
      Offset(lineEndX, size.height * 0.3),
      paint,
    );
    canvas.drawLine(
      Offset(lineStartX, size.height * 0.5),
      Offset(lineEndX, size.height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(lineStartX, size.height * 0.7),
      Offset(lineEndX, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant LineHeightIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TextBoxStyleIconPainter extends CustomPainter {
  const TextBoxStyleIconPainter({
    this.color = Colors.white,
    this.bgColor,
    this.preset = 0,
  });
  final Color color;
  final int? bgColor;
  final int preset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));

    if (preset > 0 && bgColor != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Color(bgColor!)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      // Diagonal slash box (No fill / default)
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(rrect, paint);
      canvas.drawLine(
        Offset(rect.left + 2, rect.top + 2),
        Offset(rect.right - 2, rect.bottom - 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TextBoxStyleIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bgColor != bgColor ||
      oldDelegate.preset != preset;
}

class FavoriteTextIconPainter extends CustomPainter {
  const FavoriteTextIconPainter({
    this.color = Colors.white,
    this.isSaved = false,
  });
  final Color color;
  final bool isSaved;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(rrect, paint);

    // Letter 'T'
    final tPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final cx = size.width * 0.44;
    final cy = size.height * 0.52;
    canvas.drawLine(
      Offset(cx - 3.5, cy - 3.5),
      Offset(cx + 3.5, cy - 3.5),
      tPaint,
    );
    canvas.drawLine(Offset(cx, cy - 3.5), Offset(cx, cy + 4.5), tPaint);

    // Heart badge at top right
    final hx = size.width * 0.78;
    final hy = size.height * 0.28;
    final heartPath = Path();
    heartPath.moveTo(hx, hy);
    heartPath.cubicTo(hx - 2, hy - 2.5, hx - 3.5, hy, hx, hy + 3.5);
    heartPath.cubicTo(hx + 3.5, hy, hx + 2, hy - 2.5, hx, hy);
    heartPath.close();

    canvas.drawPath(
      heartPath,
      Paint()
        ..color = isSaved ? const Color(0xffff375f) : color
        ..style = isSaved ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant FavoriteTextIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSaved != isSaved;
}

class AlignmentIconPainter extends CustomPainter {
  const AlignmentIconPainter({
    this.color = Colors.white,
    this.alignment = TextAlign.left,
  });
  final Color color;
  final TextAlign alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final widths = [
      size.width * 0.8,
      size.width * 0.55,
      size.width * 0.8,
      size.width * 0.45,
    ];
    final ys = [
      size.height * 0.22,
      size.height * 0.41,
      size.height * 0.60,
      size.height * 0.79,
    ];

    for (var i = 0; i < 4; i++) {
      final w = widths[i];
      final y = ys[i];
      double startX;
      if (alignment == TextAlign.center) {
        startX = (size.width - w) / 2;
      } else if (alignment == TextAlign.right) {
        startX = size.width - w - 2;
      } else {
        startX = 2;
      }
      canvas.drawLine(Offset(startX, y), Offset(startX + w, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant AlignmentIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.alignment != alignment;
}

class DashedRectPainter extends CustomPainter {
  const DashedRectPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(3),
    );
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint, 3.5, 2.5);
  }

  @override
  bool shouldRepaint(covariant DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DashedLassoPainter extends CustomPainter {
  const DashedLassoPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.2);
    path.cubicTo(
      size.width * 0.5,
      size.height * 0.05,
      size.width * 0.9,
      size.height * 0.25,
      size.width * 0.85,
      size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.8,
      size.height * 0.85,
      size.width * 0.45,
      size.height * 0.95,
      size.width * 0.2,
      size.height * 0.75,
    );
    path.cubicTo(
      size.width * 0.05,
      size.height * 0.6,
      size.width * 0.08,
      size.height * 0.35,
      size.width * 0.25,
      size.height * 0.2,
    );
    path.close();
    _drawDashedPath(canvas, path, paint, 3.5, 2.5);
  }

  @override
  bool shouldRepaint(covariant DashedLassoPainter oldDelegate) =>
      oldDelegate.color != color;
}

class LassoArrowPainter extends CustomPainter {
  const LassoArrowPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height + 1)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1)
      ..close();
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final strokePath = Path()
      ..moveTo(0, size.height + 1)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1);
    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant LassoArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
