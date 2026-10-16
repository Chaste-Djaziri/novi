import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'desktop_ui.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'notebook.dart';
import 'library_ui.dart';
import 'workspace_tools.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(960, 640),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // In tests or headless environments where platform channels are not hooked up.
    }
  }
  runApp(const NoviApp());
}

class NoviApp extends StatelessWidget {
  const NoviApp({super.key});
  @override
  Widget build(BuildContext context) {
    final darkTheme = defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux
        ? FTheme.neutral.dark.desktop
        : FTheme.neutral.dark.touch;

    return MaterialApp(
      title: 'Novi',
      debugShowCheckedModeBanner: false,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: defaultTargetPlatform == TargetPlatform.macOS
            ? '.AppleSystemUIFont'
            : null,
        scaffoldBackgroundColor: const Color(0xff090909),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Color(0xffbbbbbb),
          surface: Color(0xff1c1c1c),
          onSurface: Color(0xffeeeeee),
        ),
        dividerColor: const Color(0xff333333),
      ),
      builder: (context, child) => FTheme(
        data: darkTheme,
        child: FToaster(
          child: FTooltipGroup(
            child: DesktopTheme(child: child!),
          ),
        ),
      ),
      home: const Workspace(),
    );
  }
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
  final workspaceFocus = FocusNode();
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
  bool showSidebar = true;
  final List<String?> _navHistory = [];
  int _navIndex = -1;
  String status = 'Opening local library…';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  void _pushNav(String? id) {
    if (_navIndex >= 0 &&
        _navIndex < _navHistory.length &&
        _navHistory[_navIndex] == id) {
      return;
    }
    if (_navIndex + 1 < _navHistory.length) {
      _navHistory.removeRange(_navIndex + 1, _navHistory.length);
    }
    _navHistory.add(id);
    _navIndex = _navHistory.length - 1;
  }

  bool get canGoBack => _navIndex > 0 || !inLibrary;
  bool get canGoForward =>
      (_navIndex >= 0 && _navIndex < _navHistory.length - 1) ||
      (inLibrary && current != null);

  void navigateBack() {
    finishStroke();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_navIndex > 0) {
      _navIndex--;
      final target = _navHistory[_navIndex];
      _applyNav(target);
    } else {
      _pushNav(null);
      setState(() => inLibrary = true);
    }
  }

  void navigateForward() {
    finishStroke();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_navIndex >= 0 && _navIndex < _navHistory.length - 1) {
      _navIndex++;
      final target = _navHistory[_navIndex];
      _applyNav(target);
    } else if (inLibrary && current != null) {
      setState(() => inLibrary = false);
      _pushNav(current!.id);
    }
  }

  void _applyNav(String? id) {
    if (id == null) {
      setState(() => inLibrary = true);
    } else {
      final note = notes.firstWhere(
        (n) => n.id == id,
        orElse: () => notes.first,
      );
      select(note, pushHistory: false);
    }
  }

  Future<void> initialize() async {
    try {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final opened = LibraryStore('${directory.path}/novi.sqlite');
      if (!mounted) {
        opened.close();
      }
      try {
        notes = opened.load();
      } catch (_) {
        opened.close();
        rethrow;
      }
      store = opened;
      final savedOpenIds = opened.loadOpenTabs();
      final validOpenIds = savedOpenIds
          .where((id) => notes.any((n) => n.id == id))
          .toList();
      openIds.clear();
      openIds.addAll(validOpenIds);
      if (openIds.isNotEmpty) {
        current = notes.firstWhere((n) => n.id == openIds.last);
        sessions.putIfAbsent(current!.id, () => EditorSession(current!));
      } else if (notes.isNotEmpty) {
        current = notes.first;
        sessions.putIfAbsent(current!.id, () => EditorSession(current!));
      }
      _pushNav(null);
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

  void select(Notebook note, {bool pushHistory = true}) {
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
    store?.saveOpenTabs(openIds);
    if (pushHistory) {
      _pushNav(note.id);
    }
    if (session.tool == EditorTool.text) {
      session.textFocus.requestFocus();
    } else {
      workspaceFocus.requestFocus();
    }
  }

  void chooseTool(EditorTool tool) {
    finishStroke();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      session.tool = tool;
      session.selection.clear();
      selectionBox = null;
    });
    if (tool == EditorTool.text) {
      session.textFocus.requestFocus();
    } else {
      workspaceFocus.requestFocus();
    }
  }

  void closeTab(String id) {
    finishStroke();
    final index = openIds.indexOf(id);
    setState(() {
      openIds.remove(id);
    });
    store?.saveOpenTabs(openIds);
    if (current?.id == id && !inLibrary) {
      if (openIds.isEmpty) {
        _pushNav(null);
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

  Future<void> create([String? kind]) async {
    finishStroke();
    final note = await showDialog<Notebook>(
      context: context,
      builder: (_) => CreateDocumentDialog(initialKind: kind),
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
    finishStroke();
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
    finishStroke();
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
    workspaceFocus.dispose();
    store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff121212),
    body: Column(
      children: [
        DesktopWindowHeader(
          canGoBack: canGoBack,
          canGoForward: canGoForward,
          onBack: navigateBack,
          onForward: navigateForward,
          onToggleSidebar: () => setState(() => showSidebar = !showSidebar),
          notes: notes,
          openIds: openIds,
          currentId: inLibrary ? null : current?.id,
          showTabs: openIds.isNotEmpty,
          onSelectTab: (tab) => select(tab),
          onCloseTab: closeTab,
          onCreate: create,
          onOpenDocument: () {
            finishStroke();
            setState(() => inLibrary = true);
            _pushNav(null);
          },
          onTransfer: transfer,
          onStatus: (msg) => setState(() => status = msg),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: inLibrary || current == null
              ? LibraryView(
                  notes: notes,
                  enabled: store != null,
                  onCreate: create,
                  onOpen: select,
                  onFavorite: toggleFavorite,
                  onTransfer: transfer,
                  showSidebar: showSidebar,
                  onStatus: (msg) => setState(() => status = msg),
                )
              : editor(),
        ),
      ],
    ),
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
        if (tool != EditorTool.text) ...{
          const SingleActivator(LogicalKeyboardKey.keyP): () =>
              chooseTool(EditorTool.pen),
          const SingleActivator(LogicalKeyboardKey.keyB): () =>
              chooseTool(EditorTool.highlighter),
          const SingleActivator(LogicalKeyboardKey.keyE): () =>
              chooseTool(EditorTool.eraser),
          const SingleActivator(LogicalKeyboardKey.keyV): () =>
              chooseTool(EditorTool.select),
          const SingleActivator(LogicalKeyboardKey.keyT): () =>
              chooseTool(EditorTool.text),
          const SingleActivator(LogicalKeyboardKey.keyH): () =>
              chooseTool(EditorTool.hand),
        },
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
        focusNode: workspaceFocus,
        autofocus: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xff161616),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
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
                                      child: DesktopTextField(
                                        key: ValueKey('text-${note.id}'),
                                        controller: text,
                                        focusNode: session.textFocus,
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
                                        borderless: true,
                                        placeholder: 'Write your thoughts…',
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
    workspaceFocus.requestFocus();
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

class DesktopWindowHeader extends StatelessWidget {
  const DesktopWindowHeader({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onToggleSidebar,
    required this.notes,
    required this.openIds,
    required this.currentId,
    required this.showTabs,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onCreate,
    required this.onOpenDocument,
    required this.onTransfer,
    this.onStatus,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onToggleSidebar;
  final List<Notebook> notes;
  final List<String> openIds;
  final String? currentId;
  final bool showTabs;
  final ValueChanged<Notebook> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final void Function([String? kind]) onCreate;
  final VoidCallback onOpenDocument;
  final ValueChanged<String> onTransfer;
  final ValueChanged<String>? onStatus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff121212),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(top: 1, bottom: 3),
        child: Row(
          children: [
            if (defaultTargetPlatform == TargetPlatform.macOS)
              const DragToMoveArea(
                child: SizedBox(width: 78, height: 34),
              ),
            if (currentId != null) ...[
              DesktopHeaderButton(
                key: const Key('home-button'),
                tooltip: 'Home',
                icon: CupertinoIcons.house,
                onPressed: onOpenDocument,
              ),
              const SizedBox(width: 2),
            ],
            DesktopHeaderButton(
              tooltip: 'Back to documents',
              icon: CupertinoIcons.chevron_left,
              onPressed: canGoBack ? onBack : null,
            ),
            const SizedBox(width: 2),
            DesktopHeaderButton(
              tooltip: 'Forward',
              icon: CupertinoIcons.chevron_right,
              onPressed: canGoForward ? onForward : null,
            ),
            const SizedBox(width: 2),
            DesktopHeaderButton(
              tooltip: 'Toggle sidebar',
              icon: CupertinoIcons.sidebar_left,
              onPressed: onToggleSidebar,
            ),
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            if (showTabs)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final id in openIds) ...[
                        _buildTab(context, id),
                        const SizedBox(width: 4),
                      ],
                      _buildCreateButton(),
                    ],
                  ),
                ),
              )
            else
              _buildCreateButton(),
            const Expanded(
              child: DragToMoveArea(
                child: SizedBox(
                  height: 34,
                  width: double.infinity,
                ),
              ),
            ),
            DesktopIconButton(
              tooltip: 'Open document',
              onPressed: onOpenDocument,
              icon: const Icon(CupertinoIcons.folder_open, size: 18),
            ),
            DesktopPopupMenuButton<String>(
              tooltip: 'Import, export and backup',
              onSelected: onTransfer,
              itemBuilder: (_) => const [
                DesktopMenuItem(
                  value: 'export',
                  child: Text('Export notebook'),
                ),
                DesktopMenuItem(
                  value: 'backup',
                  child: Text('Back up library'),
                ),
                DesktopMenuItem(
                  value: 'import',
                  child: Text('Import .novi file'),
                ),
                DesktopMenuItem(
                  value: 'restore',
                  child: Text('Restore backup'),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, String id) {
    final tab = notes.firstWhere(
      (n) => n.id == id,
      orElse: () => Notebook(id: id, title: 'Document'),
    );
    final active = tab.id == currentId;
    return Material(
      color: active ? const Color(0xff2b2b2b) : const Color(0xff1c1c1c),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => onSelectTab(tab),
        child: Container(
          height: 26,
          constraints: const BoxConstraints(minWidth: 90, maxWidth: 175),
          padding: const EdgeInsets.only(left: 8, right: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.05),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                kindIcon(tab.kind),
                size: 13,
                color: active ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? Colors.white : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              DesktopIconButton(
                tooltip: 'Close tab ${tab.title}',
                onPressed: () => onCloseTab(id),
                icon: Icon(
                  CupertinoIcons.xmark,
                  size: 11,
                  color: active ? Colors.white70 : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Builder(
      builder: (btnContext) {
        return Tooltip(
          message: 'New document',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                final box = btnContext.findRenderObject() as RenderBox?;
                if (box != null) {
                  final offset = box.localToGlobal(Offset.zero);
                  final size = box.size;
                  showNewDocumentMenu(
                    btnContext,
                    targetRect: offset & size,
                    onCreateKind: (kind) => onCreate(kind),
                    onImport: () => onTransfer('import'),
                    onFeatureNotice: (notice) => onStatus?.call(notice),
                  );
                } else {
                  onCreate();
                }
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.plus,
                  size: 13,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DesktopHeaderButton extends StatelessWidget {
  const DesktopHeaderButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 14,
              color: enabled
                  ? Colors.white70
                  : Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ),
      ),
    );
  }
}
