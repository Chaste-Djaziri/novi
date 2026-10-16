import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/controllers/stroke_controller.dart';

void main() {
  test('stroke controller samples pressure and returns an immutable result', () {
    final controller = StrokeController(style: {'kind': 'pen'});
    controller.begin(const PointerDownEvent(position: Offset(4, 8), pressure: 0.2));
    controller.add(const PointerMoveEvent(position: Offset(10, 12), pressure: 0.8));
    final stroke = controller.finish();

    expect(stroke, [
      [4, 8, 0.2],
      [10, 12, 0.8],
    ]);
    expect(controller.isActive, isFalse);
    stroke.first[0] = 99;
    expect(controller.points, isEmpty);
  });

  test('cancel discards an active stroke', () {
    final controller = StrokeController(style: const {});
    controller.begin(const PointerDownEvent(position: Offset.zero));
    controller.cancel();
    expect(controller.isActive, isFalse);
  });
}
