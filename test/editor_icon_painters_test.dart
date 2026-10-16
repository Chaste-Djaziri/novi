import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/features/editor/tools/common/editor_icon_painters.dart';

void main() {
  testWidgets('editor icon painters render their focused footprints', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          height: 120,
          child: Row(
            children: [
              CustomPaint(size: Size(24, 24), painter: EraserIconPainter()),
              CustomPaint(size: Size(24, 24), painter: DashedRectPainter()),
              CustomPaint(size: Size(24, 24), painter: DashedLassoPainter()),
              CustomPaint(
                size: Size(18, 10),
                painter: LassoArrowPainter(
                  color: Colors.black,
                  borderColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsNWidgets(5));
    await tester.pump();
  });
}
