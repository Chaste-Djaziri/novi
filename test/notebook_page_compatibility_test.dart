import 'package:flutter_test/flutter_test.dart';
import 'package:novi/notebook.dart';

void main() {
  test('pages without persisted text styles expose an empty list', () {
    final page = NotebookPage.fromJson({
      'text': 'legacy text',
      'strokes': <dynamic>[],
      'inkStyles': <dynamic>[],
    });

    expect(page.textStyles, isEmpty);
    page.textStyles.add({
      'start': 0,
      'end': 6,
      'style': {'bold': true},
    });
    expect(page.textStyles, hasLength(1));
  });

  test('text box transforms survive page serialization', () {
    final page = NotebookPage(
      text: 'movable',
      textBoxOffsetX: 18,
      textBoxOffsetY: -7,
      textBoxScale: 1.35,
      textBoxRotation: 0.42,
    );

    final restored = NotebookPage.fromJson(page.toJson());

    expect(restored.textBoxOffsetX, 18);
    expect(restored.textBoxOffsetY, -7);
    expect(restored.textBoxScale, 1.35);
    expect(restored.textBoxRotation, 0.42);
  });
}
