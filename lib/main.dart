import 'tablet_connection.dart';
import 'paper_layout.dart';
import 'paper_text_editor.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'desktop_ui.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    final darkTheme =
        defaultTargetPlatform == TargetPlatform.macOS ||
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
          child: FTooltipGroup(child: DesktopTheme(child: child!)),
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

class _WorkspaceState extends State<Workspace> with WindowListener {
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
  final tablets = TabletConnection();
  bool get hasStylus => tablets.showHand;
  double _pinchScale = 1;
  void _tabletsChanged() {
    if (!mounted) return;
    if (!hasStylus) {
      for (final editor in sessions.values) {
        if (editor.tool == EditorTool.hand) editor.tool = editor.previousTool;
      }
    }
    setState(() {});
  }

  bool _isPanning = false;
  bool isFullScreen = false;
  Offset? _panStartPos;
  Matrix4? _panStartMatrix;
  final List<String?> _navHistory = [];
  int _navIndex = -1;
  String status = 'Opening local library…';
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    tablets.addListener(_tabletsChanged);
    tablets.start();
    _checkFullScreen();
    initialize();
  }

  Future<void> _checkFullScreen() async {
    try {
      final fs = await windowManager.isFullScreen();
      if (mounted && isFullScreen != fs) {
        setState(() => isFullScreen = fs);
      }
    } catch (_) {}
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() => isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() => isFullScreen = false);
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
    if (tool == EditorTool.hand && !hasStylus) return;
    if (session.tool != EditorTool.hand) session.previousTool = session.tool;
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

  BoxConstraints? _lastConstraints;
  double get _currentPaperWidth => current?.landscape == true ? 980.0 : 760.0;
  double _bottomOverscroll = 0.0;
  bool _isCreatingPage = false;
  Timer? _overscrollResetTimer;
  static const double _createPageThreshold = 100.0;
  int activeStrokePageIndex = 0;

  void zoom(double factor) {
    setState(() {
      final oldScale = session.view.value.getMaxScaleOnAxis();
      final target = factor == 0 ? 1.0 : (oldScale * factor).clamp(0.05, 3.0);
      final matrix = Matrix4.identity()
        ..scaleByDouble(target, target, target, 1);
      if (_lastConstraints != null) {
        final paperWidth = _currentPaperWidth * target;
        if (paperWidth <= _lastConstraints!.maxWidth) {
          matrix.storage[12] = 0.0;
        } else {
          final centeredTx = (_lastConstraints!.maxWidth - paperWidth) / 2;
          matrix.storage[12] = centeredTx;
        }
        final hasCover = current?.kind == 'Notebook';
        final paperCount = current?.pages.length ?? 1;
        final totalSheets = (hasCover ? 1 : 0) + paperCount;
        final pageHeight = current?.landscape == true ? 760.0 : 980.0;
        final totalContentHeight =
            totalSheets * pageHeight + (totalSheets + 1) * 24.0;
        final totalHeight = totalContentHeight * target;
        final double minY = totalHeight <= _lastConstraints!.maxHeight
            ? 0.0
            : _lastConstraints!.maxHeight - totalHeight;
        final currentTy = session.view.value.storage[13];
        final scaledTy = factor == 0 ? 0.0 : (currentTy * (target / oldScale));
        matrix.storage[13] = scaledTy.clamp(minY, 0.0);
      }
      session.view.value = matrix;
    });
  }

  (double, double) _getCanvasScrollBounds(
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
    double scale,
  ) {
    final paperWidth = pageWidth * scale;
    final hasCover = current?.kind == 'Notebook';
    final paperCount = current?.pages.length ?? 1;
    final totalSheets = (hasCover ? 1 : 0) + paperCount;
    final loaderExtra = (_bottomOverscroll > 0 || _isCreatingPage) ? 72.0 : 0.0;
    final totalContentHeight =
        totalSheets * pageHeight + (totalSheets + 1) * 24.0 + loaderExtra;
    final totalHeight = totalContentHeight * scale;

    final double minX = paperWidth <= constraints.maxWidth
        ? 0.0
        : constraints.maxWidth - paperWidth;
    final double minY = totalHeight <= constraints.maxHeight
        ? 0.0
        : constraints.maxHeight - totalHeight;
    return (minX, minY);
  }

  void _panCanvas(Offset delta) {
    if (_lastConstraints == null || current == null) return;
    final matrix = session.view.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    final pageWidth = current!.landscape ? 980.0 : 760.0;
    final pageHeight = current!.landscape ? 760.0 : 980.0;
    final (minX, minY) = _getCanvasScrollBounds(
      _lastConstraints!,
      pageWidth,
      pageHeight,
      scale,
    );

    final currentTx = matrix.storage[12];
    final currentTy = matrix.storage[13];
    final newTx = (currentTx + delta.dx).clamp(minX, 0.0);
    final newTy = (currentTy + delta.dy).clamp(minY, 0.0);

    if (currentTx != newTx || currentTy != newTy) {
      matrix.storage[12] = newTx;
      matrix.storage[13] = newTy;
      session.view.value = matrix;
      setState(() {});
    }
  }

  void _handleCanvasScroll(
    PointerScrollEvent event,
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (_isCreatingPage) return;
    final matrix = session.view.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    final currentTx = matrix.storage[12];
    final currentTy = matrix.storage[13];

    final paperWidth = pageWidth * scale;
    final hasCover = current?.kind == 'Notebook';
    final paperCount = current?.pages.length ?? 1;
    final totalSheets = (hasCover ? 1 : 0) + paperCount;
    final loaderExtra = (_bottomOverscroll > 0 || _isCreatingPage) ? 72.0 : 0.0;
    final totalContentHeight =
        totalSheets * pageHeight + (totalSheets + 1) * 24.0 + loaderExtra;
    final totalHeight = totalContentHeight * scale;

    final double minX, maxX;
    if (paperWidth <= constraints.maxWidth) {
      // Don't allow side scrolls when paper fits in view; keep centered
      minX = maxX = 0.0;
    } else {
      // When zoomed out of viewport, allow scroll only to the edges of the paper, not past it
      maxX = 0.0;
      minX = constraints.maxWidth - paperWidth;
    }

    final double minY, maxY;
    if (totalHeight <= constraints.maxHeight) {
      minY = maxY = 0.0;
    } else {
      minY = constraints.maxHeight - totalHeight;
      maxY = 0.0;
    }

    final newTx = (currentTx - event.scrollDelta.dx).clamp(minX, maxX);
    double newTy;

    final bool atOrPastBottom =
        currentTy <= minY + 1.0 || _bottomOverscroll > 0;
    if (atOrPastBottom && event.scrollDelta.dy > 0) {
      // User is at or past the bottom and scrolling further down to add page!
      _bottomOverscroll += event.scrollDelta.dy;
      final overscrollShift = math.min(50.0, _bottomOverscroll * 0.25);
      newTy = minY - overscrollShift;

      _overscrollResetTimer?.cancel();
      _overscrollResetTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && _bottomOverscroll > 0 && !_isCreatingPage) {
          setState(() {
            _bottomOverscroll = 0.0;
            final m = session.view.value.clone();
            m.storage[13] = m.storage[13].clamp(minY, 0.0);
            session.view.value = m;
          });
        }
      });

      if (_bottomOverscroll >= _createPageThreshold) {
        _createNextPage(constraints, pageWidth, pageHeight);
        return;
      }
      setState(() {});
    } else if (event.scrollDelta.dy < 0 && _bottomOverscroll > 0) {
      if (_bottomOverscroll + event.scrollDelta.dy >= 0) {
        _bottomOverscroll += event.scrollDelta.dy;
        final overscrollShift = math.min(50.0, _bottomOverscroll * 0.25);
        newTy = minY - overscrollShift;
      } else {
        final remainingDelta = event.scrollDelta.dy + _bottomOverscroll;
        _bottomOverscroll = 0.0;
        newTy = (minY - remainingDelta).clamp(minY, maxY);
      }
      setState(() {});
    } else {
      _bottomOverscroll = 0.0;
      newTy = (currentTy - event.scrollDelta.dy).clamp(minY, maxY);
    }

    if (currentTx != newTx || currentTy != newTy) {
      matrix.storage[12] = newTx;
      matrix.storage[13] = newTy;
      session.view.value = matrix;
    }
  }

  void _createNextPage(
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (_isCreatingPage || current == null) return;
    _isCreatingPage = true;
    _overscrollResetTimer?.cancel();
    snapshot();
    setState(() {
      current!.pages.add(NotebookPage());
      save();
      _bottomOverscroll = 0.0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || current == null) return;
      setState(() {
        _isCreatingPage = false;
        final hasCover = current!.kind == 'Notebook';
        final totalPages = (hasCover ? 1 : 0) + current!.pages.length;
        status = 'Page $totalPages created';
      });
    });
  }

  void _snapHorizontalToCenter(BoxConstraints constraints, double pageWidth) {
    final matrix = session.view.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    final paperWidth = pageWidth * scale;

    if (paperWidth <= constraints.maxWidth) {
      // Don't allow side scrolls when paper fits in view; stay centered at 0.0
      if (matrix.storage[12].abs() > 0.01) {
        matrix.storage[12] = 0.0;
        session.view.value = matrix;
      }
    } else {
      // When zoomed out of viewport, clamp left and right strictly to the edges of the paper
      final minX = constraints.maxWidth - paperWidth;
      const maxX = 0.0;
      final clampedTx = matrix.storage[12].clamp(minX, maxX);
      if ((matrix.storage[12] - clampedTx).abs() > 0.01) {
        matrix.storage[12] = clampedTx;
        session.view.value = matrix;
      }
    }
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
    if (kind != null && kind != 'Notebook') {
      setState(() => status = '$kind creation is coming later');
      return;
    }
    finishStroke();
    final note = await showDialog<Notebook>(
      context: context,
      builder: (_) => CreateDocumentDialog(initialKind: kind),
    );
    if (note == null || !mounted) {
      return;
    }
    if (note.kind != 'Notebook') return;
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
      for (var i = 0; i < restored.pages.length; i++) {
        final controller = session.controllerForPage(i, restored.pages[i].text);
        final caret = controller.selection.baseOffset.clamp(
          0,
          restored.pages[i].text.length,
        );
        controller.value = TextEditingValue(
          text: restored.pages[i].text,
          selection: TextSelection.collapsed(offset: caret),
        );
      }
      activeStrokePageIndex = activeStrokePageIndex.clamp(
        0,
        restored.pages.length - 1,
      );
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
    windowManager.removeListener(this);
    tablets.removeListener(_tabletsChanged);
    tablets.dispose();
    _overscrollResetTimer?.cancel();
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
          isFullScreen: isFullScreen,
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
        '$status  ·  Offline · ${tablets.description}',
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
          const SingleActivator(LogicalKeyboardKey.keyH): () {
            if (hasStylus) chooseTool(EditorTool.hand);
          },
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _panCanvas(const Offset(0, 60)),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _panCanvas(const Offset(0, -60)),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _panCanvas(const Offset(60, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _panCanvas(const Offset(-60, 0)),
          const SingleActivator(LogicalKeyboardKey.pageUp): () =>
              _panCanvas(const Offset(0, 300)),
          const SingleActivator(LogicalKeyboardKey.pageDown): () =>
              _panCanvas(const Offset(0, -300)),
          const SingleActivator(LogicalKeyboardKey.home): () =>
              _panCanvas(const Offset(0, 100000)),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              _panCanvas(const Offset(0, -100000)),
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
                hasStylus: hasStylus,
                onAddPage: () {
                  if (_lastConstraints != null) {
                    _createNextPage(_lastConstraints!, pageWidth, pageHeight);
                  }
                },
                onExport: () => transfer('export'),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _lastConstraints = constraints;
                    final hasCover = note.kind == 'Notebook';
                    final paperCount = note.pages.length;
                    final totalSheets = (hasCover ? 1 : 0) + paperCount;
                    final scale = session.view.value.getMaxScaleOnAxis();
                    final paperWidth = pageWidth * scale;
                    final loaderExtra =
                        (_bottomOverscroll > 0 || _isCreatingPage) ? 72.0 : 0.0;
                    final totalContentHeight =
                        totalSheets * pageHeight +
                        (totalSheets + 1) * 24.0 +
                        loaderExtra;
                    final isFittingHorizontally =
                        paperWidth <= constraints.maxWidth;
                    final isFittingVertically =
                        (totalContentHeight * scale) <= constraints.maxHeight;
                    final childWidth = isFittingHorizontally
                        ? (constraints.maxWidth / scale)
                        : pageWidth;
                    final childHeight = isFittingVertically
                        ? math.max(
                            constraints.maxHeight / scale,
                            totalContentHeight,
                          )
                        : totalContentHeight;
                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerHover: (event) {
                        if (event.kind == PointerDeviceKind.stylus ||
                            event.kind == PointerDeviceKind.invertedStylus)
                          tablets.observePen();
                      },
                      onPointerDown: (event) {
                        if (event.kind == PointerDeviceKind.stylus ||
                            event.kind == PointerDeviceKind.invertedStylus) {
                          if (!hasStylus) {
                            tablets.observePen();
                          }
                        }
                        final isSpace = HardwareKeyboard.instance
                            .isLogicalKeyPressed(LogicalKeyboardKey.space);
                        final isMiddle = (event.buttons & 4) != 0;
                        if (isSpace || isMiddle || tool == EditorTool.hand) {
                          _isPanning = true;
                          _panStartPos = event.position;
                          _panStartMatrix = session.view.value.clone();
                        }
                      },
                      onPointerMove: (event) {
                        if (_isPanning &&
                            _panStartPos != null &&
                            _panStartMatrix != null) {
                          final delta = event.position - _panStartPos!;
                          final matrix = _panStartMatrix!.clone();
                          final scale = matrix.getMaxScaleOnAxis();
                          final (minX, minY) = _getCanvasScrollBounds(
                            constraints,
                            pageWidth,
                            pageHeight,
                            scale,
                          );
                          final startTx = _panStartMatrix!.storage[12];
                          final startTy = _panStartMatrix!.storage[13];
                          final newTx = (startTx + delta.dx).clamp(minX, 0.0);
                          final newTy = (startTy + delta.dy).clamp(minY, 0.0);
                          matrix.storage[12] = newTx;
                          matrix.storage[13] = newTy;
                          session.view.value = matrix;
                          setState(() {});
                        }
                      },
                      onPointerUp: (event) {
                        if (_isPanning) {
                          _isPanning = false;
                          _panStartPos = null;
                          _panStartMatrix = null;
                          _snapHorizontalToCenter(constraints, pageWidth);
                          setState(() {});
                        }
                      },
                      onPointerCancel: (event) {
                        if (_isPanning) {
                          _isPanning = false;
                          _panStartPos = null;
                          _panStartMatrix = null;
                          _snapHorizontalToCenter(constraints, pageWidth);
                          setState(() {});
                        }
                      },
                      onPointerPanZoomStart: (_) => _pinchScale = 1,
                      onPointerPanZoomUpdate: (event) {
                        if (event.scale != _pinchScale) {
                          zoom(event.scale / _pinchScale);
                        }
                        _pinchScale = event.scale;
                        _panCanvas(event.panDelta);
                      },
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          _handleCanvasScroll(
                            event,
                            constraints,
                            pageWidth,
                            pageHeight,
                          );
                        }
                      },
                      child: InteractiveViewer(
                        key: ValueKey('view-${note.id}'),
                        transformationController: session.view,
                        constrained: false,
                        minScale: 0.05,
                        maxScale: 3,
                        panAxis: isFittingHorizontally
                            ? PanAxis.vertical
                            : PanAxis.free,
                        boundaryMargin: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 50,
                        ),
                        panEnabled: false,
                        scaleEnabled: false,
                        onInteractionEnd: (_) {
                          _snapHorizontalToCenter(constraints, pageWidth);
                          setState(() {});
                        },
                        child: SizedBox(
                          width: childWidth,
                          height: childHeight,
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) {
                              if (event.kind == PointerDeviceKind.stylus ||
                                  event.kind ==
                                      PointerDeviceKind.invertedStylus) {
                                if (!hasStylus) {
                                  tablets.observePen();
                                }
                              }
                              if (tool != EditorTool.hand &&
                                  (event.buttons & 1) != 0) {
                                _isPanning = true;
                                _panStartPos = event.position;
                                _panStartMatrix = session.view.value.clone();
                              }
                            },
                            child: Align(
                              alignment: isFittingVertically
                                  ? Alignment.center
                                  : Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasCover) ...[
                                      // Page 1: Notebook Cover
                                      SizedBox(
                                        key: ValueKey('cover-page-${note.id}'),
                                        width: pageWidth,
                                        height: pageHeight,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.35,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: DocumentCover(note),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                    // Paper Canvases (Page 2, Page 3, etc.)
                                    for (
                                      var i = 0;
                                      i < note.pages.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 24),
                                      _buildPaperPage(
                                        note,
                                        i,
                                        pageWidth,
                                        pageHeight,
                                        foreground,
                                        tool,
                                      ),
                                    ],
                                    if (_bottomOverscroll > 0 ||
                                        _isCreatingPage)
                                      _PageCreationLoader(
                                        progress:
                                            (_bottomOverscroll /
                                                    _createPageThreshold)
                                                .clamp(0.0, 1.0),
                                        isCreating: _isCreatingPage,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      '${note.kind} / ${note.paper}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (_) {
                        final hasCover = note.kind == 'Notebook';
                        final totalPages =
                            (hasCover ? 1 : 0) + note.pages.length;
                        final scale = session.view.value.getMaxScaleOnAxis();
                        final scrollY = session.view.value.storage[13].abs();
                        final sheetHeightWithGap = (pageHeight + 24.0) * scale;
                        final pageNum =
                            (sheetHeightWithGap <= 0
                                    ? 1
                                    : ((scrollY + sheetHeightWithGap * 0.4) /
                                                  sheetHeightWithGap)
                                              .floor() +
                                          1)
                                .clamp(1, totalPages);
                        return Text(
                          'Page $pageNum of $totalPages · ${session.tool.name}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
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

  Widget _buildPaperPage(
    Notebook note,
    int pageIndex,
    double pageWidth,
    double pageHeight,
    Color foreground,
    EditorTool tool,
  ) {
    final page = note.pages[pageIndex];
    final pageController = session.controllerForPage(pageIndex, page.text);
    final pageFocus = session.focusNodeForPage(pageIndex);

    return SizedBox(
      key: pageIndex == 0
          ? ValueKey('paper-page-${note.id}')
          : ValueKey('paper-page-${note.id}-$pageIndex'),
      width: pageWidth,
      height: pageHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRect(
          child: CustomPaint(
            painter: PaperPainter(
              note.paper,
              note.tone,
              guides: tool == EditorTool.text && note.paper == 'Blank',
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: tool != EditorTool.text,
                    child: PaperTextEditor(
                      key: ValueKey('paper-text-${note.id}-$pageIndex'),
                      controller: pageController,
                      focusNode: pageFocus,
                      layout: PaperLayout(note.paper),
                      fontSize: note.fontSize,
                      bold: note.boldText,
                      foreground: foreground,
                      pageWidth: pageWidth,
                      pageHeight: pageHeight,
                      onChanged: (value) => _paperChanged(
                        pageIndex,
                        value,
                        pageWidth,
                        pageHeight,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring:
                        tool == EditorTool.text || tool == EditorTool.hand,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.precise,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) =>
                            pointerDown(e, pageIndex: pageIndex),
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
                            [
                              ...page.strokes,
                              if (activeStrokePageIndex == pageIndex &&
                                  activeStroke != null)
                                activeStroke!,
                            ],
                            color: foreground,
                            styles: [
                              ...page.inkStyles,
                              if (activeStrokePageIndex == pageIndex &&
                                  activeStyle != null)
                                activeStyle!,
                            ],
                            selected: activeStrokePageIndex == pageIndex
                                ? session.selection
                                : const {},
                            selectionBox: activeStrokePageIndex == pageIndex
                                ? selectionBox
                                : null,
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
    );
  }

  void _paperChanged(int pageIndex, String value, double width, double height) {
    snapshot();
    final note = current!;
    final controller = session.controllerForPage(pageIndex, value);
    var caretPage = pageIndex;
    var caretOffset = controller.selection.baseOffset.clamp(0, value.length);
    setState(() {
      note.pages[pageIndex].text = value;
      // Preserve in-progress IME composition. Reflow when it commits.
      if (!controller.value.composing.isValid ||
          controller.value.composing.isCollapsed) {
        final layout = PaperLayout(note.paper);
        final style = DefaultTextStyle.of(context).style.merge(
          layout.textStyle(note.fontSize, note.boldText, Colors.black),
        );
        for (var i = pageIndex; i < note.pages.length; i++) {
          final content = note.pages[i].text;
          final split = layout.splitOffset(
            content,
            width,
            height,
            style,
            MediaQuery.textScalerOf(context),
          );
          if (split <= 0 || split >= content.length) continue;
          final overflow = content.substring(split);
          note.pages[i].text = content.substring(0, split);
          if (i + 1 >= note.pages.length) note.pages.add(NotebookPage());
          note.pages[i + 1].text = overflow + note.pages[i + 1].text;
          if (caretPage == i && caretOffset >= split) {
            caretPage++;
            caretOffset -= split;
          }
          final first = session.controllerForPage(i, note.pages[i].text);
          first.value = TextEditingValue(
            text: note.pages[i].text,
            selection: TextSelection.collapsed(
              offset: first.selection.baseOffset.clamp(
                0,
                note.pages[i].text.length,
              ),
            ),
          );
          final next = session.controllerForPage(i + 1, note.pages[i + 1].text);
          next.value = TextEditingValue(
            text: note.pages[i + 1].text,
            selection: TextSelection.collapsed(
              offset: caretPage == i + 1
                  ? caretOffset.clamp(0, note.pages[i + 1].text.length)
                  : 0,
            ),
          );
        }
      }
      save();
    });
    if (caretPage != pageIndex) {
      final target = caretPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || current?.id != note.id) return;
        session.focusNodeForPage(target).requestFocus();
        _panCanvas(
          Offset(
            0,
            -(height + 24) *
                (target - pageIndex) *
                session.view.value.getMaxScaleOnAxis(),
          ),
        );
      });
    }
  }

  NotebookPage get _activePage {
    if (current != null && activeStrokePageIndex < current!.pages.length) {
      return current!.pages[activeStrokePageIndex];
    }
    return current?.pages.first ?? NotebookPage();
  }

  void normalizeStyles() {
    if (current == null) return;
    for (final page in current!.pages) {
      while (page.inkStyles.length < page.strokes.length) {
        page.inkStyles.add({});
      }
    }
  }

  Rect? selectedBounds() {
    final page = _activePage;
    final points = session.selection
        .where((i) => i < page.strokes.length)
        .expand((i) => page.strokes[i])
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

  void pointerDown(PointerDownEvent e, {int pageIndex = 0}) {
    if (e.kind == PointerDeviceKind.stylus ||
        e.kind == PointerDeviceKind.invertedStylus) {
      if (!hasStylus) {
        tablets.observePen();
      }
    }
    // If Space is held or middle button is pressed, don't draw ink (user is panning)
    final isSpacePressed = HardwareKeyboard.instance.isLogicalKeyPressed(
      LogicalKeyboardKey.space,
    );
    final isMiddleButton = (e.buttons & 4) != 0;
    if (isSpacePressed || isMiddleButton) {
      return;
    }
    if (activePointer != null || (e.buttons & 1) == 0) {
      return;
    }
    activeStrokePageIndex = pageIndex;
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
      eraseAt(e.localPosition, pageIndex: pageIndex);
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
      eraseAt(e.localPosition, pageIndex: activeStrokePageIndex);
    } else if (session.tool == EditorTool.select) {
      setState(() {
        if (movingSelection) {
          if (!editedGesture) {
            snapshot();
            editedGesture = true;
          }
          final delta = e.localPosition - lastPoint!;
          final page = _activePage;
          for (final i in session.selection) {
            if (i < page.strokes.length) {
              for (final p in page.strokes[i]) {
                p[0] += delta.dx;
                p[1] += delta.dy;
              }
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

  void eraseAt(Offset position, {int? pageIndex}) {
    final targetIndex = pageIndex ?? activeStrokePageIndex;
    if (current == null || targetIndex >= current!.pages.length) return;
    final page = current!.pages[targetIndex];
    final radius = session.width * 3;
    final hits = <int>[];
    for (var i = 0; i < page.strokes.length; i++) {
      final stroke = page.strokes[i];
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
        page.strokes.removeAt(i);
        page.inkStyles.removeAt(i);
      }
      save();
    });
  }

  void deleteSelection() {
    if (session.selection.isEmpty) {
      return;
    }
    final page = _activePage;
    snapshot();
    setState(() {
      normalizeStyles();
      final indices = session.selection.toList()..sort();
      for (final i in indices.reversed) {
        if (i < page.strokes.length) {
          page.strokes.removeAt(i);
          page.inkStyles.removeAt(i);
        }
      }
      session.selection.clear();
      save();
    });
  }

  void finishStroke() {
    if (activePointer == null) {
      return;
    }
    final page = _activePage;
    setState(() {
      if (activeStroke != null) {
        page.strokes.add(activeStroke!);
        page.inkStyles.add(activeStyle!);
        save();
      } else if (session.tool == EditorTool.select &&
          !movingSelection &&
          selectionBox != null) {
        for (var i = 0; i < page.strokes.length; i++) {
          if (page.strokes[i].any(
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

class _PageCreationLoader extends StatelessWidget {
  const _PageCreationLoader({required this.progress, required this.isCreating});

  final double progress;
  final bool isCreating;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toInt().clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xff1e1e1e),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCreating || progress >= 1.0
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: isCreating
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : CircularProgressIndicator(
                        value: progress.clamp(0.04, 1.0),
                        strokeWidth: 2.2,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.white : Colors.white70,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Text(
                isCreating
                    ? 'Creating new page…'
                    : progress >= 1.0
                    ? 'Release or scroll to create page'
                    : 'Scroll to add page $percent%',
                style: TextStyle(
                  color: progress >= 1.0 ? Colors.white : Colors.grey[300],
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    this.isFullScreen = false,
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
  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTabsWidth = (constraints.maxWidth - 320).clamp(
          60.0,
          double.infinity,
        );
        return Material(
          color: const Color(0xff121212),
          child: Container(
            height: 34,
            padding: const EdgeInsets.only(top: 1, bottom: 3),
            child: Row(
              children: [
                if (defaultTargetPlatform == TargetPlatform.macOS &&
                    !isFullScreen)
                  const DragToMoveArea(child: SizedBox(width: 78, height: 34)),
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
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxTabsWidth),
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
                    child: SizedBox(height: 34, width: double.infinity),
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
      },
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
