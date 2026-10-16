import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/tools/common/tool_state.dart';
import 'package:novi/features/editor/tools/eraser/eraser_settings.dart';
import 'package:novi/features/editor/tools/highlighter/highlighter_settings.dart';
import 'package:novi/features/editor/tools/pen/pen_settings.dart';
import 'package:novi/features/editor/tools/pencil/pencil_settings.dart';
import 'package:novi/features/editor/tools/tape/tape_settings.dart';

void main() {
  test('writing tools own serializable state independently', () {
    final pen = PenSettings();
    final pencil = PencilSettings();
    final marker = HighlighterSettings();
    final tape = TapeSettings()..straight = true;

    pen.update(width: 7, color: 0xff3366ff);
    expect(pen.toJson()['penType'], 'fountain');
    expect(pen.toJson()['width'], 7);
    expect(pencil.toolId, 'pencil');
    expect(marker.opacity, closeTo(0.35, 0.001));
    expect(tape.toJson()['straight'], isTrue);
  });

  test('eraser state keeps radius, mode, and filters separate', () {
    final eraser = EraserSettings(radius: 26)..type = 'stroke';
    eraser.filters.remove('Tape');
    expect(eraser.toJson(), {
      'toolId': 'eraser',
      'radius': 26,
      'type': 'stroke',
      'filters': ['Highlighter', 'Pen', 'Pencil'],
    });
  });

  test('tool state notifies listeners only through updates', () {
    final state = WritingToolState();
    var notifications = 0;
    state.addListener(() => notifications++);
    state.update(width: 4);
    expect(notifications, 1);
    expect(state.width, 4);
  });
}
