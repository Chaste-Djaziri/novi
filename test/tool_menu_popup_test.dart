import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/widgets/tool_menu_popup.dart';

void main() {
  testWidgets('shared tool menu popup renders supplied content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            ToolMenuPopup(
              targetRect: const Rect.fromLTWH(100, 20, 40, 30),
              child: const SizedBox(
                height: 80,
                child: Center(child: Text('Pencil settings')),
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Pencil settings'), findsOneWidget);
    expect(find.byType(ToolMenuPopup), findsOneWidget);
  });
}
