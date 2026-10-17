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
}
