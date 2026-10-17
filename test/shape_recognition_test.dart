import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/tools/shape/shape_recognition.dart';

List<List<double>> samples(
  List<Offset> vertices, {
  int perEdge = 12,
  bool closed = true,
  double noise = 0,
}) {
  final output = <List<double>>[];
  final edges = closed ? vertices.length : vertices.length - 1;
  for (var edge = 0; edge < edges; edge++) {
    final a = vertices[edge];
    final b = vertices[(edge + 1) % vertices.length];
    for (var step = 0; step < perEdge; step++) {
      final t = step / perEdge;
      final wobble = noise * math.sin((edge * perEdge + step) * 2.17);
      output.add([
        a.dx + (b.dx - a.dx) * t + wobble,
        a.dy + (b.dy - a.dy) * t - wobble,
        0.6,
      ]);
    }
  }
  final end = closed ? vertices.first : vertices.last;
  output.add([end.dx, end.dy, 0.6]);
  return output;
}

List<Offset> regular(int count, {double phase = 0}) => [
  for (var i = 0; i < count; i++)
    Offset(
      130 + 85 * math.cos(phase + 2 * math.pi * i / count),
      120 + 70 * math.sin(phase + 2 * math.pi * i / count),
    ),
];

List<Offset> star({double phase = -math.pi / 2}) => [
  for (var i = 0; i < 10; i++)
    Offset(
      180 + (i.isEven ? 95.0 : 42.0) * math.cos(phase + i * math.pi / 5),
      145 + (i.isEven ? 95.0 : 42.0) * math.sin(phase + i * math.pi / 5),
    ),
];

List<Offset> heart() => [
  for (var i = 0; i < 64; i++) ...[
    () {
      final t = i * 2 * math.pi / 64;
      return Offset(
        180 + 6.2 * math.pow(math.sin(t), 3),
        145 -
            (5.2 * math.cos(t) -
                2.1 * math.cos(2 * t) -
                1.0 * math.cos(3 * t) -
                0.5 * math.cos(4 * t)),
      );
    }(),
  ],
];

Rect boundsOf(List<List<double>> stroke) => Rect.fromPoints(
  Offset(
    stroke.map((point) => point[0]).reduce(math.min),
    stroke.map((point) => point[1]).reduce(math.min),
  ),
  Offset(
    stroke.map((point) => point[0]).reduce(math.max),
    stroke.map((point) => point[1]).reduce(math.max),
  ),
);

