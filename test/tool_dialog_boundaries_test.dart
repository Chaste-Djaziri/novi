import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/tools/eraser/eraser_menu.dart';
import 'package:novi/features/editor/tools/pen/pen_menu.dart';
import 'package:novi/features/editor/tools/pencil/pencil_menu.dart';
import 'package:novi/features/editor/tools/select/lasso_menu.dart';
import 'package:novi/features/editor/tools/shape/shape_menu.dart';
import 'package:novi/features/editor/tools/tape/tape_menu.dart';
import 'package:novi/features/editor/tools/text/text_popovers.dart';

void main() {
  test('tool dialog boundaries expose the legacy-compatible public APIs', () {
    expect(PenMenuDialog, isA<Type>());
    expect(PenFeatureMenuDialog, isA<Type>());
    expect(PencilMenuDialog, isA<Type>());
    expect(TapeMenuDialog, isA<Type>());
    expect(DrawShapeMenuDialog, isA<Type>());
    expect(LassoToolMenuDialog, isA<Type>());
    expect(EraserTypeMenuDialog, isA<Type>());
    expect(EraserAdvancedSettingsDialog, isA<Type>());
    expect(FontSizeMenuDialog, isA<Type>());
    expect(FontFamilyMenuDialog, isA<Type>());
    expect(TextStyleMenuDialog, isA<Type>());
    expect(TextColorMenuDialog, isA<Type>());
    expect(TextAlignmentMenuDialog, isA<Type>());
    expect(LineHeightMenuDialog, isA<Type>());
    expect(TextBoxStyleMenuDialog, isA<Type>());
  });
}
