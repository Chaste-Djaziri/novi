import 'package:flutter/gestures.dart';

/// Owns pointer sampling for one active stroke. Rendering and persistence stay
/// outside this controller so tools can reuse the same input lifecycle.
class StrokeController {
  StrokeController({required this.style});

  final Map<String, dynamic> style;
  final List<List<double>> points = [];
  bool get isActive => points.isNotEmpty;

  void begin(PointerDownEvent event) {
    points
      ..clear()
      ..add(_point(event.position, event.pressure));
  }

  void add(PointerMoveEvent event) {
    if (!isActive) return;
    final point = _point(event.position, event.pressure);
    if (points.length > 1 && point[0] == points.last[0] && point[1] == points.last[1]) {
      points[points.length - 1] = point;
    } else {
      points.add(point);
    }
  }

  List<List<double>> finish() {
    final result = points.map(List<double>.from).toList();
    points.clear();
    return result;
  }

  void cancel() => points.clear();

  List<double> _point(Offset position, double pressure) => [
    position.dx,
    position.dy,
    pressure.clamp(0.0, 1.0),
  ];
}
