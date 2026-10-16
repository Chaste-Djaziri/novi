import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared geometry for ink rendering, toolbar samples and the paper footprint.
class InkMaterial {
  const InkMaterial(this.style);
  final Map<String, dynamic> style;
  String get kind => style['kind'] as String? ?? 'pen';
  String get pen => style['penType'] as String? ?? 'legacy';
  double get width => (style['width'] as num?)?.toDouble() ?? 3;
  double get opacity => (style['opacity'] as num?)?.toDouble() ?? 1;
  bool get textured => kind == 'pencil' || kind == 'tape';

  static double toolWidth(String kind, double width) => switch (kind) {
    'highlighter' => width * 4,
    'tape' => width * (22 / 3),
    _ => width,
  };

  double pressureScale(double pressure) {
    final p = pressure.clamp(0.0, 1.0);
    if (kind == 'tape' || kind == 'highlighter' || kind == 'shape') return 1;
    if (kind == 'pencil') return 0.65 + 0.35 * p;
    return switch (pen) {
      'ballpoint' => 0.9 + 0.1 * p,
      'brush' => 0.15 + 0.85 * p * p,
      _ => 0.5 + 0.5 * p,
    };
  }

  Path nib(Offset point, double pressure) {
    final w = width * pressureScale(pressure);
    final path = Path();
    if (kind == 'tape' || kind == 'highlighter') {
      path.addRect(Rect.fromCenter(center: point, width: w * 0.32, height: w));
    } else if (pen == 'fountain' && kind == 'pen') {
      path.addOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.42, height: w),
      );
      return path
          .transform(Matrix4.rotationZ(-math.pi / 4).storage)
          .shift(point);
    } else {
      path.addOval(Rect.fromCircle(center: point, radius: w / 2));
    }
    return path;
  }

  Path footprint(List<List<double>> stroke) {
    final path = Path();
    for (var i = 0; i < stroke.length; i++) {
      final b = stroke[i];
      final a = stroke[i == 0 ? 0 : i - 1];
      final start = Offset(a[0], a[1]);
      final end = Offset(b[0], b[1]);
      final steps = math.max(
        1,
        ((end - start).distance / math.max(0.25, width * 0.08)).ceil(),
      );
      for (var j = 0; j <= steps; j++) {
        final t = j / steps;
        path.addPath(
          nib(Offset.lerp(start, end, t)!, a[2] + (b[2] - a[2]) * t),
          Offset.zero,
        );
      }
    }
    return path;
  }

  void paint(Canvas canvas, List<List<double>> stroke, Color color) {
    if (stroke.isEmpty) return;
    final path = footprint(stroke);
    final bounds = path.getBounds().inflate(1);
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: kind == 'pencil' ? 0.34 : 1),
    );
    if (textured) {
      canvas.save();
      canvas.clipPath(path);
      // Paper-coordinate noise stays fixed through repaint, selection and erasing.
      final spacing = kind == 'pencil' ? 1.25 : 3.0;
      for (
        var y = (bounds.top / spacing).floor();
        y <= (bounds.bottom / spacing).ceil();
        y++
      ) {
        for (
          var x = (bounds.left / spacing).floor();
          x <= (bounds.right / spacing).ceil();
          x++
        ) {
          final hash = ((x * 73856093) ^ (y * 19349663)) & 0xffff;
          if (hash % 3 == 0) continue;
          final point = Offset(
            x * spacing + (hash % 11) / 11,
            y * spacing + (hash % 7) / 7,
          );
          canvas.drawCircle(
            point,
            kind == 'pencil' ? 0.25 + (hash % 4) * 0.12 : 0.4,
            Paint()
              ..color = (kind == 'pencil' ? color : Colors.white).withValues(
                alpha: kind == 'pencil' ? 0.45 : 0.12,
              ),
          );
        }
      }
      canvas.restore();
    }
    canvas.restore();
  }
}

class InkFootprintPainter extends CustomPainter {
  const InkFootprintPainter({
    required Offset position,
    this.resolvePosition,
    required this.material,
    required this.color,
    this.pressure = 1,
    this.eraserRadius,
  // Keep the named position argument while exposing its resolved paint-time value.
  // ignore: prefer_initializing_formals
  }) : _position = position;
  final Offset _position;
  final Offset Function()? resolvePosition;
  Offset get position => resolvePosition?.call() ?? _position;
  final InkMaterial material;
  final Color color;
  final double pressure;
  final double? eraserRadius;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final path = eraserRadius == null
        ? material.nib(position, pressure)
        : (Path()..addOval(
            Rect.fromCircle(center: position, radius: eraserRadius!),
          ));
    for (final border in [(Colors.white, 2.5), (Colors.black, 1.0)]) {
      canvas.drawPath(
        path,
        Paint()
          ..color = border.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = border.$2,
      );
    }
    if (eraserRadius == null) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.16));
    }
  }

  @override
  bool shouldRepaint(covariant InkFootprintPainter oldDelegate) => true;
}

/// A fitted material swatch; all presets of a tool use the same scale.
class InkSamplePainter extends CustomPainter {
  const InkSamplePainter(this.material);
  final InkMaterial material;
  @override
  void paint(Canvas canvas, Size size) {
    final maxWidth = InkMaterial.toolWidth(material.kind, 7);
    final scale = math.min(1.0, (size.height - 2) / maxWidth);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    material.paint(canvas, [
      [-5 / scale, 0, 1],
      [5 / scale, 0, 1],
    ], Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InkSamplePainter oldDelegate) => true;
}
