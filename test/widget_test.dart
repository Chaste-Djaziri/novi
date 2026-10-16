import 'desktop_test_support.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novi/main.dart';
import 'package:novi/desktop_ui.dart';
import 'package:novi/notebook.dart';
import 'package:novi/library_ui.dart';

class TestPaths extends PathProviderPlatform {
  TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  initializeDesktopWidgetTests();
  setUpAll(() => EditableText.debugDeterministicCursor = true);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);
  test('styles and document kinds survive storage and portable files; old documents still load', () {
    final old = Notebook.fromJson({
      'id': 'old',
      'title': 'Original',
      'text': 'Keep',
      'strokes': [],
    });
    expect(old.kind, 'Notebook');
    expect(old.paper, 'Blank');
    for (final kind in documentKinds) {
      final note = Notebook(
        id: kind,
        title: 'Styled',
        kind: kind,
        paper: 'Squared',
        tone: 'Dark',
        cover: 0xff909090,
        landscape: true,
        favorite: true,
      );
      final decoded = decodePortable(
        encodePortable([note], backup: false),
        backup: false,
      ).single;
      expect(decoded.toJson(), note.toJson());
      expect(note.copy().toJson(), note.toJson());
    }
  });
  test(
    'restore multiple notebooks into a fresh library and reject future formats',
    () {
      final directory = Directory.systemTemp.createTempSync('novi-restore');
      addTearDown(() => directory.deleteSync(recursive: true));
      final originals = [
        Notebook(id: 'a', title: 'Art'),
        Notebook(id: 'b', title: 'Science', text: 'F = ma'),
      ];
      final bytes = encodePortable(originals, backup: true);
      final destination = LibraryStore('${directory.path}/restored.sqlite');
      addTearDown(destination.close);
      destination.save(Notebook(id: 'existing', title: 'Keep me'));
      destination.merge(decodePortable(bytes, backup: true));
      expect(destination.load().map((n) => n.title), [
        'Keep me',
        'Art',
        'Science',
      ]);
      final manifest = utf8.encode(
        jsonEncode({'format': 'novi', 'version': 999, 'notebooks': []}),
      );
      final future = Uint8List.fromList(
        ZipEncoder().encode(
          Archive()
            ..addFile(ArchiveFile('manifest.json', manifest.length, manifest)),
        ),
      );
      expect(
        () => decodePortable(future, backup: false),
        throwsFormatException,
      );
      expect(destination.load(), hasLength(3));
    },
  );
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
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync('novi-widget');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      directory.deleteSync(recursive: true);
    });
    await tester.pumpWidget(const NoviApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    if (find.text('Notebook').evaluate().isNotEmpty) {
      await tester.tap(find.text('Notebook'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const Key('document-name')),
      'Notebook test',
    );
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Type'),
        matching: find.byType(DesktopToolButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(DesktopTextField), 'Hello Novi');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Hello Novi'), findsNothing);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(find.text('Hello Novi'), findsOneWidget);
    await tester.tap(
      find.ancestor(
        of: find.text('Draw'),
        matching: find.byType(DesktopToolButton),
      ),
    );
    await tester.pumpAndSettle();
    final inkCanvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is InkPainter,
    );
    final canvasTop = tester.getTopLeft(inkCanvas);
    await tester.dragFrom(
      canvasTop + const Offset(120, 160),
      const Offset(80, 60),
    );
    await tester.pumpAndSettle();
    final ink = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter is InkPainter)
        .single;
    expect((ink.painter! as InkPainter).strokes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const NoviApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notebook test').first);
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

  testWidgets('custom color picker allows picking any hex color for notebook cover', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync('novi-color-test');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      directory.deleteSync(recursive: true);
    });

    await tester.pumpWidget(const NoviApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    // Open New menu and select Notebook
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notebook').first);
    await tester.pumpAndSettle();
    // Enter name
    await tester.enterText(find.byKey(const Key('document-name')), 'Vibrant Notebook');
    await tester.pumpAndSettle();

    // Scroll to and tap Custom Color button
    await tester.ensureVisible(find.byKey(const Key('custom-color-button')));
    await tester.tap(find.byKey(const Key('custom-color-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomColorPickerDialog), findsOneWidget);

    // Enter custom hex color
    await tester.enterText(find.byKey(const Key('custom-hex-field')), 'FF5733');
    await tester.pumpAndSettle();

    // Confirm color selection
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomColorPickerDialog), findsNothing);

    // Create document
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Vibrant Notebook'), findsWidgets);

    // Verify in SQLite storage
    final store = LibraryStore('${directory.path}/novi.sqlite');
    final saved = store.load().firstWhere((n) => n.title == 'Vibrant Notebook');
    expect(saved.cover, 0xffff5733);
    expect(saved.coverImage, isNull);
    store.close();
  });

  testWidgets('notebook with image cover renders in DocumentCover and survives portable format', (tester) async {
    const samplePng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final note = Notebook(
      id: 'img-note',
      title: 'Art Journal',
      cover: 0xff255492,
      coverImage: samplePng,
    );

    // Verify DocumentCover widget renders without throwing
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 260,
            child: DocumentCover(note),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Art Journal'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Verify survives export / import round trip
    final encoded = encodePortable([note], backup: false);
    final decoded = decodePortable(encoded, backup: false).single;
    expect(decoded.coverImage, samplePng);
    expect(decoded.cover, 0xff255492);
    expect(decoded.title, 'Art Journal');
  });

  testWidgets('home button appears on notebook write page right before route buttons and returns to library', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync('novi-home-test');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(directory.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      directory.deleteSync(recursive: true);
    });

    await tester.pumpWidget(const NoviApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    // In library: Home button is not displayed in the window header
    expect(find.byKey(const Key('home-button')), findsNothing);

    // Open New menu and create a notebook
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notebook').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('document-name')), 'Home Test Notebook');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Now on notebook write page: Home button is present
    expect(find.byKey(const Key('home-button')), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);

    // Tap Home button to navigate back to documents library
    await tester.tap(find.byKey(const Key('home-button')));
    await tester.pumpAndSettle();

    // Back in library: Documents view is visible, and Home button is gone
    expect(find.text('Documents'), findsWidgets);
    expect(find.byKey(const Key('home-button')), findsNothing);
  });
}

