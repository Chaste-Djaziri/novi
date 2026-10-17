import 'dart:math' as math;

import 'package:flutter/painting.dart';

class RecognizedShape {
  const RecognizedShape(this.stroke, {required this.isClosed});

  final List<List<double>> stroke;
  final bool isClosed;
}

/// Fits only shapes supported by the sampled gesture; uncertain ink stays ink.
class ShapeRecognition {
  static RecognizedShape recognize(List<List<double>> stroke) {
    if (stroke.length < 2) return RecognizedShape(stroke, isClosed: false);
    final points = <Offset>[];
    for (final sample in stroke) {
      final point = Offset(sample[0], sample[1]);
      if (points.isEmpty || (point - points.last).distance >= 0.5) {
        points.add(point);
      }
    }
    if (points.length < 2) return RecognizedShape(stroke, isClosed: false);
    final bounds = _bounds(points);
    final diagonal = Offset(bounds.width, bounds.height).distance;
    final length = _length(points);
    if (diagonal < 8 || length < 12) {
      return RecognizedShape(stroke, isClosed: false);
    }
    final gap = (points.first - points.last).distance;
    final closed =
        gap <= math.max(12, diagonal * 0.22) &&
        length >= diagonal * 1.65 &&
        bounds.width >= 12 &&
        bounds.height >= 12;
    if (closed) return _closed(stroke, points, bounds);
    return _open(stroke, points, diagonal, length);
  }

  static RecognizedShape _closed(
    List<List<double>> original,
    List<Offset> points,
    Rect bounds,
  ) {
    // Even arc-length spacing makes corner detection independent of pointer rate.
    final ring = _resample(points, 48, closed: true);
    final smooth = <Offset>[
      for (var i = 0; i < ring.length; i++)
        (ring[(i + 47) % 48] + ring[i] * 2 + ring[(i + 1) % 48]) / 4,
    ];
    final turns = <double>[
      for (var i = 0; i < 48; i++)
        _turn(smooth[(i + 46) % 48], smooth[i], smooth[(i + 2) % 48]),
    ];
    final candidates = [
      for (var i = 0; i < 48; i++)
        if (turns[i] > 0.43) i,
    ]..sort((a, b) => turns[b].compareTo(turns[a]));
    final corners = <int>[];
    for (final index in candidates) {
      if (corners.every(
        (other) =>
            math.min((index - other).abs(), 48 - (index - other).abs()) >= 5,
      )) {
        corners.add(index);
      }
    }
    corners.sort();
    if (corners.length >= 3 && corners.length <= 8) {
      final vertices = [for (final index in corners) ring[index]];
      final error = _meanEdgeError(ring, vertices, closed: true);
      if (error <= Offset(bounds.width, bounds.height).distance * 0.06) {
        return RecognizedShape(
          _samples(vertices, _meanPressure(original), closed: true),
          isClosed: true,
        );
      }
    }

    // An ellipse needs both a smooth contour and a close geometric fit.
    if (corners.length < 3) {
      final center = ring.reduce((a, b) => a + b) / ring.length.toDouble();
      var xx = 0.0;
      var yy = 0.0;
      var xy = 0.0;
      for (final point in ring) {
        final offset = point - center;
        xx += offset.dx * offset.dx;
        yy += offset.dy * offset.dy;
        xy += offset.dx * offset.dy;
      }
      final rotation = 0.5 * math.atan2(2 * xy, xx - yy);
      final cosine = math.cos(rotation);
      final sine = math.sin(rotation);
      final trace = xx + yy;
      final spread = math.sqrt((xx - yy) * (xx - yy) + 4 * xy * xy);
      final majorRadiusSquared = (trace + spread) / ring.length;
      final minorRadiusSquared = (trace - spread) / ring.length;
      var rx = math.sqrt(math.max(0, majorRadiusSquared));
      var ry = math.sqrt(math.max(0, minorRadiusSquared));
      if (rx == 0 || ry == 0) return RecognizedShape(original, isClosed: true);
      final local = [
        for (final point in ring)
          Offset(
            (point.dx - center.dx) * cosine + (point.dy - center.dy) * sine,
            -(point.dx - center.dx) * sine + (point.dy - center.dy) * cosine,
          ),
      ];
      rx =
          _quantile(local.map((point) => point.dx.abs()).toList(), 0.9) / 0.988;
      ry =
          _quantile(local.map((point) => point.dy.abs()).toList(), 0.9) / 0.988;
      if (rx / ry < 1.08) {
        final radius = (rx + ry) / 2;
        rx = radius;
        ry = radius;
      }
      final residual =
          local
              .map((point) {
                final x = point.dx / rx;
                final y = point.dy / ry;
                return (math.sqrt(x * x + y * y) - 1).abs();
              })
              .reduce((a, b) => a + b) /
          ring.length;
      if (residual <= 0.095) {
        const ellipseSamples = 48;
        final ellipse = <Offset>[
          for (var i = 0; i < ellipseSamples; i++)
            Offset(
              center.dx +
                  rx * math.cos(i * 2 * math.pi / ellipseSamples) * cosine -
                  ry * math.sin(i * 2 * math.pi / ellipseSamples) * sine,
              center.dy +
                  rx * math.cos(i * 2 * math.pi / ellipseSamples) * sine +
                  ry * math.sin(i * 2 * math.pi / ellipseSamples) * cosine,
            ),
        ];
        return RecognizedShape(
          _samples(ellipse, _meanPressure(original), closed: true),
          isClosed: true,
        );
      }
    }
    return RecognizedShape(original, isClosed: true);
  }

