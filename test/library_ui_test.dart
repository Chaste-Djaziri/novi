import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:novi/main.dart';
import 'package:novi/notebook.dart';

import 'widget_test.dart' show TestPaths;

void main() {
  testWidgets(
    'grayscale library, creation preview, favorites and minimum-size layout',
    (tester) async {
      // Use an available desktop font for readable local preview artifacts.
      // Other platforms still run all layout and behavior assertions.
      await tester.runAsync(() async {
        final font = File('/System/Library/Fonts/SFNS.ttf');
        if (await font.exists()) {
          final loader = FontLoader('Roboto')
            ..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('novi-library-ui');
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = TestPaths(directory.path);
      addTearDown(() {
        PathProviderPlatform.instance = original;
        directory.deleteSync(recursive: true);
      });
      final store = LibraryStore('${directory.path}/novi.sqlite');
      for (var i = 0; i < 4; i++) {
        store.save(
          Notebook(
            id: '$i',
            title: [
              'Everyday thoughts',
              'Ideas & sketches',
              'Reading notes',
              'The next chapter',
            ][i],
            cover: [0xff303030, 0xff656565, 0xff909090, 0xffe0e0e0][i],
          ),
        );
      }
      store.close();
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: captureKey, child: const NoviApp()),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/ui-preview/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('library');
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Whiteboard'));
      await tester.enterText(
        find.byKey(const Key('document-name')),
        'Design ideas',
      );
      await tester.tap(find.text('Squared'));
      await tester.pumpAndSettle();
      await capture('creation');
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Design ideas'), findsOneWidget);
      expect(find.text('Whiteboard / Squared'), findsOneWidget);
      await capture('editor');
      tester.view.physicalSize = const Size(960, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back to documents'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Favorite Design ideas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Favorite Design ideas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Design ideas'), findsWidgets);
      expect(find.text('Everyday thoughts'), findsNothing);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('minimum-dialog');
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = LibraryStore('${directory.path}/novi.sqlite');
      final created = reopened.load().firstWhere(
        (n) => n.title == 'Design ideas',
      );
      expect(created.kind, 'Whiteboard');
      expect(created.paper, 'Squared');
      expect(created.landscape, isTrue);
      expect(created.favorite, isTrue);
      reopened.close();
    },
  );
}
