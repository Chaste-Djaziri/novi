import 'desktop_test_support.dart';

import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novi/main.dart';
import 'package:novi/desktop_ui.dart';
import 'package:novi/notebook.dart';
import 'package:novi/library_ui.dart';
import 'package:novi/pages_sidebar.dart';
import 'package:novi/workspace_tools.dart';

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
        of: find.byTooltip('Type'),
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
        of: find.byTooltip('Draw'),
        matching: find.byType(DesktopToolButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(0, 1100),
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

  testWidgets(
    'custom color picker allows picking any hex color for notebook cover',
    (tester) async {
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
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Vibrant Notebook',
      );
      await tester.pumpAndSettle();

      // Scroll to and tap Custom Color button
      await tester.ensureVisible(find.byKey(const Key('custom-color-button')));
      await tester.tap(find.byKey(const Key('custom-color-button')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomColorPickerDialog), findsOneWidget);

      // Enter custom hex color
      await tester.enterText(
        find.byKey(const Key('custom-hex-field')),
        'FF5733',
      );
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
      final saved = store.load().firstWhere(
        (n) => n.title == 'Vibrant Notebook',
      );
      expect(saved.cover, 0xffff5733);
      expect(saved.coverImage, isNull);
      store.close();
    },
  );

  testWidgets(
    'notebook with image cover renders in DocumentCover and survives portable format',
    (tester) async {
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
            body: SizedBox(width: 200, height: 260, child: DocumentCover(note)),
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
    },
  );

  testWidgets(
    'home button appears on notebook write page right before route buttons and returns to library',
    (tester) async {
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
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Home Test Notebook',
      );
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
    },
  );

  testWidgets(
    'when document opened and is in tab preserve it open until specifically closed by the user in tab',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('novi-tab-test');
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

      // Create first notebook 'Doc Alpha'
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notebook').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Doc Alpha',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // 'Doc Alpha' is in tab
      expect(find.byTooltip('Close tab Doc Alpha'), findsOneWidget);

      // Go Home (back to library)
      await tester.tap(find.byKey(const Key('home-button')));
      await tester.pumpAndSettle();

      // In library: 'Doc Alpha' tab is PRESERVED open in the tab bar
      expect(find.byTooltip('Close tab Doc Alpha'), findsOneWidget);

      // Create second notebook 'Doc Beta'
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notebook').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Doc Beta',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Both tabs are open
      expect(find.byTooltip('Close tab Doc Alpha'), findsOneWidget);
      expect(find.byTooltip('Close tab Doc Beta'), findsOneWidget);

      // Go Home again
      await tester.tap(find.byKey(const Key('home-button')));
      await tester.pumpAndSettle();

      // Both tabs remain preserved while browsing the library
      expect(find.byTooltip('Close tab Doc Alpha'), findsOneWidget);
      expect(find.byTooltip('Close tab Doc Beta'), findsOneWidget);

      // Click 'Doc Alpha' tab to switch to it
      await tester.tap(find.text('Doc Alpha').first);
      await tester.pumpAndSettle();

      // We are back in 'Doc Alpha'
      expect(find.byKey(const Key('home-button')), findsOneWidget);

      // Close only 'Doc Alpha' tab using its 'x' button
      await tester.tap(find.byTooltip('Close tab Doc Alpha'));
      await tester.pumpAndSettle();

      // 'Doc Alpha' tab is now closed, but 'Doc Beta' tab remains preserved!
      expect(find.byTooltip('Close tab Doc Alpha'), findsNothing);
      expect(find.byTooltip('Close tab Doc Beta'), findsOneWidget);

      // Close 'Doc Beta' tab
      await tester.tap(find.byTooltip('Close tab Doc Beta'));
      await tester.pumpAndSettle();

      // All tabs closed -> back in library, no tabs open
      expect(find.byTooltip('Close tab Doc Beta'), findsNothing);
    },
  );

  testWidgets(
    'folder and 3 dots actions stay pinned to the right end of the top bar with or without tabs',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('novi-topbar-test');
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

      final menuFinder = find.byTooltip('Import, export and backup');
      final folderFinder = find.byTooltip('Open document');

      // Without tabs open in library
      final menuRightNoTab = tester.getTopRight(menuFinder).dx;
      final folderRightNoTab = tester.getTopRight(folderFinder).dx;
      expect(menuRightNoTab, greaterThan(1150));
      expect(folderRightNoTab, lessThan(menuRightNoTab));

      // Open a notebook so tabs are active
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notebook').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Pinned Doc',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // With a tab open in the top bar: verify menu and folder remain pinned flush to the right end!
      final menuRightWithTab = tester.getTopRight(menuFinder).dx;
      final folderRightWithTab = tester.getTopRight(folderFinder).dx;
      expect(menuRightWithTab, greaterThan(1150));
      expect((menuRightWithTab - menuRightNoTab).abs(), lessThan(5.0));
      expect((folderRightWithTab - folderRightNoTab).abs(), lessThan(5.0));
    },
  );

  testWidgets(
    'notebook paper centers itself in viewport and on scroll sticks to top and bottom',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('novi-center-test');
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

      // Create a portrait notebook
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notebook').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Centered Paper Doc',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final viewerFinder = find.byType(InteractiveViewer);
      final inkCanvasFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is InkPainter,
      );
      final coverFinder = find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('cover-page-'),
      );

      // 1. Verify cover (Page 1) and paper (Page 2) are centered horizontally in the viewport
      final viewerCenter = tester.getCenter(viewerFinder);
      final coverCenter = tester.getCenter(coverFinder);
      final inkCenter = tester.getCenter(inkCanvasFinder);
      expect((coverCenter.dx - viewerCenter.dx).abs(), lessThan(2.0));
      expect((inkCenter.dx - viewerCenter.dx).abs(), lessThan(2.0));

      // Initially at top: top of cover (Page 1) has 24px gap below viewport top
      final initialTop = tester.getTopLeft(coverFinder).dy;
      final viewerTop = tester.getTopLeft(viewerFinder).dy;
      expect((initialTop - viewerTop - 24.0).abs(), lessThan(2.0));

      // Paper (Page 2) is directly under cover with a 24px gap
      final paperTop = tester.getTopLeft(inkCanvasFinder).dy;
      final coverBottom = tester.getBottomLeft(coverFinder).dy;
      expect((paperTop - coverBottom - 24.0).abs(), lessThan(2.0));

      // 2. Scrolling left or right MUST always keep paper centered horizontally!
      final initialIv = tester.widget<InteractiveViewer>(viewerFinder);
      expect(initialIv.panAxis, PanAxis.vertical);
      expect(initialIv.boundaryMargin.horizontal, 0.0);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(500, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getCenter(inkCanvasFinder).dx - viewerCenter.dx).abs(),
        lessThan(2.0),
      );

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(-800, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getCenter(inkCanvasFinder).dx - viewerCenter.dx).abs(),
        lessThan(2.0),
      );

      // 3. Scroll down by mouse wheel / trackpad gesture
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 200),
        ),
      );
      await tester.pumpAndSettle();
      final midScrollTop = tester.getTopLeft(coverFinder).dy;
      expect(midScrollTop, lessThan(initialTop));

      // 4. Scroll all the way to the bottom: paper bottom leaves 24px gap above viewport bottom
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 3000),
        ),
      );
      await tester.pumpAndSettle();
      final bottomReached = tester.getBottomLeft(inkCanvasFinder).dy;
      final viewerBottom = tester.getBottomLeft(viewerFinder).dy;
      expect((viewerBottom - bottomReached - 24.0).abs(), lessThan(2.0));

      // Scrolling down slightly at bottom overscrolls within expanded bounds
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 30),
        ),
      );
      await tester.pump();
      expect(
        (viewerBottom - tester.getBottomLeft(inkCanvasFinder).dy - 24.0).abs(),
        lessThan(25.0),
      );
      // Wait for bounce-back animation to return
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        (viewerBottom - tester.getBottomLeft(inkCanvasFinder).dy - 24.0).abs(),
        lessThan(2.0),
      );

      // 5. Scroll all the way to the top: cover top leaves 24px gap below viewport top
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, -5000),
        ),
      );
      await tester.pumpAndSettle();
      final topReached = tester.getTopLeft(coverFinder).dy;
      expect((topReached - viewerTop - 24.0).abs(), lessThan(2.0));

      // Scrolling up further still sticks to top gap (cannot scroll past top)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, -1000),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getTopLeft(coverFinder).dy - viewerTop - 24.0).abs(),
        lessThan(2.0),
      );

      // 6. On zoom: make sure it is aligned center
      await tester.tap(find.byKey(const ValueKey('tool-pen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final zoomedCenter = tester.getCenter(inkCanvasFinder);
      expect((zoomedCenter.dx - viewerCenter.dx).abs(), lessThan(5.0));

      final zoomedIv = tester.widget<InteractiveViewer>(viewerFinder);
      expect(zoomedIv.panAxis, PanAxis.free);
      expect(zoomedIv.boundaryMargin.horizontal, 0.0);

      // 7. When too big out of view: allow left and right scrolling to the edge of the paper
      final initialZoomedLeft = tester.getTopLeft(inkCanvasFinder).dx;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(200, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(inkCanvasFinder).dx,
        lessThan(initialZoomedLeft),
      );

      // Scroll to right edge of the paper: right edge sticks to right edge of viewport
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(3000, 0),
        ),
      );
      await tester.pumpAndSettle();
      final viewerRight = tester.getTopRight(viewerFinder).dx;
      final paperRight = tester.getTopRight(inkCanvasFinder).dx;
      expect((paperRight - viewerRight).abs(), lessThan(5.0));

      // Scrolling right further cannot scroll past the right edge
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(1000, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getTopRight(inkCanvasFinder).dx - viewerRight).abs(),
        lessThan(5.0),
      );

      // Scroll to left edge of the paper: left edge sticks to left edge of viewport
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(-5000, 0),
        ),
      );
      await tester.pumpAndSettle();
      final viewerLeft = tester.getTopLeft(viewerFinder).dx;
      final paperLeft = tester.getTopLeft(inkCanvasFinder).dx;
      expect((paperLeft - viewerLeft).abs(), lessThan(5.0));

      // Scrolling left further cannot scroll past the left edge
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(-1000, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getTopLeft(inkCanvasFinder).dx - viewerLeft).abs(),
        lessThan(5.0),
      );

      // 8. Allow zooming out the page to small size even smaller than the viewport,
      // and keep paper centered on side scroll when smaller than viewport
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byTooltip('Zoom out'));
        await tester.pumpAndSettle();
      }
      final smallIv = tester.widget<InteractiveViewer>(viewerFinder);
      final smallScale = smallIv.transformationController!.value
          .getMaxScaleOnAxis();
      expect(smallScale, lessThan(0.5));
      expect(smallIv.panAxis, PanAxis.vertical);

      // Verify paper is centered horizontally when zoomed out small
      final smallCenter = tester.getCenter(inkCanvasFinder);
      expect((smallCenter.dx - viewerCenter.dx).abs(), lessThan(5.0));

      // Side scroll attempts in both directions keep the paper centered
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(600, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getCenter(inkCanvasFinder).dx - viewerCenter.dx).abs(),
        lessThan(5.0),
      );

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(-800, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.getCenter(inkCanvasFinder).dx - viewerCenter.dx).abs(),
        lessThan(5.0),
      );

      // Reset view returns back to 100% and centered
      await tester.tap(find.byTooltip('Reset view'));
      await tester.pumpAndSettle();
      expect(smallIv.transformationController!.value.getMaxScaleOnAxis(), 1.0);
      expect(
        (tester.getCenter(inkCanvasFinder).dx - viewerCenter.dx).abs(),
        lessThan(2.0),
      );
    },
  );

  testWidgets(
    'once on bottom on scroll shows loader, and scrolling past threshold creates new page',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final directory = Directory.systemTemp.createTempSync('novi-multipage');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        directory.deleteSync(recursive: true);
      });

      final dbPath = '${directory.path}/novi.sqlite';
      final store = LibraryStore(dbPath);
      store.save(Notebook(id: 'note-multipage', title: 'Scroll Page Note'));
      store.close();

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      // Open the notebook
      await tester.tap(find.text('Scroll Page Note').first);
      await tester.pumpAndSettle();

      // Initially 2 pages total (Page 1 Cover, Page 2 Paper)
      expect(find.textContaining('Page 1 of 2'), findsOneWidget);

      final viewerFinder = find.byType(InteractiveViewer);
      final viewerCenter = tester.getCenter(viewerFinder);

      // Scroll to the bottom of the document
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 3000),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 2 of 2'), findsOneWidget);

      // Now at bottom: scroll down slightly (overscroll)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 90),
        ),
      );
      await tester.pump();

      // Loader appears underneath showing progress! (90 / 180 = 50%)
      expect(find.text('Scroll to add page 50%'), findsOneWidget);

      // Scroll down further past the 180 threshold (90 + 100 = 190 >= 180)
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // New page is created! Total pages is now 3 (Page 2 of 3)
      expect(find.textContaining('of 3'), findsOneWidget);

      // Scrolling down reaches Page 3 of 3
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 1000),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Page 3 of 3'), findsOneWidget);

      // Verify two paper pages now exist
      final inkCanvases = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is InkPainter,
      );
      expect(inkCanvases, findsNWidgets(2));

      // Paper Page 2 is directly under Paper Page 1 with a 24px gap
      final page1Bottom = tester.getBottomLeft(inkCanvases.first).dy;
      final page2Top = tester.getTopLeft(inkCanvases.last).dy;
      expect((page2Top - page1Bottom - 24.0).abs(), lessThan(2.0));

      // Undo reverts the page creation back to 2 pages
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();

      final inkCanvasesAfterUndo = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is InkPainter,
      );
      expect(inkCanvasesAfterUndo, findsNWidgets(1));
      expect(find.textContaining('Page 2 of 2'), findsOneWidget);
    },
  );

  testWidgets(
    'allows scroll without hand tool when using pc and keyboard/mouse and reveals hand when stylus is connected',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final directory = Directory.systemTemp.createTempSync(
        'novi-scroll-test-',
      );
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

      // Create notebook
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notebook').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Mouse Keyboard Scroll Doc',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final handFinder = find.ancestor(
        of: find.byTooltip('Hand'),
        matching: find.byType(DesktopToolButton),
      );

      // 1. Hand tool is initially HIDDEN when using mouse & keyboard normally
      expect(handFinder, findsNothing);

      final viewerFinder = find.byType(InteractiveViewer);
      final coverFinder = find.byWidgetPredicate(
        (w) =>
            w is SizedBox &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('cover-page-'),
      );
      final initialTop = tester.getTopLeft(coverFinder).dy;

      // 2. Can scroll without the hand control using mouse wheel
      final viewerCenter = tester.getCenter(viewerFinder);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: viewerCenter,
          scrollDelta: const Offset(0, 150),
        ),
      );
      await tester.pumpAndSettle();
      final scrolledTop = tester.getTopLeft(coverFinder).dy;
      expect(scrolledTop, lessThan(initialTop));

      // 3. Can scroll without the hand control using keyboard arrow keys
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final arrowScrolledTop = tester.getTopLeft(coverFinder).dy;
      expect(arrowScrolledTop, lessThan(scrolledTop));

      // 4. Can scroll using PageDown key
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final pageDownTop = tester.getTopLeft(coverFinder).dy;
      expect(pageDownTop, lessThan(arrowScrolledTop));

      // Native attach notification exposes Hand without a pen event.
      expect(find.byTooltip('Connect stylus / pen'), findsNothing);
      setTabletHardware(tester, ['test-tablet']);
      await tester.pumpAndSettle();

      // Hand tool is now REVEALED and visible in the toolbar!
      expect(handFinder, findsOneWidget);

      // Select Hand tool
      await tester.tap(handFinder);
      await tester.pumpAndSettle();
      expect(find.textContaining('· hand'), findsOneWidget);

      // Disconnect stylus: Hand tool hides again and tool switches to previousTool (select)
      setTabletHardware(tester, []);
      await tester.pumpAndSettle();
      expect(handFinder, findsNothing);
      expect(find.textContaining('· select'), findsOneWidget);

      // 6. Connecting stylus via actual Stylus Pointer event automatically reveals Hand tool!
      await tester.sendEventToBinding(
        PointerDownEvent(
          kind: PointerDeviceKind.stylus,
          position: viewerCenter,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(
        PointerUpEvent(kind: PointerDeviceKind.stylus, position: viewerCenter),
      );
      await tester.pumpAndSettle();

      // Automatically detected stylus: Hand tool is visible!
      expect(handFinder, findsOneWidget);
    },
  );

  testWidgets(
    'on top header in full screen mode, home button, back/forward and tabs move to the very left edge',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final directory = Directory.systemTemp.createTempSync(
        'novi-fullscreen-test-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        directory.deleteSync(recursive: true);
      });

      Widget buildHeader({required bool isFullScreen}) {
        return FTheme(
          data: FTheme.neutral.dark.desktop,
          child: DesktopTheme(
            child: Material(
              child: DesktopWindowHeader(
                canGoBack: true,
                canGoForward: true,
                onBack: () {},
                onForward: () {},
                onToggleSidebar: () {},
                notes: const [],
                openIds: const ['tab-1'],
                currentId: 'tab-1',
                showTabs: true,
                onSelectTab: (_) {},
                onCloseTab: (_) {},
                onCreate: ([_]) {},
                onOpenDocument: () {},
                onTransfer: (_) {},
                isFullScreen: isFullScreen,
              ),
            ),
          ),
        );
      }

      // 1. Render DesktopWindowHeader in normal windowed mode (isFullScreen: false)
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: buildHeader(isFullScreen: false))),
      );
      await tester.pumpAndSettle();

      final homeFinder = find.byKey(const Key('home-button'));
      expect(homeFinder, findsOneWidget);

      final normalHomeLeft = tester.getTopLeft(homeFinder).dx;
      // In normal mode on macOS, DragToMoveArea takes 78px for macOS traffic light buttons
      expect(normalHomeLeft, equals(78.0));

      // 2. Render DesktopWindowHeader in full screen mode (isFullScreen: true)
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: buildHeader(isFullScreen: true))),
      );
      await tester.pumpAndSettle();

      final fullScreenHomeLeft = tester.getTopLeft(homeFinder).dx;
      // In full screen mode, the home button starts from the very left edge (0.0)!
      expect(fullScreenHomeLeft, equals(0.0));

      // Back and forward buttons and tabs follow directly from the left edge
      final backFinder = find.byTooltip('Back to documents');
      final forwardFinder = find.byTooltip('Forward');
      expect(tester.getTopLeft(backFinder).dx, lessThan(normalHomeLeft));
      expect(tester.getTopLeft(forwardFinder).dx, lessThan(normalHomeLeft));

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'trackpad two-finger scroll overscroll creates new page smoothly',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('novi_test_trackpad_');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      final store = LibraryStore('${dir.path}/novi.sqlite');
      final note = Notebook(
        id: 'test-trackpad-scroll',
        title: 'Trackpad Note',
        kind: 'Notebook',
      );
      store.save(note);
      store.close();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trackpad Note').first);
      await tester.pumpAndSettle();

      final viewerFinder = find.byKey(ValueKey('view-${note.id}'));
      expect(viewerFinder, findsOneWidget);
      final center = tester.getCenter(viewerFinder);

      // Scroll to bottom first using mouse or trackpad pan
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 3000),
        ),
      );
      await tester.pumpAndSettle();

      // Send trackpad pan zoom start
      await tester.sendEventToBinding(
        PointerPanZoomStartEvent(
          position: center,
        ),
      );
      await tester.pump();

      // Pan up on trackpad (panDelta.dy = -40 => scroll down 40)
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -40),
        ),
      );
      await tester.pump();

      // Loader is visible with progress
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Pan further past threshold (panDelta.dy = -150 => scroll down 150, total 190 >= 180)
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -150),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Reaching threshold creates a new page!
      final checkStore = LibraryStore('${dir.path}/novi.sqlite');
      final reloaded = checkStore.load().firstWhere((n) => n.id == note.id);
      expect(reloaded.pages.length, equals(2));
      expect(find.textContaining('Page 3 created'), findsOneWidget);
      checkStore.close();

      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(
          position: center,
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'overscroll page creation animates view into the new page and allows smooth continuous scrolling',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('novi_test_create_anim_');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      final store = LibraryStore('${dir.path}/novi.sqlite');
      final note = Notebook(
        id: 'test-create-anim',
        title: 'Anim Create Note',
        kind: 'Notebook',
      );
      store.save(note);
      store.close();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anim Create Note').first);
      await tester.pumpAndSettle();

      final viewerFinder = find.byKey(ValueKey('view-${note.id}'));
      final center = tester.getCenter(viewerFinder);

      // Scroll to bottom
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 3000),
        ),
      );
      await tester.pumpAndSettle();

      final ivBefore = tester.widget<InteractiveViewer>(viewerFinder);
      final tyBefore = ivBefore.transformationController!.value.storage[13];

      // Pan past threshold to trigger page creation
      await tester.sendEventToBinding(
        PointerPanZoomStartEvent(position: center),
      );
      await tester.pump();
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -200),
        ),
      );
      await tester.pump();

      // Page was added and animated glide begins
      final checkStore = LibraryStore('${dir.path}/novi.sqlite');
      final reloaded = checkStore.load().firstWhere((n) => n.id == note.id);
      expect(reloaded.pages.length, equals(2));
      checkStore.close();

      // Advance animation halfway (150ms)
      await tester.pump(const Duration(milliseconds: 150));
      final ivMid = tester.widget<InteractiveViewer>(viewerFinder);
      final tyMid = ivMid.transformationController!.value.storage[13];
      // View has smoothly glided down towards the new page
      expect(tyMid, lessThan(tyBefore));

      // User continues continuous scrolling during the animation
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -80),
        ),
      );
      await tester.pump();

      final ivContinuous = tester.widget<InteractiveViewer>(viewerFinder);
      final tyContinuous = ivContinuous.transformationController!.value.storage[13];
      // Continuous scroll was accepted and drove the canvas even further down
      expect(tyContinuous, lessThan(tyMid));

      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(position: center),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Page 3 created'), findsOneWidget);
    },
  );

  testWidgets(
    'trackpad overscroll release before threshold triggers bounce-back animation',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('novi_test_bounce_');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      final store = LibraryStore('${dir.path}/novi.sqlite');
      final note = Notebook(
        id: 'test-trackpad-bounce',
        title: 'Bounce Note',
        kind: 'Notebook',
      );
      store.save(note);
      store.close();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bounce Note').first);
      await tester.pumpAndSettle();

      final viewerFinder = find.byKey(ValueKey('view-${note.id}'));
      final center = tester.getCenter(viewerFinder);

      // Scroll to bottom first
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 3000),
        ),
      );
      await tester.pumpAndSettle();

      // Pan up on trackpad (overscroll by 60, well below 180 threshold)
      await tester.sendEventToBinding(
        PointerPanZoomStartEvent(position: center),
      );
      await tester.pump();
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -60),
        ),
      );
      await tester.pump();

      // Loader is visible showing progress (~33%)
      expect(find.text('Scroll to add page 33%'), findsOneWidget);

      // Release finger before threshold
      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(position: center),
      );
      await tester.pump();

      // Bounce-back animation smoothly restores overscroll
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Overcroll is reset and no new page was created
      final checkStore = LibraryStore('${dir.path}/novi.sqlite');
      final reloaded = checkStore.load().firstWhere((n) => n.id == note.id);
      expect(reloaded.pages.length, equals(1)); // Cover + 1 page
      expect(find.textContaining('Scroll to add page'), findsNothing);
      checkStore.close();
    },
  );

  testWidgets(
    'trackpad release during in-bounds scrolling engages inertial fling and gradually decelerates',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('novi_test_fling_');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      final store = LibraryStore('${dir.path}/novi.sqlite');
      final note = Notebook(
        id: 'test-trackpad-fling',
        title: 'Fling Note',
        kind: 'Notebook',
        pages: [NotebookPage(), NotebookPage()], // 3 sheets total
      );
      store.save(note);
      store.close();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Fling Note').first);
      await tester.pumpAndSettle();

      final viewerFinder = find.byKey(ValueKey('view-${note.id}'));
      final center = tester.getCenter(viewerFinder);

      // Start trackpad pan
      await tester.sendEventToBinding(
        PointerPanZoomStartEvent(
          position: center,
          timeStamp: Duration.zero,
        ),
      );
      await tester.pump();

      // Pan upwards quickly (moving finger up to scroll down)
      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -40),
          timeStamp: const Duration(milliseconds: 16),
        ),
      );
      await tester.pump();

      await tester.sendEventToBinding(
        PointerPanZoomUpdateEvent(
          position: center,
          panDelta: const Offset(0, -40),
          timeStamp: const Duration(milliseconds: 32),
        ),
      );
      await tester.pump();

      // Release trackpad while moving with velocity
      await tester.sendEventToBinding(
        PointerPanZoomEndEvent(
          position: center,
          timeStamp: const Duration(milliseconds: 34),
        ),
      );
      await tester.pump();

      final ivAtRelease = tester.widget<InteractiveViewer>(viewerFinder);
      final tyAtRelease = ivAtRelease.transformationController!.value.storage[13];
      // Has scrolled down from 0.0
      expect(tyAtRelease, lessThan(0.0));

      // Advance by 150ms: inertial fling continues scrolling forward!
      await tester.pump(const Duration(milliseconds: 150));
      final ivDuringFling = tester.widget<InteractiveViewer>(viewerFinder);
      final tyDuringFling = ivDuringFling.transformationController!.value.storage[13];
      expect(tyDuringFling, lessThan(tyAtRelease));

      // Advance until fling simulation decelerates to a stop
      await tester.pumpAndSettle();
      final ivAtRest = tester.widget<InteractiveViewer>(viewerFinder);
      final tyAtRest = ivAtRest.transformationController!.value.storage[13];
      expect(tyAtRest, lessThanOrEqualTo(tyDuringFling));
    },
  );

  testWidgets(
    'canvas scroll indicator appears on right edge and allows dragging to scroll smoothly',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('novi_test_indicator_');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      final store = LibraryStore('${dir.path}/novi.sqlite');
      final note = Notebook(
        id: 'test-scroll-indicator',
        title: 'Scroll Indicator Note',
        kind: 'Notebook',
      );
      store.save(note);
      store.close();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scroll Indicator Note').first);
      await tester.pumpAndSettle();

      // The notebook has cover + 1 page = 2 sheets (~2000px height > 800px viewport)
      // Normal scroll indicator appears on the right edge!
      final indicatorFinder = find.byKey(const Key('canvas-scroll-indicator'));
      expect(indicatorFinder, findsOneWidget);

      final indicatorTopRight = tester.getTopRight(indicatorFinder);
      expect(indicatorTopRight.dx, greaterThan(1170)); // Pinned to the right edge

      // Drag the scroll indicator down
      await tester.drag(indicatorFinder, const Offset(0, 150));
      await tester.pumpAndSettle();

      // Verify canvas scrolled down (cover moved up)
      final coverFinder = find.byKey(ValueKey('cover-page-${note.id}'));
      expect(tester.getTopLeft(coverFinder).dy, lessThan(0.0));
    },
  );

  testWidgets(
    'content page manager collapses and opens, shows thumbnails, bookmarks, and allows adding pages and jumping',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('novi_test_pages_');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(dir.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        dir.deleteSync(recursive: true);
      });
      final store = LibraryStore('${dir.path}/novi.sqlite');
      final note = Notebook(
        id: 'test-pages-sidebar',
        title: 'Pages Manager Note',
        kind: 'Notebook',
      );
      store.save(note);
      store.close();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pages Manager Note').first);
      await tester.pumpAndSettle();

      // 1. Pages manager is initially closed
      expect(find.byType(PagesSidebar), findsNothing);

      // 2. Open page manager using toolbar button
      final toggleButton = find.byKey(const Key('toolbar-toggle-pages'));
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // PagesSidebar is now open!
      expect(find.byType(PagesSidebar), findsOneWidget);
      expect(find.text('Pages'), findsOneWidget);

      // Page 1 (cover) and Page 2 (paper) thumbnails are visible
      expect(
        find.byKey(const ValueKey('sidebar-page-thumbnail-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sidebar-page-thumbnail-1')),
        findsOneWidget,
      );

      // 3. Add page using the '+' dashed card in PagesSidebar
      final addPageButton = find.byKey(const Key('sidebar-add-page-button'));
      expect(addPageButton, findsOneWidget);
      await tester.tap(addPageButton);
      await tester.pumpAndSettle();

      // A new page is created!
      expect(
        find.byKey(const ValueKey('sidebar-page-thumbnail-2')),
        findsOneWidget,
      );
      final checkStore = LibraryStore('${dir.path}/novi.sqlite');
      final reloaded = checkStore.load().firstWhere((n) => n.id == note.id);
      expect(reloaded.pages.length, equals(2)); // Cover + 2 pages = 3 total
      checkStore.close();

      // 4. Tap thumbnail 0 to scroll to Page 1
      await tester.tap(find.byKey(const ValueKey('sidebar-page-thumbnail-0')));
      await tester.pumpAndSettle();
      final coverFinder = find.byKey(ValueKey('cover-page-${note.id}'));
      expect(tester.getTopLeft(coverFinder).dy, greaterThan(0.0));

      // 5. Close PagesSidebar using the 'X' button
      final closeButton = find.byKey(const Key('close-pages-sidebar'));
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // PagesSidebar is collapsed!
      expect(find.byType(PagesSidebar), findsNothing);

      // 6. Reopen using the header sidebar toggle button
      final headerSidebarButton = find.byTooltip('Toggle sidebar');
      await tester.tap(headerSidebarButton);
      await tester.pumpAndSettle();
      expect(find.byType(PagesSidebar), findsOneWidget);
    },
  );

  testWidgets(
    'toolbar on top shows icon-only items with tooltips, hovering sub-components, and select as initial tool',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final directory = Directory.systemTemp.createTempSync('novi-toolbar-test-');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        directory.deleteSync(recursive: true);
      });

      final dbPath = '${directory.path}/novi.sqlite';
      final seed = LibraryStore(dbPath);
      seed.save(Notebook(id: 'nb1', title: 'Toolbar Notebook'));
      seed.close();

      await tester.pumpWidget(const NoviApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      // Open notebook
      await tester.tap(find.text('Toolbar Notebook').first);
      await tester.pumpAndSettle();

      final toolbarFinder = find.byType(WorkspaceToolbar);
      expect(toolbarFinder, findsOneWidget);
      final toolbar = tester.widget<WorkspaceToolbar>(toolbarFinder);

      // 1. Initial tool is Select and is the first tool on the line
      expect(toolbar.session.tool, EditorTool.select);
      final centeredToolsFinder = find.byKey(const Key('centered-tools'));
      expect(centeredToolsFinder, findsOneWidget);
      final rowWidget = tester.widget<Row>(centeredToolsFinder);
      final firstChild = rowWidget.children.first as Padding;
      expect((firstChild.child as KeyedSubtree).key, const ValueKey('tool-select'));

      // 2. Toolbar tool items are icon-only (DesktopToolButton contains no text child)
      final selectButtonFinder = find.byKey(const ValueKey('tool-select'));
      expect(selectButtonFinder, findsOneWidget);
      expect(
        find.descendant(of: selectButtonFinder, matching: find.byType(Text)),
        findsNothing,
      );
      final drawButtonFinder = find.byKey(const ValueKey('tool-pen'));
      expect(drawButtonFinder, findsOneWidget);
      expect(
        find.descendant(of: drawButtonFinder, matching: find.byType(Text)),
        findsNothing,
      );

      // 3. Tooltips are configured for tools with Lasso Selection (V) for select
      expect(find.byTooltip('Lasso Selection (V)'), findsOneWidget);
      expect(find.byTooltip('Draw'), findsOneWidget);
      expect(find.byTooltip('Highlight'), findsOneWidget);
      expect(find.byTooltip('Erase'), findsOneWidget);
      expect(find.byTooltip('Type'), findsOneWidget);

      // 4. Select tool has NO floating option sub-menu
      expect(find.byKey(const Key('context-controls')), findsNothing);

      // 5. Clicking select button while already selected pops open the Lasso Tool menu dialog
      await tester.tap(selectButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Lasso Tool'), findsOneWidget);
      expect(find.text('Lasso Type'), findsOneWidget);
      expect(find.text('Rectangular'), findsOneWidget);
      expect(find.text('Freehand'), findsOneWidget);
      expect(find.text('Included in Selection'), findsOneWidget);
      expect(find.text('Handwriting'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Shapes'), findsOneWidget);
      expect(find.text('Arrows'), findsOneWidget);
      expect(find.text('Text Boxes'), findsOneWidget);
      expect(find.text('Equations'), findsOneWidget);
      expect(find.text('Tape'), findsOneWidget);
      expect(find.text('Sticky Notes'), findsOneWidget);

      // Switch lasso type to Freehand
      expect(toolbar.session.lassoType, LassoType.rectangular);
      await tester.tap(find.byKey(const Key('lasso-type-freehand')));
      await tester.pumpAndSettle();
      expect(toolbar.session.lassoType, LassoType.freehand);

      // Toggle switch in selection
      expect(toolbar.session.lassoIncludes['Handwriting'], isTrue);
      await tester.tap(find.byKey(const ValueKey('lasso-switch-Handwriting')));
      await tester.pumpAndSettle();
      expect(toolbar.session.lassoIncludes['Handwriting'], isFalse);

      // Dismiss popover by tapping outside
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Lasso Tool'), findsNothing);

      // 6. Switching to Draw tool reveals floating component sub-controls for pen
      await tester.tap(drawButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbar.session.tool, EditorTool.pen);

      final contextControlsFinder = find.byKey(const Key('context-controls'));
      expect(contextControlsFinder, findsOneWidget);
      expect(find.byTooltip('Automatic ink contrast'), findsOneWidget);
      expect(find.byTooltip('Ink shade 1'), findsOneWidget);
      expect(find.byTooltip('Ink shade 4'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.byTooltip('Reset view'), findsOneWidget);

      // 7. More controls are out of the header toolbar and floating over the canvas
      expect(
        find.descendant(of: toolbarFinder, matching: contextControlsFinder),
        findsNothing,
      );
      expect(find.byType(FloatingToolControls), findsOneWidget);

      // 8. Floating controls can be dragged around the screen
      final dragGrip = find.byKey(const Key('floating-drag-handle'));
      expect(dragGrip, findsOneWidget);
      await tester.drag(dragGrip, const Offset(60, 40));
      await tester.pumpAndSettle();
      final floatingState = tester.state<FloatingToolControlsState>(
        find.byType(FloatingToolControls),
      );
      expect(floatingState.dragOffset.dx, greaterThan(0));
      expect(floatingState.dragOffset.dy, greaterThan(0));
    },
  );
}