  static RecognizedShape _open(
    List<List<double>> original,
    List<Offset> points,
    double diagonal,
    double length,
  ) {
    final start = points.first;
    final end = points.last;
    if ((start - end).distance / length > 0.85 &&
        _meanEdgeError(points, [start, end], closed: false) <=
            diagonal * 0.08 &&
        _maxLineError(points, start, end) <= math.max(5, diagonal * 0.16)) {
      return RecognizedShape(
        _samples([start, end], original.first[2]),
        isClosed: false,
      );
    }
    final sampled = _resample(points, 32, closed: false);
    final corners = <int>[];
    for (var i = 2; i < sampled.length - 2; i++) {
      if (_turn(sampled[i - 2], sampled[i], sampled[i + 2]) > 0.65) {
        if (corners.isEmpty || i - corners.last >= 4) corners.add(i);
      }
    }
    if (corners.isNotEmpty && corners.length <= 6) {
      final vertices = [start, for (final i in corners) sampled[i], end];
      if (_meanEdgeError(points, vertices, closed: false) <= diagonal * 0.035) {
        return RecognizedShape(
          _samples(vertices, original.first[2]),
          isClosed: false,
        );
      }
    }
    return RecognizedShape(original, isClosed: false);
  }

  static double _turn(Offset before, Offset at, Offset after) {
    final incoming = at - before;
    final outgoing = after - at;
    if (incoming.distance < 0.001 || outgoing.distance < 0.001) return 0;
    final dot =
        (incoming.dx * outgoing.dx + incoming.dy * outgoing.dy) /
        (incoming.distance * outgoing.distance);
    return math.acos(dot.clamp(-1.0, 1.0));
  }

  static List<Offset> _resample(
    List<Offset> points,
    int count, {
    required bool closed,
  }) {
    final path = [...points];
    if (closed && (path.last - path.first).distance > 0.001) {
      path.add(path.first);
    }
    final total = _length(path);
    final output = <Offset>[];
    var segment = 1;
    var traversed = 0.0;
    for (var i = 0; i < count; i++) {
      final target = total * i / (closed ? count : count - 1);
      while (segment < path.length - 1 &&
          traversed + (path[segment] - path[segment - 1]).distance < target) {
        traversed += (path[segment] - path[segment - 1]).distance;
        segment++;
      }
      final a = path[segment - 1];
      final b = path[segment];
      final distance = (b - a).distance;
      output.add(
        Offset.lerp(
          a,
          b,
          distance == 0 ? 0 : ((target - traversed) / distance).clamp(0.0, 1.0),
        )!,
      );
    }
    return output;
  }

  static double _meanEdgeError(
    List<Offset> points,
    List<Offset> vertices, {
    required bool closed,
  }) {
    var sum = 0.0;
    for (final point in points) {
      var best = double.infinity;
      final edges = closed ? vertices.length : vertices.length - 1;
      for (var i = 0; i < edges; i++) {
        final a = vertices[i];
        final b = vertices[(i + 1) % vertices.length];
        final edge = b - a;
        final t = edge.distanceSquared == 0
            ? 0.0
            : (((point - a).dx * edge.dx + (point - a).dy * edge.dy) /
                      edge.distanceSquared)
                  .clamp(0.0, 1.0);
        best = math.min(best, (point - (a + edge * t)).distance);
      }
      sum += best;
    }
    return sum / points.length;
  }

  static double _maxLineError(List<Offset> points, Offset a, Offset b) {
    final edge = b - a;
    var largest = 0.0;
    for (final point in points) {
      final t = edge.distanceSquared == 0
          ? 0.0
          : (((point - a).dx * edge.dx + (point - a).dy * edge.dy) /
                    edge.distanceSquared)
                .clamp(0.0, 1.0);
      largest = math.max(largest, (point - (a + edge * t)).distance);
    }
    return largest;
  }

  static Rect _bounds(List<Offset> points) => Rect.fromPoints(
    points.reduce((a, b) => Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy))),
    points.reduce((a, b) => Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy))),
  );

  static double _length(List<Offset> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }

  static List<List<double>> _samples(
    List<Offset> points,
    double pressure, {
    bool closed = false,
  }) => [
    for (final point in points) [point.dx, point.dy, pressure],
    if (closed) [points.first.dx, points.first.dy, pressure],
  ];

  static double _meanPressure(List<List<double>> stroke) {
    var total = 0.0;
    var count = 0;
    for (final point in stroke) {
      if (point.length < 3 || !point[2].isFinite) continue;
      total += point[2].clamp(0.0, 1.0);
      count++;
    }
    return count == 0 ? 1.0 : total / count;
  }

  static double _quantile(List<double> values, double fraction) {
    values.sort();
    final index = ((values.length - 1) * fraction).round();
    return values[index];
  }
}
