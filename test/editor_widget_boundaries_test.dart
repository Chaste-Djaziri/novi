import 'package:flutter_test/flutter_test.dart';
import 'package:novi/workspace_tools.dart';

void main() {
  test('editor toolbar widgets remain available through the compatibility boundary', () {
    expect(WorkspaceToolbar, isA<Type>());
    expect(FloatingToolControls, isA<Type>());
    expect(FloatingToolControlsState, isA<Type>());
  });
}
