import 'desktop_test_support.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novi/main.dart';
import 'package:novi/desktop_ui.dart';
import 'package:novi/notebook.dart';
import 'package:novi/workspace_tools.dart';

import 'widget_test.dart' show TestPaths;

void main() {
  initializeDesktopWidgetTests();
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);
  testWidgets(
    'tools edit real ink, preserve styles and keep independent document sessions',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('novi-workspace');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        directory.deleteSync(recursive: true);
      });
      final dbPath = '${directory.path}/novi.sqlite';
      final seed = LibraryStore(dbPath);
      seed.save(Notebook(id: 'a', title: 'Alpha'));
      seed.save(Notebook(id: 'b', title: 'Beta'));
      seed.close();
      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha').first);
      await tester.pumpAndSettle();
      final inkFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is InkPainter,
      );
      InkPainter ink() =>
          tester.widget<CustomPaint>(inkFinder).painter! as InkPainter;
      Offset point(double x, double y) =>
          tester.getTopLeft(inkFinder) + Offset(x, y);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkspaceToolbar>(find.byType(WorkspaceToolbar))
            .session
            .tool,
        EditorTool.eraser,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: const Offset(400, 300),
          scrollDelta: const Offset(0, 1004),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(point(100, 100), const Offset(100, 30));
      await tester.pumpAndSettle();
      expect(ink().strokes, hasLength(1));
      await tester.tap(
        find.ancestor(
          of: find.byTooltip('Highlight'),
          matching: find.byType(DesktopToolButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(point(100, 200), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(ink().strokes, hasLength(2));
      expect(ink().styles[1]['opacity'], 0.3);
      await tester.tap(
        find.ancestor(
          of: find.byTooltip('Erase'),
          matching: find.byType(DesktopToolButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(point(150, 115));
      await tester.pumpAndSettle();
      expect(ink().strokes, hasLength(1));
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(ink().strokes, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('tool-select')));
      await tester.pumpAndSettle();
      await tester.dragFrom(point(70, 70), const Offset(160, 90));
      await tester.pumpAndSettle();
      expect(ink().selected, {0});
      final originalX = ink().strokes.first.first.first;
      await tester.dragFrom(point(150, 115), const Offset(30, 40));
      await tester.pumpAndSettle();
      expect(ink().strokes.first.first.first, closeTo(originalX + 30, 0.01));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(ink().strokes, hasLength(1));
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(ink().strokes, hasLength(2));
      await tester.tap(
        find.ancestor(
          of: find.byTooltip('Type'),
          matching: find.byType(DesktopToolButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(DesktopTextField), 'Alpha text');
      await tester.pumpAndSettle();
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bold text'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final firstView = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      setTabletHardware(tester, ['test-tablet']);
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.byTooltip('Hand'),
          matching: find.byType(DesktopToolButton),
        ),
      );
      await tester.pumpAndSettle();
      final priorMatrix = firstView.value.clone();
      await tester.dragFrom(point(250, 250), const Offset(35, 25));
      await tester.pumpAndSettle();
      expect(firstView.value, isNot(priorMatrix));
      await tester.tap(
        find.ancestor(
          of: find.byTooltip('Type'),
          matching: find.byType(DesktopToolButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkspaceToolbar>(find.byType(WorkspaceToolbar))
            .session
            .tool,
        EditorTool.select,
      );
      expect(
        tester
            .widget<WorkspaceToolbar>(find.byType(WorkspaceToolbar))
            .session
            .undo,
        isEmpty,
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      final toolbar = tester.widget<WorkspaceToolbar>(
        find.byType(WorkspaceToolbar),
      );
      expect(toolbar.session.tool, EditorTool.text);
      expect(toolbar.session.textFocus.hasFocus, isTrue);
      expect(toolbar.session.undo, isNotEmpty);
      expect(toolbar.session.view.value.getMaxScaleOnAxis(), 1.25);
      expect(find.text('Alpha text'), findsOneWidget);
      await tester.tap(find.byTooltip('Close tab Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha text'), findsOneWidget);
      tester.view.physicalSize = const Size(960, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = LibraryStore(dbPath);
      final alpha = reopened.load().firstWhere((n) => n.id == 'a');
      final beta = reopened.load().firstWhere((n) => n.id == 'b');
      expect(alpha.text, 'Alpha text');
      expect(alpha.boldText, isTrue);
      expect(alpha.fontSize, 24);
      expect(alpha.strokes, hasLength(2));
      expect(alpha.inkStyles, hasLength(2));
      expect(beta.text, isEmpty);
      expect(beta.strokes, isEmpty);
      reopened.close();
    },
  );
}