void main() {
  test('rotated polygons keep their number of corners', () {
    for (final sides in [3, 4, 5, 6, 8]) {
      for (final phase in [0.0, 0.27, 0.83]) {
        final result = ShapeRecognition.recognize(
          samples(regular(sides, phase: phase), noise: 0.7),
        );
        expect(result.isClosed, isTrue, reason: '$sides sides, $phase');
        expect(result.stroke.length, sides + 1, reason: '$sides sides, $phase');
      }
    }
  });

  test('five-point stars keep all ten alternating corners', () {
    final result = ShapeRecognition.recognize(
      samples(star(), perEdge: 8, noise: 1.2),
    );
    expect(result.isClosed, isTrue);
    expect(result.stroke.length, 11);
  });

  test('heart outlines fit to a clean heart instead of an oval', () {
    final result = ShapeRecognition.recognize(
      samples(heart(), perEdge: 1, noise: 0.8),
    );
    expect(result.isClosed, isTrue);
    expect(result.stroke.length, 49);
    final bounds = boundsOf(result.stroke);
    expect(bounds.center.dx, closeTo(180, 1));
    expect(bounds.bottom, closeTo(154.5, 2));
  });

  test('trapezium retains four unequal corners', () {
    final result = ShapeRecognition.recognize(
      samples([
        const Offset(60, 50),
        const Offset(170, 50),
        const Offset(220, 160),
        const Offset(25, 160),
      ], noise: 0.5),
    );
    expect(result.stroke.length, 5);
  });

  test('polygon recognition is independent of starting edge and direction', () {
    for (final sides in [3, 4, 6]) {
      final outline = samples(
        regular(sides, phase: 0.39),
        perEdge: 17,
        noise: 0.9,
      );
      final ring = outline.sublist(0, outline.length - 1);
      for (final shift in [3, 11, 25]) {
        final shifted = [...ring.skip(shift), ...ring.take(shift)];
        for (final sequence in [shifted, shifted.reversed.toList()]) {
          final gesture = [...sequence, sequence.first];
          final result = ShapeRecognition.recognize(gesture);
          expect(
            result.stroke.length,
            sides + 1,
            reason: '$sides sides, shift $shift',
          );
        }
      }
    }
  });

  test('smooth circles and ellipses remain smooth', () {
    for (final radii in [(80.0, 80.0), (100.0, 55.0)]) {
      final outline = [
        for (var i = 0; i < 96; i++)
          Offset(
            150 + radii.$1 * math.cos(i * math.pi / 48),
            150 + radii.$2 * math.sin(i * math.pi / 48),
          ),
      ];
      final result = ShapeRecognition.recognize(
        samples(outline, perEdge: 1, noise: 0.4),
      );
      expect(result.isClosed, isTrue);
      expect(result.stroke.length, greaterThan(24));
    }
  });

  test('noisy circles are straightened to a true circle', () {
    final outline = [
      for (var i = 0; i < 80; i++)
        Offset(
          220 + (75 + 2.5 * math.sin(i * 2.7)) * math.cos(i * 2 * math.pi / 80),
          160 + (75 + 2.5 * math.cos(i * 1.9)) * math.sin(i * 2 * math.pi / 80),
        ),
    ];
    final result = ShapeRecognition.recognize(
      samples(outline, perEdge: 1, noise: 1.2),
    );
    final bounds = boundsOf(result.stroke);
    expect(result.isClosed, isTrue);
    expect(result.stroke.length, 49);
    expect(bounds.center.dx, closeTo(220, 2));
    expect(bounds.center.dy, closeTo(160, 2));
    expect(bounds.width, closeTo(bounds.height, 2));
    expect(bounds.width, closeTo(150, 5));
  });

  test('an imperfect oval is straightened while retaining its proportions', () {
    final outline = [
      for (var i = 0; i < 72; i++)
        Offset(
          180 + (110 + 2 * math.sin(i * 2.1)) * math.cos(i * 2 * math.pi / 72),
          140 + (55 + 2 * math.cos(i * 1.7)) * math.sin(i * 2 * math.pi / 72),
        ),
    ];
    final result = ShapeRecognition.recognize(
      samples(outline, perEdge: 1, noise: 0.8),
    );
    final bounds = boundsOf(result.stroke);
    expect(result.isClosed, isTrue);
    expect(result.stroke.length, 49);
    expect(bounds.center.dx, closeTo(180, 2));
    expect(bounds.center.dy, closeTo(140, 2));
    expect(bounds.width, closeTo(220, 6));
    expect(bounds.height, closeTo(110, 6));
  });

  test('sparsely sampled hand-drawn ovals are still fitted', () {
    final outline = [
      for (var i = 0; i < 18; i++)
        Offset(
          180 + (100 + 4 * math.sin(i * 1.7)) * math.cos(i * 2 * math.pi / 18),
          140 + (50 + 3 * math.cos(i * 1.3)) * math.sin(i * 2 * math.pi / 18),
        ),
    ];
    final result = ShapeRecognition.recognize(
      samples(outline, perEdge: 1, noise: 2.5),
    );
    expect(result.stroke.length, 49);
  });

  test('a rotated ellipse fits without becoming a polygon', () {
    const angle = 0.64;
    final outline = [
      for (var i = 0; i < 96; i++)
        Offset(
          150 +
              100 * math.cos(i * math.pi / 48) * math.cos(angle) -
              52 * math.sin(i * math.pi / 48) * math.sin(angle),
          150 +
              100 * math.cos(i * math.pi / 48) * math.sin(angle) +
              52 * math.sin(i * math.pi / 48) * math.cos(angle),
        ),
    ];
    final result = ShapeRecognition.recognize(
      samples(outline, perEdge: 1, noise: 0.3),
    );
    expect(result.isClosed, isTrue);
    expect(result.stroke.length, 49);
  });

  test('lines and open angles snap without closing; curves stay freehand', () {
    final line = ShapeRecognition.recognize(
      samples(
        [const Offset(10, 20), const Offset(210, 30)],
        closed: false,
        noise: 0.3,
      ),
    );
    expect(line.stroke.length, 2);
    final angle = ShapeRecognition.recognize(
      samples(
        [const Offset(20, 20), const Offset(100, 150), const Offset(190, 45)],
        closed: false,
        noise: 0.3,
      ),
    );
    expect(angle.isClosed, isFalse);
    expect(angle.stroke.length, 3);
    final curve = [
      for (var i = 0; i <= 40; i++)
        [i * 5.0, 80 + 35 * math.sin(i * math.pi / 20), 0.6],
    ];
    final freehand = ShapeRecognition.recognize(curve);
    expect(freehand.isClosed, isFalse);
    expect(freehand.stroke.length, curve.length);
  });
}
