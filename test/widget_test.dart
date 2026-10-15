import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novi/main.dart';
import 'package:novi/notebook.dart';

class TestPaths extends PathProviderPlatform {
  TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  test(
    'SQLite restart and both archive formats preserve text and original ink',
    () {
      final directory = Directory.systemTemp.createTempSync('novi-test');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}/library.sqlite';
      final note = Notebook(
        id: 'one',
        title: 'Physics',
        text: 'Newton',
        strokes: [
          [
            [1, 2, 0.5],
            [3, 4, 1],
          ],
        ],
      );
      final store = LibraryStore(path);
      store.save(note);
      store.close();
      final reopened = LibraryStore(path);
      expect(reopened.load().single.toJson(), note.toJson());
      for (final backup in [false, true]) {
        final decoded = decodePortable(
          encodePortable(reopened.load(), backup: backup),
          backup: backup,
        );
        expect(jsonEncode(decoded.single.toJson()), jsonEncode(note.toJson()));
      }
      expect(
        () =>
            decodePortable(encodePortable([note], backup: false), backup: true),
        throwsFormatException,
      );
      reopened.close();
    },
  );
  testWidgets('create, type, draw, undo, redo, and reopen', (tester) async {
    final directory = Directory.systemTemp.createTempSync('novi-widget');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      directory.deleteSync(recursive: true);
    });
    await tester.pumpWidget(const NoviApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New notebook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello Novi');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Hello Novi'), findsNothing);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(find.text('Hello Novi'), findsOneWidget);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 250), const Offset(80, 60));
    await tester.pumpAndSettle();
    final ink = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter is InkPainter)
        .single;
    expect((ink.painter! as InkPainter).strokes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const NoviApp());
    await tester.pumpAndSettle();
    expect(find.text('Hello Novi'), findsOneWidget);
    final restored = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter is InkPainter)
        .single;
    expect((restored.painter! as InkPainter).strokes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
