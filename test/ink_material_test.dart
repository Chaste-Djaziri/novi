import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novi/ink_material.dart';
import 'package:novi/main.dart';
import 'package:novi/notebook.dart';
import 'package:novi/workspace_tools.dart';

const kinds = ['fountain', 'ballpoint', 'brush', 'pencil', 'highlighter', 'tape'];
Map<String, dynamic> style(String kind, {double width = 14}) => {
  'kind': kinds.indexOf(kind) < 3 ? 'pen' : kind,
  'penType': kind,
  'materialVersion': 1,
  'width': width,
  'opacity': kind == 'highlighter' ? 0.35 : kind == 'tape' ? 0.95 : 1.0,
  'color': 0xff3355bb,
};
Future<ui.Image> render(String kind, {bool dark = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(dark ? const Color(0xff222222) : Colors.white, BlendMode.src);
  InkPainter([
    [[25, 35, 0.1], [90, 35, 0.5], [155, 35, 1]],
    [[25, 75, 1], [90, 75, 1], [155, 75, 1]],
    [[155, 105, 1]],
  ], styles: [style(kind), style(kind), style(kind)]).paint(canvas, const Size(180, 130));
  final picture = recorder.endRecording();
  final image = await picture.toImage(180, 130);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('/System/Library/Fonts/SFNS.ttf');
    if (font.existsSync()) {
      await (FontLoader('InkPreview')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())))).load();
    }
  });
  test('all materials have matching size geometry and pressure response', () {
    final session = EditorSession(Notebook(id: 'ink', title: 'Ink'));
    addTearDown(session.dispose);
    session.tool = EditorTool.pen;
    for (final mode in WritingMode.values) {
      session.writingMode = mode;
      for (final width in [2.0, 4.0, 7.0]) {
        session.width = width;
        final material = InkMaterial(session.inkStyle());
        expect(material.width, InkMaterial.toolWidth(session.inkKind, width));
        final dot = material.footprint([[40, 40, 1]]).getBounds();
        expect(dot, material.nib(const Offset(40, 40), 1).getBounds());
        expect(dot.width, greaterThan(0));
        expect(material.footprint([[40, 40, 0.2], [41, 40, 1]]).getBounds().width, greaterThan(0));
        expect(material.footprint([[10, 40, 0.2], [500, 40, 1]]).contains(const Offset(250, 40)), isTrue);
      }
    }
    expect(InkMaterial(style('ballpoint')).pressureScale(0), 0.9);
    expect(InkMaterial(style('brush')).pressureScale(0), 0.15);
    expect(InkMaterial(style('highlighter')).pressureScale(0), 1);
    expect(InkMaterial(style('tape')).pressureScale(0), 1);
    session.width = 7;
    session.eraserRadius = 26;
    expect(session.width, 7);
  });

  test('unchanged ink skips repaint but in-place stroke edits invalidate it', () {
    final strokes = <List<List<double>>>[[[10, 10, 1], [30, 30, 1]]];
    final styles = [style('pencil')];
    final old = InkPainter(strokes, styles: styles);
    expect(InkPainter(strokes, styles: styles).shouldRepaint(old), isFalse);
    strokes.first.last[0] = 35;
    final moved = InkPainter(strokes, styles: styles);
    expect(moved.shouldRepaint(old), isTrue);
    styles.first['color'] = 0xff000000;
    expect(InkPainter(strokes, styles: styles).shouldRepaint(moved), isTrue);
  });

  test('material metadata survives SQLite and both portable formats', () {
    final dir = Directory.systemTemp.createTempSync('novi-ink');
    addTearDown(() => dir.deleteSync(recursive: true));
    final note = Notebook(id: 'materials', title: 'Materials',
      strokes: [for (final _ in kinds) [[20, 20, 0.3], [80, 80, 1]]],
      inkStyles: [for (final kind in kinds) style(kind)]);
    final store = LibraryStore('${dir.path}/notes.sqlite');
    store.save(note);
    store.close();
    final reopened = LibraryStore('${dir.path}/notes.sqlite');
    addTearDown(reopened.close);
    expect(reopened.load().single.inkStyles, note.inkStyles);
    expect(decodePortable(encodePortable([note], backup: false), backup: false).single.inkStyles, note.inkStyles);
    expect(decodePortable(encodePortable([note], backup: true), backup: true).single.inkStyles, note.inkStyles);
  });

  test('rendered materials are distinct, deterministic and marker joins stay uniform', () async {
    final images = <String, List<int>>{};
    for (final kind in kinds) {
      final first = await render(kind);
      final second = await render(kind);
      final bytes = (await first.toByteData())!.buffer.asUint8List();
      expect((await second.toByteData())!.buffer.asUint8List(), bytes);
      images[kind] = bytes;
      if (kind == 'highlighter') {
        int channel(int x) => bytes[(75 * 180 + x) * 4];
        expect(channel(70), channel(90));
        expect(channel(110), channel(90));
      }
      first.dispose();
      second.dispose();
    }
    for (var i = 0; i < kinds.length; i++) {
      for (var j = i + 1; j < kinds.length; j++) {
        expect(images[kinds[i]], isNot(equals(images[kinds[j]])));
      }
    }
  });

  test('write light and dark material comparison for visual inspection', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < kinds.length; i++) {
      for (var column = 0; column < 2; column++) {
        final image = await render(kinds[i], dark: column == 1);
        canvas.drawImage(image, Offset(column * 180, i * 155 + 25), Paint());
        image.dispose();
        final label = TextPainter(text: TextSpan(text: kinds[i], style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'InkPreview')), textDirection: TextDirection.ltr)..layout();
        canvas.drawRect(Rect.fromLTWH(column * 180, i * 155, 180, 25), Paint()..color = Colors.black);
        label.paint(canvas, Offset(column * 180 + 5, i * 155 + 3));
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(360, kinds.length * 155);
    final file = File('build/ui-preview/ink-materials.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
