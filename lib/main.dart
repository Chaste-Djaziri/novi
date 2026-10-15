import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'notebook.dart';
import 'library_ui.dart';
import 'workspace_tools.dart';

import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoviApp());
}

class NoviApp extends StatelessWidget {
  const NoviApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Novi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff090909),
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Color(0xffbbbbbb),
        surface: Color(0xff1c1c1c),
        onSurface: Color(0xffeeeeee),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff242424),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: const Color(0xff333333),
      useMaterial3: true,
    ),
    home: const Workspace(),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  LibraryStore? store;
  List<Notebook> notes = [];
  Notebook? current;
  final sessions = <String, EditorSession>{};
  final openIds = <String>[];
  EditorSession get session => sessions[current!.id]!;
  TextEditingController get text => session.text;
  List<Notebook> get undo => session.undo;
  List<Notebook> get redo => session.redo;
  Offset? gestureStart;
  Offset? lastPoint;
  Rect? selectionBox;
  bool movingSelection = false;
  bool editedGesture = false;
  Map<String, dynamic>? activeStyle;
  List<List<double>>? activeStroke;
  int? activePointer;
  bool get drawing => session.tool != EditorTool.text;
  bool inLibrary = true;
  String status = 'Opening local library…';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final opened = LibraryStore('${directory.path}/novi.sqlite');
      if (!mounted) {
        opened.close();
        return;
      }
      try {
        notes = opened.load();
      } catch (_) {
        opened.close();
        rethrow;
      }
      store = opened;
      if (notes.isNotEmpty) {
        select(notes.first);
      }
      setState(() {
        status = 'Saved locally';
        inLibrary = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Could not open library: $e');
      }
    }
  }

  void select(Notebook note) {
    finishStroke();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      current = notes.firstWhere((n) => n.id == note.id);
      sessions.putIfAbsent(note.id, () => EditorSession(current!));
      if (!openIds.contains(note.id)) {
        openIds.add(note.id);
      }
      inLibrary = false;
      activeStroke = null;
      activePointer = null;
      gestureStart = null;
      selectionBox = null;
    });
  }

  void chooseTool(EditorTool tool) {
    finishStroke();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      session.tool = tool;
      session.selection.clear();
      selectionBox = null;
    });
  }

  void closeTab(String id) {
    finishStroke();
    final index = openIds.indexOf(id);
    setState(() {
      openIds.remove(id);
    });
    if (current?.id == id) {
      if (openIds.isEmpty) {
        setState(() => inLibrary = true);
      } else {
        select(
          notes.firstWhere(
            (n) => n.id == openIds[math.min(index, openIds.length - 1)],
          ),
        );
      }
    }
  }

  void zoom(double factor) {
    setState(() {
      if (factor == 0) {
        session.view.value = Matrix4.identity();
      } else {
        final scale = session.view.value.getMaxScaleOnAxis();
        final target = (scale * factor).clamp(0.25, 3.0);
        final matrix = session.view.value.clone();
        matrix.multiply(
          Matrix4.diagonal3Values(target / scale, target / scale, 1),
        );
        session.view.value = matrix;
      }
    });
  }

  void formatText({double? size, bool? bold}) {
    snapshot();
    setState(() {
      current!.fontSize = size ?? current!.fontSize;
      current!.boldText = bold ?? current!.boldText;
      save();
    });
  }

  void snapshot() {
    undo.add(current!.copy());
    if (undo.length > 100) {
      undo.removeAt(0);
    }
    redo.clear();
  }

  void save() {
    try {
      store!.save(current!);
      status = 'Saved locally';
    } catch (e) {
      status = 'Save failed — keep Novi open: $e';
    }
  }

  Future<void> create() async {
    final note = await showDialog<Notebook>(
      context: context,
      builder: (_) => const CreateDocumentDialog(),
    );
    if (note == null || !mounted) {
      return;
    }
    try {
      store!.save(note);
      notes.add(note);
      select(note);
      setState(() => status = 'Saved locally');
    } catch (e) {
      setState(() => status = 'Could not create document: $e');
    }
  }

  Future<void> styleDocument() async {
    final changed = await showDialog<Notebook>(
      context: context,
      builder: (_) => CreateDocumentDialog(existing: current),
    );
    if (changed == null || !mounted) {
      return;
    }
    snapshot();
    notes[notes.indexWhere((n) => n.id == changed.id)] = changed;
    setState(() {
      current = changed;
      save();
    });
  }

  void toggleFavorite(Notebook note) {
    final changed = note.copy()..favorite = !note.favorite;
    try {
      store!.save(changed);
      setState(() {
        notes[notes.indexWhere((n) => n.id == note.id)] = changed;
        if (current?.id == note.id) {
          current = changed;
        }
      });
    } catch (e) {
      setState(() => status = 'Could not save favorite: $e');
    }
  }

  void history(bool backwards) {
    final source = backwards ? undo : redo;
    final target = backwards ? redo : undo;
    if (source.isEmpty) {
      return;
    }
    target.add(current!.copy());
    final restored = source.removeLast();
    notes[notes.indexWhere((n) => n.id == restored.id)] = restored;
    setState(() {
      current = restored;
      session.selection.clear();
      text.text = restored.text;
      save();
    });
  }

  Future<void> transfer(String action) async {
    final backup = action == 'backup' || action == 'restore';
    final importing = action == 'import' || action == 'restore';
    final extension = backup ? 'novibackup' : 'novi';
    try {
      if (importing) {
        final file = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: extension, extensions: [extension]),
          ],
        );
        if (file == null) {
          return;
        }
        final imported = decodePortable(
          await file.readAsBytes(),
          backup: backup,
        );
        // Restore adds copies, preserving all existing local work.
        for (var i = 0; i < imported.length; i++) {
          imported[i].id = '${newId()}-$i';
        }
        store!.merge(imported);
        if (!mounted) {
          return;
        }
        notes.addAll(imported);
        if (imported.isNotEmpty) {
          select(imported.first);
        }
        setState(
          () => status = '${imported.length} notebook(s) imported as copies',
        );
      } else {
        final destination = await getSaveLocation(
          suggestedName: backup
              ? 'Novi-library.$extension'
              : 'Notebook.$extension',
          acceptedTypeGroups: [
            XTypeGroup(label: extension, extensions: [extension]),
          ],
        );
        if (destination == null) {
          return;
        }
        final bytes = encodePortable(
          backup ? notes : [current!],
          backup: backup,
        );
        await File(destination.path).writeAsBytes(bytes, flush: true);
        if (mounted) {
          setState(
            () =>
                status = backup ? 'Library backup saved' : 'Notebook exported',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => status = 'File operation failed: $e');
      }
    }
  }

  @override
  void dispose() {
    for (final editor in sessions.values) {
      editor.dispose();
    }
    store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: inLibrary || current == null
        ? LibraryView(
            notes: notes,
            enabled: store != null,
            onCreate: create,
            onOpen: select,
            onFavorite: toggleFavorite,
            onTransfer: transfer,
          )
        : editor(),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xff262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      child: Text(
        '$status  ·  Offline · No account required',
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
    ),
  );

  Widget editor() {
    final note = current!;
    final foreground = note.tone == 'Dark'
        ? Colors.white
        : const Color(0xff222222);
    final tool = session.tool;
    final pageWidth = note.landscape ? 980.0 : 760.0;
    final pageHeight = note.landscape ? 760.0 : 980.0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
            history(true),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: true,
          shift: true,
        ): () =>
            history(false),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            history(true),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () =>
            history(false),
        if (tool != EditorTool.text)
          const SingleActivator(LogicalKeyboardKey.delete): deleteSelection,
        if (tool != EditorTool.text)
          const SingleActivator(LogicalKeyboardKey.backspace): deleteSelection,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Material(
              color: const Color(0xff141414),
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to documents',
                      onPressed: () {
                        finishStroke();
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => inLibrary = true);
                      },
                      icon: const Icon(Icons.home_outlined),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'novi.',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: openIds.map((id) {
                          final tab = notes.firstWhere((n) => n.id == id);
                          return Padding(
                            padding: const EdgeInsets.only(top: 7, right: 4),
                            child: Material(
                              color: note.id == id
                                  ? const Color(0xff303030)
                                  : const Color(0xff191919),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(9),
                              ),
                              child: InkWell(
                                onTap: () => select(tab),
                                child: SizedBox(
                                  width: 190,
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      Icon(kindIcon(tab.kind), size: 15),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          tab.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Close tab ${tab.title}',
                                        onPressed: () => closeTab(id),
                                        icon: const Icon(Icons.close, size: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open document',
                      onPressed: () {
                        finishStroke();
                        setState(() => inLibrary = true);
                      },
                      icon: const Icon(Icons.folder_open_outlined, size: 19),
                    ),
                    IconButton(
                      tooltip: 'New document',
                      onPressed: create,
                      icon: const Icon(Icons.add, size: 19),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Import, export and backup',
                      onSelected: transfer,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Export notebook'),
                        ),
                        PopupMenuItem(
                          value: 'backup',
                          child: Text('Back up library'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            WorkspaceToolbar(
              session: session,
              note: note,
              onTool: chooseTool,
              onSettings: () => setState(() {}),
              onUndo: undo.isEmpty ? null : () => history(true),
              onRedo: redo.isEmpty ? null : () => history(false),
              onDelete: session.selection.isEmpty ? null : deleteSelection,
              onZoom: zoom,
              onStyle: styleDocument,
              onFontSize: (v) => formatText(size: v),
              onBold: () => formatText(bold: !note.boldText),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => InteractiveViewer(
                  key: ValueKey('view-${note.id}'),
                  transformationController: session.view,
                  constrained: false,
                  minScale: 0.25,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(500),
                  panEnabled: tool == EditorTool.hand,
                  scaleEnabled: tool == EditorTool.hand,
                  onInteractionEnd: (_) => setState(() {}),
                  child: SizedBox(
                    width: math.max(constraints.maxWidth, pageWidth + 48),
                    height: math.max(constraints.maxHeight, pageHeight + 48),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: pageWidth,
                          height: pageHeight,
                          child: ClipRect(
                            child: CustomPaint(
                              painter: PaperPainter(note.paper, note.tone),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 28,
                                    top: 28,
                                    right: 28,
                                    bottom: 28,
                                    child: IgnorePointer(
                                      ignoring: tool != EditorTool.text,
                                      child: TextField(
                                        key: ValueKey('text-${note.id}'),
                                        controller: text,
                                        maxLines: null,
                                        expands: true,
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        style: TextStyle(
                                          color: foreground,
                                          fontSize: note.fontSize,
                                          fontWeight: note.boldText
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          height: 1.6,
                                        ),
                                        cursorColor: foreground,
                                        decoration: InputDecoration(
                                          filled: false,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          hintText: 'Write your thoughts…',
                                          hintStyle: TextStyle(
                                            color: foreground.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            snapshot();
                                            note.text = value;
                                            save();
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      ignoring:
                                          tool == EditorTool.text ||
                                          tool == EditorTool.hand,
                                      child: MouseRegion(
                                        cursor: tool == EditorTool.select
                                            ? SystemMouseCursors.precise
                                            : SystemMouseCursors.precise,
                                        child: Listener(
                                          behavior: HitTestBehavior.opaque,
                                          onPointerDown: pointerDown,
                                          onPointerMove: pointerMove,
                                          onPointerUp: (e) {
                                            if (e.pointer == activePointer) {
                                              finishStroke();
                                            }
                                          },
                                          onPointerCancel: (e) {
                                            if (e.pointer == activePointer) {
                                              finishStroke();
                                            }
                                          },
                                          child: CustomPaint(
                                            painter: InkPainter(
                                              [...note.strokes, ?activeStroke],
                                              color: foreground,
                                              styles: [
                                                ...note.inkStyles,
                                                ?activeStyle,
                                              ],
                                              selected: session.selection,
                                              selectionBox: selectionBox,
                                            ),
                                            size: Size.infinite,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${note.kind} / ${note.paper}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    'Page 1 of 1 · ${session.tool.name}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void normalizeStyles() {
    while (current!.inkStyles.length < current!.strokes.length) {
      current!.inkStyles.add({});
    }
  }

  Rect? selectedBounds() {
    final points = session.selection
        .where((i) => i < current!.strokes.length)
        .expand((i) => current!.strokes[i])
        .toList();
    if (points.isEmpty) {
      return null;
    }
    return Rect.fromLTRB(
      points.map((p) => p[0]).reduce(math.min),
      points.map((p) => p[1]).reduce(math.min),
      points.map((p) => p[0]).reduce(math.max),
      points.map((p) => p[1]).reduce(math.max),
    ).inflate(8);
  }

  void pointerDown(PointerDownEvent e) {
    if (activePointer != null || (e.buttons & 1) == 0) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    activePointer = e.pointer;
    gestureStart = e.localPosition;
    lastPoint = e.localPosition;
    editedGesture = false;
    if (session.tool == EditorTool.select) {
      movingSelection = selectedBounds()?.contains(e.localPosition) ?? false;
      if (!movingSelection) {
        setState(() => session.selection.clear());
      }
    } else if (session.tool == EditorTool.eraser) {
      eraseAt(e.localPosition);
    } else {
      snapshot();
      normalizeStyles();
      activeStyle = {
        'width':
            session.width * (session.tool == EditorTool.highlighter ? 5 : 1),
        'color': session.color,
        'opacity': session.tool == EditorTool.highlighter ? 0.3 : 1.0,
      };
      setState(
        () => activeStroke = [
          [e.localPosition.dx, e.localPosition.dy, e.pressure],
        ],
      );
    }
  }

  void pointerMove(PointerMoveEvent e) {
    if (e.pointer != activePointer) {
      return;
    }
    if (session.tool == EditorTool.eraser) {
      eraseAt(e.localPosition);
    } else if (session.tool == EditorTool.select) {
      setState(() {
        if (movingSelection) {
          if (!editedGesture) {
            snapshot();
            editedGesture = true;
          }
          final delta = e.localPosition - lastPoint!;
          for (final i in session.selection) {
            for (final p in current!.strokes[i]) {
              p[0] += delta.dx;
              p[1] += delta.dy;
            }
          }
        } else {
          selectionBox = Rect.fromPoints(gestureStart!, e.localPosition);
        }
      });
    } else if (activeStroke != null) {
      setState(
        () => activeStroke!.add([
          e.localPosition.dx,
          e.localPosition.dy,
          e.pressure,
        ]),
      );
    }
    lastPoint = e.localPosition;
  }

  void eraseAt(Offset position) {
    final radius = session.width * 3;
    final hits = <int>[];
    for (var i = 0; i < current!.strokes.length; i++) {
      final stroke = current!.strokes[i];
      if (stroke.any(
        (p) => (Offset(p[0], p[1]) - position).distance <= radius,
      )) {
        hits.add(i);
        continue;
      }
      for (var j = 1; j < stroke.length; j++) {
        final a = Offset(stroke[j - 1][0], stroke[j - 1][1]);
        final b = Offset(stroke[j][0], stroke[j][1]);
        final line = b - a;
        final t = line.distanceSquared == 0
            ? 0.0
            : (((position - a).dx * line.dx + (position - a).dy * line.dy) /
                      line.distanceSquared)
                  .clamp(0.0, 1.0);
        if ((position - (a + line * t)).distance <= radius) {
          hits.add(i);
          break;
        }
      }
    }
    if (hits.isEmpty) {
      return;
    }
    setState(() {
      if (!editedGesture) {
        snapshot();
        editedGesture = true;
      }
      normalizeStyles();
      for (final i in hits.reversed) {
        current!.strokes.removeAt(i);
        current!.inkStyles.removeAt(i);
      }
      save();
    });
  }

  void deleteSelection() {
    if (session.selection.isEmpty) {
      return;
    }
    snapshot();
    setState(() {
      normalizeStyles();
      final indices = session.selection.toList()..sort();
      for (final i in indices.reversed) {
        current!.strokes.removeAt(i);
        current!.inkStyles.removeAt(i);
      }
      session.selection.clear();
      save();
    });
  }

  void finishStroke() {
    if (activePointer == null) {
      return;
    }
    setState(() {
      if (activeStroke != null) {
        current!.strokes.add(activeStroke!);
        current!.inkStyles.add(activeStyle!);
        save();
      } else if (session.tool == EditorTool.select &&
          !movingSelection &&
          selectionBox != null) {
        for (var i = 0; i < current!.strokes.length; i++) {
          if (current!.strokes[i].any(
            (p) => selectionBox!.contains(Offset(p[0], p[1])),
          )) {
            session.selection.add(i);
          }
        }
      } else if (editedGesture) {
        save();
      }
      activeStroke = null;
      activeStyle = null;
      activePointer = null;
      selectionBox = null;
      gestureStart = null;
    });
  }
}

class InkPainter extends CustomPainter {
  InkPainter(
    this.strokes, {
    this.color = const Color(0xff222222),
    this.styles = const [],
    this.selected = const {},
    this.selectionBox,
  });
  final List<Map<String, dynamic>> styles;
  final Set<int> selected;
  final Rect? selectionBox;
  final Color color;
  final List<List<List<double>>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (var index = 0; index < strokes.length; index++) {
      final stroke = strokes[index];
      final style = index < styles.length ? styles[index] : <String, dynamic>{};
      final strokeColor = style['color'] is int
          ? Color(style['color'] as int)
          : color;
      final opacity = (style['opacity'] as num?)?.toDouble() ?? 1.0;
      final width = (style['width'] as num?)?.toDouble() ?? 3.0;
      // Composite a marker stroke once so overlapping segments do not darken joins.
      if (opacity < 1) {
        canvas.saveLayer(
          null,
          Paint()..color = Colors.white.withValues(alpha: opacity),
        );
      }
      final paint = Paint()
        ..color = strokeColor
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < stroke.length; i++) {
        final p = stroke[i];
        paint.strokeWidth = width * (0.5 + 0.5 * p[2].clamp(0, 1));
        final a = Offset(p[0], p[1]);
        if (i == 0) {
          canvas.drawCircle(a, paint.strokeWidth / 2, paint);
        } else {
          final previous = stroke[math.max(0, i - 1)];
          canvas.drawLine(Offset(previous[0], previous[1]), a, paint);
        }
      }
      if (opacity < 1) {
        canvas.restore();
      }
      if (selected.contains(index) && stroke.isNotEmpty) {
        final rect = Rect.fromLTRB(
          stroke.map((p) => p[0]).reduce(math.min),
          stroke.map((p) => p[1]).reduce(math.min),
          stroke.map((p) => p[0]).reduce(math.max),
          stroke.map((p) => p[1]).reduce(math.max),
        ).inflate(5);
        canvas.drawRect(
          rect,
          Paint()
            ..color = color.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    if (selectionBox != null) {
      canvas.drawRect(
        selectionBox!,
        Paint()..color = color.withValues(alpha: 0.12),
      );
      canvas.drawRect(
        selectionBox!,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant InkPainter oldDelegate) => true;
}
