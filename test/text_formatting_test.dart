import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/tools/text/text_formatting.dart';

void main() {
  test(
    'applies multiple styles to selected text without affecting neighbors',
    () {
      final controller = StyledTextController(text: 'hello world');
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );

      controller.applyStyle(controller.selection, {
        'bold': true,
        'color': 0xffff0000,
      });
      controller.applyStyle(controller.selection, {'underline': true});

      expect(controller.serializedRanges, [
        {
          'start': 0,
          'end': 5,
          'style': {'bold': true, 'color': 0xffff0000, 'underline': true},
        },
      ]);
      expect(
        controller.buildTextSpan(
          context: _TestBuildContext(),
          style: const TextStyle(),
          withComposing: false,
        ),
        isA<TextSpan>(),
      );
    },
  );

  test('preserves styles outside a partial selection', () {
    final controller = StyledTextController(text: 'abcdef');
    controller.applyStyle(const TextSelection(baseOffset: 1, extentOffset: 5), {
      'italic': true,
    });
    controller.applyStyle(const TextSelection(baseOffset: 3, extentOffset: 6), {
      'strikethrough': true,
    });

    expect(controller.serializedRanges, [
      {
        'start': 1,
        'end': 3,
        'style': {'italic': true},
      },
      {
        'start': 3,
        'end': 5,
        'style': {'italic': true, 'strikethrough': true},
      },
      {
        'start': 5,
        'end': 6,
        'style': {'strikethrough': true},
      },
    ]);
  });

  test('adjusts persisted ranges when text is inserted', () {
    final controller = StyledTextController(
      text: 'hello',
      serializedRanges: [
        {
          'start': 0,
          'end': 5,
          'style': {'bold': true},
        },
      ],
    );

    controller.text = 'heXllo';

    expect(controller.serializedRanges.single['start'], 0);
    expect(controller.serializedRanges.single['end'], 6);
  });
}

class _TestBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
