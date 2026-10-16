import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/main.dart';
import 'package:novi/notebook.dart';
import 'package:novi/workspace_tools.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'desktop_test_support.dart';
import 'widget_test.dart' show TestPaths;

void main() {
  initializeDesktopWidgetTests();
  testWidgets('canvas preview and saved geometry agree for each writing mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync('novi-shapes');
    final originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    addTearDown(() {
      PathProviderPlatform.instance = originalPaths;
      directory.deleteSync(recursive: true);
    });
    final store = LibraryStore('${directory.path}/novi.sqlite');
    store.save(Notebook(id: 'shapes', title: 'Shapes'));
    store.close();
    await tester.pumpWidget(const NoviApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shapes').first);
    await tester.pumpAndSettle();
    final dynamic workspace = tester.state(find.byType(Workspace));
    final session = tester
        .widget<WorkspaceToolbar>(find.byType(WorkspaceToolbar))
        .session;
    final note = workspace.current as Notebook;
    workspace.chooseTool(EditorTool.pen);
    session.penHoldForLine = true;
    session.pencilDrawAndHold = true;

    List<Offset> regular(int sides) => [
      for (var i = 0; i < sides; i++)
        Offset(
          220 + 80 * math.cos(0.21 + i * 2 * math.pi / sides),
          210 + 65 * math.sin(0.21 + i * 2 * math.pi / sides),
        ),
    ];
    final shapes = <(String, List<Offset>, int)>[
      (
        'circle',
        [
          for (var i = 0; i < 48; i++)
            Offset(
              220 + 75 * math.cos(i * math.pi / 24),
              210 + 75 * math.sin(i * math.pi / 24),
            ),
        ],
        49,
      ),
      ('triangle', regular(3), 4),
      (
        'rectangle',
        [
          const Offset(140, 145),
          const Offset(300, 145),
          const Offset(300, 275),
          const Offset(140, 275),
        ],
        5,
      ),
      ('hexagon', regular(6), 7),
    ];

    for (final mode in [
      WritingMode.drawShape,
      WritingMode.pen,
      WritingMode.pencil,
    ]) {
      session.writingMode = mode;
      for (final shape in shapes) {
        final vertices = shape.$2;
        final sampled = <Offset>[];
        for (var edge = 0; edge < vertices.length; edge++) {
          final a = vertices[edge];
          final b = vertices[(edge + 1) % vertices.length];
          for (var step = 0; step < 10; step++) {
            sampled.add(Offset.lerp(a, b, step / 10)!);
          }
        }
        sampled.add(vertices.first);
        workspace.pointerDown(
          PointerDownEvent(
            pointer: 9,
            position: sampled.first,
            buttons: 1,
            pressure: 0.6,
          ),
          pageIndex: 0,
        );
        for (final point in sampled.skip(1)) {
          workspace.pointerMove(
            PointerMoveEvent(
              pointer: 9,
              position: point,
              buttons: 1,
              pressure: 0.6,
            ),
          );
        }
        if (mode != WritingMode.drawShape) {
          await tester.pump(const Duration(milliseconds: 510));
        } else {
          await tester.pump();
        }
        final ink =
            tester
                    .widgetList<CustomPaint>(
                      find.byWidgetPredicate(
                        (widget) =>
                            widget is CustomPaint &&
                            widget.painter is InkPainter,
                      ),
                    )
                    .first
                    .painter!
                as InkPainter;
        if (mode != WritingMode.drawShape) {
          expect(
            ink.strokes.last.length,
            shape.$3,
            reason: '${mode.name} ${shape.$1} preview',
          );
        }
        workspace.finishStroke();
        expect(
          note.pages.first.strokes.last.length,
          shape.$3,
          reason: '${mode.name} ${shape.$1} saved',
        );
        expect(
          note.pages.first.inkStyles.last['originalPoints'],
          hasLength(sampled.length),
          reason: '${mode.name} ${shape.$1} original samples',
        );
      }
    }
  });
}
