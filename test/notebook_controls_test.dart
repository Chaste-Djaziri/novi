import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novi/main.dart';
import 'package:novi/notebook.dart';
import 'package:novi/paper_layout.dart';
import 'package:novi/paper_text_editor.dart';
import 'package:novi/desktop_ui.dart';
import 'package:novi/workspace_tools.dart';
import 'package:novi/tablet_connection.dart';

import 'desktop_test_support.dart';
import 'widget_test.dart' show TestPaths;

void main() {
  initializeDesktopWidgetTests();
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);

  test('paper metrics keep whole rows and preserve every character across page splits', () {
    for (final pattern in [
      'Blank',
      'Squared',
      'Dotted',
      'Ruled',
      'Lines',
      'Wide ruled',
    ]) {
      final layout = PaperLayout(pattern);
      for (final fontSize in [12.0, 16.0, 24.0, 32.0]) {
        expect(layout.lineHeight(fontSize) % layout.spacing, 0);
        final style = layout.textStyle(fontSize, false, Colors.black);
        const text = 'Row zero';
        final value = layout.caretAt(
          const TextEditingValue(text: text),
          Offset(50, layout.edge + layout.lineHeight(fontSize) * 5 + 1),
          760,
          style,
          TextScaler.noScaling,
        );
        expect(value.text, 'Row zero\n\n\n\n\n');
        expect(value.selection.baseOffset, value.text.length);
        var remaining = List.generate(180, (i) => 'Line $i').join('\n');
        final original = remaining;
        final parts = <String>[];
        while (remaining.isNotEmpty) {
          final split = layout.splitOffset(
            remaining,
            760,
            980,
            style,
            TextScaler.noScaling,
          );
          expect(split, greaterThan(0));
          parts.add(remaining.substring(0, split));
          remaining = remaining.substring(split);
        }
        expect(parts.length, greaterThan(1));
        expect(parts.join(), original);
      }
    }
  });

  test(
    'tablet attachment is independent of proximity and observed pen fallback',
    () {
      final tablets = TabletConnection();
      expect(tablets.available, isFalse);
      tablets.apply({
        'available': true,
        'devices': ['one', 'two'],
      });
      expect(tablets.connected, isTrue);
      expect(tablets.deviceIds.length, 2);
      tablets.apply({
        'available': true,
        'devices': ['two'],
      });
      expect(tablets.showHand, isTrue);
      tablets.apply({'available': true, 'devices': []});
      expect(tablets.showHand, isFalse);
      tablets.observePen();
      expect(tablets.showHand, isTrue);
      expect(tablets.connected, isFalse);
      expect(tablets.description, contains('Pen observed'));
      tablets.dispose();
      tablets.apply({
        'available': true,
        'devices': ['late'],
      });
    },
  );

  testWidgets(
    'centered notebook tools, future menu, paper typing, continuation and scroll in text mode',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('novi-paper');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = originalPaths;
        directory.deleteSync(recursive: true);
      });
      final seed = LibraryStore('${directory.path}/novi.sqlite');
      seed.save(Notebook(id: 'paper', title: 'Rows', paper: 'Squared'));
      seed.close();
      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rows').first);
      await tester.pumpAndSettle();
      for (final width in [1200.0, 960.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        final toolbar = tester.getRect(find.byType(WorkspaceToolbar));
        final center = tester.getRect(find.byKey(const Key('centered-tools')));
        expect(center.center.dx, closeTo(toolbar.center.dx, 1));
        final calc = tester
            .widgetList<DesktopIconButton>(find.byType(DesktopIconButton))
            .firstWhere(
              (button) => button.tooltip == 'Calculator — Coming later',
            );
        expect(calc.onPressed, isNull);
        expect(tester.takeException(), isNull);
      }
      // Click below existing text on the actual paper at its current zoom.
      await tester.tap(find.byKey(const ValueKey('tool-text')));
      await tester.pumpAndSettle();
      final editor = find.byType(PaperTextEditor).first;
      final viewport = find.byType(InteractiveViewer);
      final delta =
          tester.getTopLeft(editor).dy - tester.getTopLeft(viewport).dy - 24;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewport),
          scrollDelta: Offset(0, delta),
        ),
      );
      await tester.pumpAndSettle();
      final scale = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      await tester.tapAt(
        tester.getTopLeft(editor) + Offset(40 * scale, 145 * scale),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<PaperTextEditor>(editor);
      expect(field.controller.text, startsWith('\n\n\n'));
      expect(field.focusNode.hasFocus, isTrue);
      final matrix = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final oldScale = matrix.value.getMaxScaleOnAxis();
      final oldY = matrix.value.storage[13];
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getTopLeft(editor) + const Offset(50, 160),
          scrollDelta: const Offset(0, 120),
        ),
      );
      await tester.pumpAndSettle();
      expect(matrix.value.getMaxScaleOnAxis(), oldScale);
      expect(matrix.value.storage[13], closeTo(oldY - 120, 1));
      final text = List.generate(130, (i) => 'Writing row $i').join('\n');
      final input = find.descendant(
        of: editor,
        matching: find.byType(DesktopTextField),
      );
      await tester.enterText(input, text);
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(Workspace));
      final note = state.current as Notebook;
      expect(note.pages.length, greaterThan(1));
      expect(note.pages.map((p) => p.text).join(), text);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect((state.current as Notebook).pages, hasLength(1));
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect((state.current as Notebook).pages.map((p) => p.text).join(), text);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = LibraryStore('${directory.path}/novi.sqlite');
      expect(reopened.load().single.pages.map((p) => p.text).join(), text);
      reopened.close();
    },
  );
}
