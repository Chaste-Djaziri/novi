import 'tablet_connection.dart';
import 'paper_layout.dart';
import 'ink_material.dart';
import 'paper_text_editor.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'desktop_ui.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:forui/forui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'notebook.dart';
import 'library_ui.dart';
import 'workspace_tools.dart';
import 'features/editor/tools/shape/shape_recognition.dart';
import 'pages_sidebar.dart';

import 'package:flutter/services.dart';

enum SelectionTransformMode { none, move, resize, rotate, lasso }

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

class _WorkspaceState extends State<Workspace>
    with WindowListener, TickerProviderStateMixin {
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
  List<Offset>? selectionPath;
  bool movingSelection = false;
  SelectionTransformMode selectionTransformMode = SelectionTransformMode.none;
  Map<int, List<List<double>>>? _selectionOriginalStrokes;
  Offset? _selectionCenter;
  double _selectionStartDistance = 0;
  double _selectionStartAngle = 0;
  double _selectionStartTextScale = 1.0;
  double _selectionStartTextRotation = 0.0;
  bool editedGesture = false;
  Offset? _inkHover;
  Offset? _inkGlobalPointer;
  int? _inkHoverPage;
  double _inkPressure = 1;
  Timer? _inkHoldTimer;
  bool _inkHeld = false;
  Map<String, dynamic>? activeStyle;

  List<List<double>> get _displayActiveStroke {
    final stroke = activeStroke!;
    final style = activeStyle!;
    if (stroke.length < 2) return stroke;
    if (style['kind'] == 'tape' && style['straight'] == true) {
      return [stroke.first, stroke.last];
    }
    if (_inkHeld &&
        ((style['kind'] == 'pen' && style['holdForLine'] == true) ||
            (style['kind'] == 'pencil' && style['drawAndHold'] == true) ||
            style['kind'] == 'shape')) {
      return ShapeRecognition.recognize(stroke).stroke;
    }
    return stroke;
  }

  bool get _showInkFootprint =>
      !_isPanning &&
      !HardwareKeyboard.instance.isLogicalKeyPressed(
        LogicalKeyboardKey.space,
      ) &&
      (session.tool == EditorTool.pen ||
          session.tool == EditorTool.highlighter ||
          session.tool == EditorTool.eraser);

  void _trackInkPointer(PointerEvent event, int pageIndex) {
    setState(() {
      _inkGlobalPointer = event.position;
      _inkHover = event.kind == PointerDeviceKind.touch
          ? null
          : event.localPosition;
      _inkHoverPage = pageIndex;
      _inkPressure =
          event is PointerHoverEvent ||
              event is PointerEnterEvent ||
              event.kind == PointerDeviceKind.mouse
          ? 1
          : event.pressure;
    });
  }

  void _scheduleInkHold() {
    _inkHoldTimer?.cancel();
    _inkHeld = false;
    if (activeStyle == null ||
        activeStroke == null ||
        activeStroke!.length < 2) {
      return;
    }
    if ((activeStyle!['kind'] == 'pen' &&
            activeStyle!['holdForLine'] == true) ||
        (activeStyle!['kind'] == 'pencil' &&
            activeStyle!['drawAndHold'] == true) ||
        (activeStyle!['kind'] == 'shape' &&
            activeStyle!['requireHold'] == true)) {
      _inkHoldTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted || activeStroke == null) return;
        setState(() => _inkHeld = true);
      });
    }
  }

  List<List<double>>? activeStroke;
  int? activePointer;
  bool _shapePlacementMoved = false;
  bool get drawing => session.tool != EditorTool.text;
  bool inLibrary = true;
  bool showSidebar = true;
  bool showPagesSidebar = false;
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
    _overscrollBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    tablets.addListener(_tabletsChanged);
    tablets.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkFullScreen();
    });
    initialize();
  }

  Future<void> _checkFullScreen() async {
    try {
      await windowManager.ensureInitialized();
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
      _inkHover = null;
      _inkHoverPage = null;
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
      selectionPath = null;
      session.textBoxSelected = false;
    });
    store?.saveOpenTabs(openIds);
    if (pushHistory) {
      _pushNav(note.id);
    }
    if (session.tool == EditorTool.text) {
      session
          .focusNodeForPage(
            session.activeTextPage.clamp(0, current!.pages.length - 1),
          )
          .requestFocus();
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
      if (tool != EditorTool.shapes && tool != EditorTool.select) {
        session.selection.clear();
        session.textBoxSelected = false;
      }
      selectionBox = null;
      selectionPath = null;
    });
    if (tool == EditorTool.text) {
      session
          .focusNodeForPage(
            session.activeTextPage.clamp(0, current!.pages.length - 1),
          )
          .requestFocus();
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
  bool _isTrackpadPanning = false;
  Timer? _overscrollResetTimer;
  static const double _createPageThreshold = 180.0;
  AnimationController? _overscrollBounceController;
  Animation<double>? _overscrollBounceAnimation;
  AnimationController? _pageCreationScrollController;
  int activeStrokePageIndex = 0;
  Ticker? _flingTicker;
  VelocityTracker _panVelocityTracker = VelocityTracker.withKind(
    PointerDeviceKind.trackpad,
  );
  double _accumulatedPanY = 0.0;

  double _calculateOverscrollShift(double overscroll) {
    if (overscroll <= 0) return 0.0;
    return 110.0 * (1.0 - math.exp(-overscroll / 150.0));
  }

  void _stopPageCreationAnimation() {
    if (_pageCreationScrollController != null) {
      _pageCreationScrollController?.stop();
      _pageCreationScrollController?.dispose();
      _pageCreationScrollController = null;
      _isCreatingPage = false;
    }
  }

  void _stopFling() {
    _flingTicker?.stop();
    _flingTicker?.dispose();
    _flingTicker = null;
  }

  void _applyFlingY(double targetTy) {
    final m = session.view.value.clone();
    m.storage[13] = targetTy;
    session.view.value = m;
  }

  void _startFling(
    double vy,
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    _stopFling();
    final matrix = session.view.value;
    final scale = matrix.getMaxScaleOnAxis();
    final currentTy = matrix.storage[13];
    final (_, minY) = _getCanvasScrollBounds(
      constraints,
      pageWidth,
      pageHeight,
      scale,
    );

    if (minY >= 0.0 || currentTy > 0.0 || currentTy < minY) return;

    final simulation = FrictionSimulation(0.135, currentTy, vy);

    _flingTicker = createTicker((elapsed) {
      if (!mounted || current == null) {
        _stopFling();
        return;
      }
      final t = elapsed.inMicroseconds / 1000000.0;
      final targetTy = simulation.x(t);
      final v = simulation.dx(t);

      if (simulation.isDone(t) || v.abs() < 12.0) {
        _stopFling();
        _applyFlingY(targetTy.clamp(minY, 0.0));
      } else if (targetTy >= 0.0) {
        _stopFling();
        _applyFlingY(0.0);
      } else if (targetTy <= minY) {
        _stopFling();
        _applyFlingY(minY);
      } else {
        _applyFlingY(targetTy);
      }
    });
    _flingTicker!.start();
  }

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
    final totalContentHeight =
        totalSheets * pageHeight + (totalSheets + 1) * 24.0;
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

  void _startBounceBack(
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (_bottomOverscroll <= 0 || _isCreatingPage) return;
    _overscrollResetTimer?.cancel();
    _overscrollBounceController?.stop();

    final startVal = _bottomOverscroll;
    final curve = CurvedAnimation(
      parent: _overscrollBounceController!,
      curve: Curves.easeOutCubic,
    );
    _overscrollBounceAnimation =
        Tween<double>(begin: startVal, end: 0.0).animate(curve)
          ..addListener(() {
            if (!mounted || current == null) return;
            setState(() {
              _bottomOverscroll = _overscrollBounceAnimation!.value;
              final matrix = session.view.value.clone();
              final scale = matrix.getMaxScaleOnAxis();
              final hasCover = current?.kind == 'Notebook';
              final paperCount = current?.pages.length ?? 1;
              final totalSheets = (hasCover ? 1 : 0) + paperCount;
              final totalContentHeight =
                  totalSheets * pageHeight + (totalSheets + 1) * 24.0;
              final totalHeight = totalContentHeight * scale;
              final minY = totalHeight <= constraints.maxHeight
                  ? 0.0
                  : constraints.maxHeight - totalHeight;
              final overscrollShift = _calculateOverscrollShift(
                _bottomOverscroll,
              );
              matrix.storage[13] = minY - overscrollShift;
              session.view.value = matrix;
            });
          })
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed ||
                s == AnimationStatus.dismissed) {
              if (mounted && _bottomOverscroll != 0.0) {
                setState(() {
                  _bottomOverscroll = 0.0;
                });
              }
            }
          });
    _overscrollBounceController!.forward(from: 0.0);
  }

  void _handleScrollDelta(
    Offset scrollDelta,
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (_pageCreationScrollController?.isAnimating == true) {
      _stopPageCreationAnimation();
    }
    final matrix = session.view.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    final currentTx = matrix.storage[12];
    final currentTy = matrix.storage[13];

    final paperWidth = pageWidth * scale;
    final hasCover = current?.kind == 'Notebook';
    final paperCount = current?.pages.length ?? 1;
    final totalSheets = (hasCover ? 1 : 0) + paperCount;
    final totalContentHeight =
        totalSheets * pageHeight + (totalSheets + 1) * 24.0;
    final totalHeight = totalContentHeight * scale;

    final double minX, maxX;
    if (paperWidth <= constraints.maxWidth) {
      minX = maxX = 0.0;
    } else {
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

    final newTx = (currentTx - scrollDelta.dx).clamp(minX, maxX);
    double newTy;

    final bool atOrPastBottom =
        currentTy <= minY + 1.0 || _bottomOverscroll > 0;
    if (atOrPastBottom && scrollDelta.dy > 0) {
      // User is at the bottom and scrolling further down to add page
      _overscrollBounceController?.stop();
      _overscrollResetTimer?.cancel();
      _bottomOverscroll += scrollDelta.dy;
      final overscrollShift = _calculateOverscrollShift(_bottomOverscroll);
      newTy = minY - overscrollShift;

      if (!_isTrackpadPanning) {
        _overscrollResetTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted && _bottomOverscroll > 0 && !_isCreatingPage) {
            _startBounceBack(constraints, pageWidth, pageHeight);
          }
        });
      }

      if (_bottomOverscroll >= _createPageThreshold && !_isCreatingPage) {
        _createNextPage(constraints, pageWidth, pageHeight);
        return;
      }
      matrix.storage[12] = newTx;
      matrix.storage[13] = newTy;
      session.view.value = matrix;
      setState(() {});
    } else if (scrollDelta.dy < 0 && _bottomOverscroll > 0) {
      _overscrollBounceController?.stop();
      _overscrollResetTimer?.cancel();
      if (_bottomOverscroll + scrollDelta.dy >= 0) {
        _bottomOverscroll += scrollDelta.dy;
        final overscrollShift = _calculateOverscrollShift(_bottomOverscroll);
        newTy = minY - overscrollShift;
      } else {
        final remainingDelta = scrollDelta.dy + _bottomOverscroll;
        _bottomOverscroll = 0.0;
        newTy = (minY - remainingDelta).clamp(minY, maxY);
      }
      matrix.storage[12] = newTx;
      matrix.storage[13] = newTy;
      session.view.value = matrix;
      setState(() {});
    } else {
      if (_bottomOverscroll > 0) {
        _bottomOverscroll = 0.0;
        setState(() {});
      }
      newTy = (currentTy - scrollDelta.dy).clamp(minY, maxY);
      if (currentTx != newTx || currentTy != newTy) {
        matrix.storage[12] = newTx;
        matrix.storage[13] = newTy;
        session.view.value = matrix;
      }
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
    _overscrollBounceController?.stop();
    _stopFling();
    _stopPageCreationAnimation();
    snapshot();

    final hasCover = current!.kind == 'Notebook';
    final paperCountBefore = current!.pages.length;
    final newSheetIndex = (hasCover ? 1 : 0) + paperCountBefore;
    final totalPagesAfter = (hasCover ? 1 : 0) + paperCountBefore + 1;

    setState(() {
      current!.pages.add(NotebookPage());
      save();
      _bottomOverscroll = 0.0;
      status = 'Page $totalPagesAfter created';
    });

    final matrix = session.view.value.clone();
    final scale = matrix.getMaxScaleOnAxis();
    final totalSheets = totalPagesAfter;
    final totalContentHeight =
        totalSheets * pageHeight + (totalSheets + 1) * 24.0;
    final totalHeight = totalContentHeight * scale;
    final newMinY = totalHeight <= constraints.maxHeight
        ? 0.0
        : constraints.maxHeight - totalHeight;

    final sheetTop = 24.0 + newSheetIndex * (pageHeight + 24.0);
    final targetTy = (-sheetTop * scale + 24.0).clamp(newMinY, 0.0);
    final startTy = matrix.storage[13];

    if ((targetTy - startTy).abs() > 2.0) {
      _pageCreationScrollController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      );
      final curve = CurvedAnimation(
        parent: _pageCreationScrollController!,
        curve: Curves.easeOutCubic,
      );
      final anim = Tween<double>(begin: startTy, end: targetTy).animate(curve);
      anim
        ..addListener(() {
          if (!mounted || current == null) return;
          final m = session.view.value.clone();
          m.storage[13] = anim.value;
          session.view.value = m;
        })
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed ||
              s == AnimationStatus.dismissed) {
            if (mounted) {
              setState(() {
                _isCreatingPage = false;
              });
            }
          }
        });
      _pageCreationScrollController!.forward();
    } else {
      _isCreatingPage = false;
    }
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

  void _scrollToPage(
    int sheetIndex,
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (current == null) return;
    final scale = session.view.value.getMaxScaleOnAxis();
    final sheetTop = 24.0 + sheetIndex * (pageHeight + 24.0);

    final hasCover = current?.kind == 'Notebook';
    final paperCount = current?.pages.length ?? 1;
    final totalSheets = (hasCover ? 1 : 0) + paperCount;
    final totalContentHeight =
        totalSheets * pageHeight + (totalSheets + 1) * 24.0;
    final totalHeight = totalContentHeight * scale;

    final minY = totalHeight <= constraints.maxHeight
        ? 0.0
        : constraints.maxHeight - totalHeight;

    final targetTy = (-sheetTop * scale + 24.0).clamp(minY, 0.0);

    final matrix = session.view.value.clone();
    matrix.storage[13] = targetTy;
    session.view.value = matrix;
    setState(() {});
  }

  int _getCurrentActivePageIndex(double pageHeight) {
    if (current == null) return 0;
    final scale = session.view.value.getMaxScaleOnAxis();
    final currentTy = session.view.value.storage[13];
    final hasCover = current!.kind == 'Notebook';
    final paperCount = current!.pages.length;
    final totalSheets = (hasCover ? 1 : 0) + paperCount;
    if (scale <= 0) return 0;
    final offset = -currentTy / scale;
    return (offset / (pageHeight + 24.0)).round().clamp(0, totalSheets - 1);
  }

  void _toggleBookmark(int sheetIndex) {
    if (current == null) return;
    snapshot();
    setState(() {
      final hasCover = current!.kind == 'Notebook';
      if (hasCover && sheetIndex == 0) {
        current!.coverBookmarked = !current!.coverBookmarked;
      } else {
        final paperIdx = hasCover ? sheetIndex - 1 : sheetIndex;
        if (paperIdx >= 0 && paperIdx < current!.pages.length) {
          current!.pages[paperIdx].isBookmarked =
              !current!.pages[paperIdx].isBookmarked;
        }
      }
      save();
    });
  }

  void _duplicatePage(
    int sheetIndex,
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (current == null) return;
    final hasCover = current!.kind == 'Notebook';
    final paperIdx = hasCover ? sheetIndex - 1 : sheetIndex;
    if (paperIdx >= 0 && paperIdx < current!.pages.length) {
      snapshot();
      setState(() {
        final original = current!.pages[paperIdx];
        current!.pages.insert(paperIdx + 1, original.copy());
        save();
        status = 'Page duplicated';
      });
      _scrollToPage(sheetIndex + 1, constraints, pageWidth, pageHeight);
    }
  }

  void _deletePage(
    int sheetIndex,
    BoxConstraints constraints,
    double pageWidth,
    double pageHeight,
  ) {
    if (current == null || current!.pages.length <= 1) return;
    final hasCover = current!.kind == 'Notebook';
    final paperIdx = hasCover ? sheetIndex - 1 : sheetIndex;
    if (paperIdx >= 0 && paperIdx < current!.pages.length) {
      snapshot();
      setState(() {
        current!.pages.removeAt(paperIdx);
        save();
        status = 'Page deleted';
      });
      _scrollToPage(
        math.max(0, sheetIndex - 1),
        constraints,
        pageWidth,
        pageHeight,
      );
    }
  }

  void formatText({double? size, bool? bold}) {
    snapshot();
    final pageIndex = session.activeTextPage.clamp(
      0,
      current!.pages.length - 1,
    );
    final page = current!.pages[pageIndex];
    final controller = session.controllerForPage(
      pageIndex,
      page.text,
      serializedRanges: page.textStyles,
    );
    final patch = <String, dynamic>{};
    if (size != null) {
      patch['fontSize'] = size;
    }
    if (bold != null) {
      patch['bold'] = bold;
    }
    if (patch.isNotEmpty &&
        session.textFormatScope == TextFormatScope.selection &&
        !controller.selection.isCollapsed) {
      controller.applyStyle(controller.selection, patch);
      page.textStyles = controller.serializedRanges;
      setState(save);
      return;
    }
    if (patch.isNotEmpty &&
        session.textFormatScope == TextFormatScope.textBox &&
        controller.text.isNotEmpty) {
      controller.applyStyle(
        TextSelection(baseOffset: 0, extentOffset: controller.text.length),
        patch,
      );
      page.textStyles = controller.serializedRanges;
      setState(save);
      return;
    }
    setState(() {
      current!.fontSize = size ?? current!.fontSize;
      current!.boldText = bold ?? current!.boldText;
      save();
    });
    final width = current!.landscape ? 980.0 : 760.0;
    final height = current!.landscape ? 760.0 : 980.0;
    final focusedPage = session.activeTextPage.clamp(
      0,
      current!.pages.length - 1,
    );
    _paperChanged(
      0,
      current!.pages.first.text,
      width,
      height,
      recordUndo: false,
      caretSource: focusedPage,
    );
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
    _paperChanged(
      0,
      changed.pages.first.text,
      changed.landscape ? 980 : 760,
      changed.landscape ? 760 : 980,
      recordUndo: false,
      caretSource: session.activeTextPage.clamp(0, changed.pages.length - 1),
    );
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
      session.composingPages.clear();
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
    _inkHoldTimer?.cancel();
    _overscrollResetTimer?.cancel();
    _overscrollBounceController?.dispose();
    _stopPageCreationAnimation();
    _stopFling();
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
          onToggleSidebar: () => setState(() {
            if (inLibrary) {
              showSidebar = !showSidebar;
            } else {
              showPagesSidebar = !showPagesSidebar;
            }
          }),
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
          const SingleActivator(LogicalKeyboardKey.keyW): () {
            chooseTool(EditorTool.pen);
          },
          const SingleActivator(LogicalKeyboardKey.keyP): () {
            chooseTool(EditorTool.pen);
            setState(() => session.writingMode = WritingMode.pen);
          },
          const SingleActivator(LogicalKeyboardKey.keyB): () {
            chooseTool(EditorTool.pen);
            setState(() => session.writingMode = WritingMode.highlighter);
          },
          const SingleActivator(LogicalKeyboardKey.keyA): () {
            chooseTool(EditorTool.pen);
            setState(() => session.writingMode = WritingMode.tape);
          },
          const SingleActivator(LogicalKeyboardKey.keyD): () {
            chooseTool(EditorTool.pen);
            setState(() => session.writingMode = WritingMode.drawShape);
          },
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
        onKeyEvent: (_, event) {
          if (event.logicalKey == LogicalKeyboardKey.space) setState(() {});
          return KeyEventResult.ignored;
        },
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPagesSidebar)
                PagesSidebar(
                  note: note,
                  session: session,
                  onClose: () => setState(() => showPagesSidebar = false),
                  onSelectPage: (idx) {
                    if (_lastConstraints != null) {
                      _scrollToPage(
                        idx,
                        _lastConstraints!,
                        pageWidth,
                        pageHeight,
                      );
                    }
                  },
                  onAddPage: () {
                    if (_lastConstraints != null) {
                      _createNextPage(_lastConstraints!, pageWidth, pageHeight);
                    }
                  },
                  currentPageIndex: _getCurrentActivePageIndex(pageHeight),
                  onDeletePage: (idx) {
                    if (_lastConstraints != null) {
                      _deletePage(
                        idx,
                        _lastConstraints!,
                        pageWidth,
                        pageHeight,
                      );
                    }
                  },
                  onDuplicatePage: (idx) {
                    if (_lastConstraints != null) {
                      _duplicatePage(
                        idx,
                        _lastConstraints!,
                        pageWidth,
                        pageHeight,
                      );
                    }
                  },
                  onToggleBookmark: _toggleBookmark,
                ),
              Expanded(
                child: Column(
                  children: [
                    WorkspaceToolbar(
                      session: session,
                      note: note,
                      onTool: chooseTool,
                      onSettings: () => setState(() {
                        applyShapeToolSettingsToSelection();
                        save();
                      }),
                      onUndo: undo.isEmpty ? null : () => history(true),
                      onRedo: redo.isEmpty ? null : () => history(false),
                      onDelete:
                          session.selection.isEmpty && !session.textBoxSelected
                          ? null
                          : deleteSelection,
                      onZoom: zoom,
                      onStyle: styleDocument,
                      onFontSize: (v) => formatText(size: v),
                      onBold: () => formatText(bold: !note.boldText),
                      hasStylus: hasStylus,
                      onAddPage: () {
                        if (_lastConstraints != null) {
                          _createNextPage(
                            _lastConstraints!,
                            pageWidth,
                            pageHeight,
                          );
                        }
                      },
                      onExport: () => transfer('export'),
                      onTogglePages: () =>
                          setState(() => showPagesSidebar = !showPagesSidebar),
                      showPages: showPagesSidebar,
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
                          final totalContentHeight =
                              totalSheets * pageHeight +
                              (totalSheets + 1) * 24.0;
                          final isFittingHorizontally =
                              paperWidth <= constraints.maxWidth;
                          final isFittingVertically =
                              (totalContentHeight * scale) <=
                              constraints.maxHeight;
                          final childWidth = isFittingHorizontally
                              ? (constraints.maxWidth / scale)
                              : pageWidth;
                          final childHeight = isFittingVertically
                              ? math.max(
                                  constraints.maxHeight / scale,
                                  totalContentHeight,
                                )
                              : totalContentHeight + 80.0;
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Listener(
                                  behavior: HitTestBehavior.translucent,
                                  onPointerHover: (event) {
                                    if (event.kind ==
                                            PointerDeviceKind.stylus ||
                                        event.kind ==
                                            PointerDeviceKind.invertedStylus) {
                                      tablets.observePen();
                                    }
                                  },
                                  onPointerDown: (event) {
                                    _stopFling();
                                    _stopPageCreationAnimation();
                                    if (event.kind ==
                                            PointerDeviceKind.stylus ||
                                        event.kind ==
                                            PointerDeviceKind.invertedStylus) {
                                      if (!hasStylus) {
                                        tablets.observePen();
                                      }
                                    }
                                    final isSpace = HardwareKeyboard.instance
                                        .isLogicalKeyPressed(
                                          LogicalKeyboardKey.space,
                                        );
                                    final isMiddle = (event.buttons & 4) != 0;
                                    if (isSpace ||
                                        isMiddle ||
                                        tool == EditorTool.hand) {
                                      _isPanning = true;
                                      _panStartPos = event.position;
                                      _panStartMatrix = session.view.value
                                          .clone();
                                    }
                                  },
                                  onPointerMove: (event) {
                                    if (_isPanning &&
                                        _panStartPos != null &&
                                        _panStartMatrix != null) {
                                      final delta =
                                          event.position - _panStartPos!;
                                      final matrix = _panStartMatrix!.clone();
                                      final scale = matrix.getMaxScaleOnAxis();
                                      final (
                                        minX,
                                        minY,
                                      ) = _getCanvasScrollBounds(
                                        constraints,
                                        pageWidth,
                                        pageHeight,
                                        scale,
                                      );
                                      final startTx =
                                          _panStartMatrix!.storage[12];
                                      final startTy =
                                          _panStartMatrix!.storage[13];
                                      final newTx = (startTx + delta.dx).clamp(
                                        minX,
                                        0.0,
                                      );
                                      final newTy = (startTy + delta.dy).clamp(
                                        minY,
                                        0.0,
                                      );
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
                                      _snapHorizontalToCenter(
                                        constraints,
                                        pageWidth,
                                      );
                                      setState(() {});
                                    }
                                  },
                                  onPointerCancel: (event) {
                                    if (_isPanning) {
                                      _isPanning = false;
                                      _panStartPos = null;
                                      _panStartMatrix = null;
                                      _snapHorizontalToCenter(
                                        constraints,
                                        pageWidth,
                                      );
                                      setState(() {});
                                    }
                                  },
                                  onPointerPanZoomStart: (event) {
                                    _isTrackpadPanning = true;
                                    _stopFling();
                                    _stopPageCreationAnimation();
                                    _pinchScale = 1;
                                    _accumulatedPanY = 0.0;
                                    _panVelocityTracker =
                                        VelocityTracker.withKind(
                                          PointerDeviceKind.trackpad,
                                        );
                                    _panVelocityTracker.addPosition(
                                      event.timeStamp,
                                      Offset.zero,
                                    );
                                  },
                                  onPointerPanZoomUpdate: (event) {
                                    if (event.scale != _pinchScale) {
                                      zoom(event.scale / _pinchScale);
                                    }
                                    _pinchScale = event.scale;
                                    if (event.panDelta != Offset.zero) {
                                      _accumulatedPanY += event.panDelta.dy;
                                      _panVelocityTracker.addPosition(
                                        event.timeStamp,
                                        Offset(0, _accumulatedPanY),
                                      );
                                      final scrollDelta = Offset(
                                        -event.panDelta.dx,
                                        -event.panDelta.dy,
                                      );
                                      _handleScrollDelta(
                                        scrollDelta,
                                        constraints,
                                        pageWidth,
                                        pageHeight,
                                      );
                                    }
                                  },
                                  onPointerPanZoomEnd: (_) {
                                    _isTrackpadPanning = false;
                                    _pinchScale = 1;
                                    _snapHorizontalToCenter(
                                      constraints,
                                      pageWidth,
                                    );
                                    if (_bottomOverscroll > 0 &&
                                        !_isCreatingPage) {
                                      _startBounceBack(
                                        constraints,
                                        pageWidth,
                                        pageHeight,
                                      );
                                    } else if (!_isCreatingPage) {
                                      final velocity = _panVelocityTracker
                                          .getVelocity();
                                      final vy = velocity.pixelsPerSecond.dy;
                                      if (vy.abs() > 40.0) {
                                        _startFling(
                                          vy,
                                          constraints,
                                          pageWidth,
                                          pageHeight,
                                        );
                                      }
                                    }
                                  },
                                  onPointerSignal: (event) {
                                    if (event is PointerScrollEvent) {
                                      _stopFling();
                                      _stopPageCreationAnimation();
                                      _handleScrollDelta(
                                        event.scrollDelta,
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
                                      _snapHorizontalToCenter(
                                        constraints,
                                        pageWidth,
                                      );
                                      setState(() {});
                                    },
                                    child: SizedBox(
                                      width: childWidth,
                                      height: childHeight,
                                      child: Listener(
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: (event) {
                                          if (event.kind ==
                                                  PointerDeviceKind.stylus ||
                                              event.kind ==
                                                  PointerDeviceKind
                                                      .invertedStylus) {
                                            if (!hasStylus) {
                                              tablets.observePen();
                                            }
                                          }
                                          final sheetLeft =
                                              (childWidth - pageWidth) / 2;
                                          final onSheet =
                                              event.localPosition.dx >=
                                                  sheetLeft &&
                                              event.localPosition.dx <=
                                                  sheetLeft + pageWidth &&
                                              event.localPosition.dy >= 24 &&
                                              event.localPosition.dy <=
                                                  totalContentHeight - 24;
                                          if (!onSheet &&
                                              tool != EditorTool.hand &&
                                              (event.buttons & 1) != 0) {
                                            _isPanning = true;
                                            _panStartPos = event.position;
                                            _panStartMatrix = session.view.value
                                                .clone();
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
                                                    key: ValueKey(
                                                      'cover-page-${note.id}',
                                                    ),
                                                    width: pageWidth,
                                                    height: pageHeight,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.35,
                                                                ),
                                                            blurRadius: 16,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  4,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: DocumentCover(
                                                        note,
                                                      ),
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
                                                  if (i > 0)
                                                    const SizedBox(height: 24),
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
                                ),
                              ),
                              Positioned(
                                top: 6,
                                bottom: 6,
                                right: 4,
                                child: CanvasScrollIndicator(
                                  session: session,
                                  constraints: constraints,
                                  pageWidth: pageWidth,
                                  pageHeight: pageHeight,
                                  note: note,
                                  isCreatingPage: _isCreatingPage,
                                  bottomOverscroll: _bottomOverscroll,
                                  onScrollTo: (ty) {
                                    _stopFling();
                                    _stopPageCreationAnimation();
                                    final m = session.view.value.clone();
                                    m.storage[13] = ty;
                                    session.view.value = m;
                                  },
                                ),
                              ),
                              Positioned(
                                top: 14,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: FloatingToolControls(
                                    session: session,
                                    note: note,
                                    onSettings: () => setState(() {
                                      applyShapeToolSettingsToSelection();
                                      save();
                                    }),
                                    onFontSize: (v) => formatText(size: v),
                                    onBold: () =>
                                        formatText(bold: !note.boldText),
                                    onZoom: zoom,
                                    onDelete:
                                        session.selection.isEmpty &&
                                            !session.textBoxSelected
                                        ? null
                                        : deleteSelection,
                                    onClearPage: clearActivePageInk,
                                    onRemoveAllTape: removeAllTape,
                                    onOpenCustomColor: _showCustomColorPicker,
                                  ),
                                ),
                              ),
                            ],
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
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Builder(
                            builder: (_) {
                              final hasCover = note.kind == 'Notebook';
                              final totalPages =
                                  (hasCover ? 1 : 0) + note.pages.length;
                              final scale = session.view.value
                                  .getMaxScaleOnAxis();
                              final scrollY = session.view.value.storage[13]
                                  .abs();
                              final sheetHeightWithGap =
                                  (pageHeight + 24.0) * scale;
                              final pageNum =
                                  (sheetHeightWithGap <= 0
                                          ? 1
                                          : ((scrollY +
                                                            sheetHeightWithGap *
                                                                0.4) /
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
    final pageController = session.controllerForPage(
      pageIndex,
      page.text,
      serializedRanges: page.textStyles,
    );
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
                      fontFamily: note.fontFamily,
                      italic: note.italicText,
                      underline: note.underlineText,
                      strikethrough: note.strikethroughText,
                      textAlign: note.textAlign == 'center'
                          ? TextAlign.center
                          : note.textAlign == 'right'
                          ? TextAlign.right
                          : TextAlign.left,
                      lineHeight: note.lineHeight,
                      lineHeightAuto: note.lineHeightAuto,
                      textColor: note.textColor,
                      textBoxBgColor: note.textBoxBgColor,
                      textBoxBorderColor: note.textBoxBorderColor,
                      textBoxRadius: note.textBoxRadius,
                      textBoxBorder: note.textBoxBorder,
                      textBoxPadding: note.textBoxPadding,
                      textBoxShadow: note.textBoxShadow,
                      textBoxOffset: Offset(
                        page.textBoxOffsetX,
                        page.textBoxOffsetY,
                      ),
                      textBoxScale: page.textBoxScale,
                      textBoxRotation: page.textBoxRotation,
                      foreground: foreground,
                      pageWidth: pageWidth,
                      pageHeight: pageHeight,
                      onChanged: (value) => _paperChanged(
                        pageIndex,
                        value,
                        pageWidth,
                        pageHeight,
                        textStyles: pageController.serializedRanges,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring:
                        tool == EditorTool.text || tool == EditorTool.hand,
                    child: MouseRegion(
                      cursor: _showInkFootprint
                          ? SystemMouseCursors.none
                          : SystemMouseCursors.precise,
                      onEnter: (e) => _trackInkPointer(e, pageIndex),
                      onHover: (e) => _trackInkPointer(e, pageIndex),
                      onExit: (_) => setState(() {
                        _inkHover = null;
                        _inkHoverPage = null;
                      }),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          _trackInkPointer(e, pageIndex);
                          pointerDown(e, pageIndex: pageIndex);
                        },
                        onPointerMove: (e) {
                          _trackInkPointer(e, pageIndex);
                          pointerMove(e);
                        },
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
                        child: AnimatedBuilder(
                          animation: session.view,
                          builder: (paperContext, _) => CustomPaint(
                            foregroundPainter:
                                _showInkFootprint &&
                                    _inkHover != null &&
                                    _inkHoverPage == pageIndex
                                ? InkFootprintPainter(
                                    position: _inkHover!,
                                    resolvePosition: () =>
                                        (paperContext.findRenderObject()
                                                as RenderBox)
                                            .globalToLocal(_inkGlobalPointer!),
                                    material: InkMaterial(
                                      activeStyle ?? session.inkStyle(),
                                    ),
                                    color: Color(
                                      (activeStyle?['color'] as int?) ??
                                          session.color ??
                                          foreground.toARGB32(),
                                    ),
                                    pressure: _inkPressure,
                                    eraserRadius:
                                        session.tool == EditorTool.eraser
                                        ? session.eraserRadius
                                        : null,
                                  )
                                : null,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: InkPainter(
                                  [
                                    ...page.strokes,
                                    if (activeStrokePageIndex == pageIndex &&
                                        activeStroke != null)
                                      _displayActiveStroke,
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
                                  selectionBox:
                                      activeStrokePageIndex == pageIndex
                                      ? selectionBox
                                      : null,
                                  selectionPath:
                                      activeStrokePageIndex == pageIndex
                                      ? selectionPath
                                      : null,
                                  selectedBounds:
                                      activeStrokePageIndex == pageIndex
                                      ? selectedBounds()
                                      : null,
                                  hasSelection:
                                      activeStrokePageIndex == pageIndex &&
                                      (session.selection.isNotEmpty ||
                                          session.textBoxSelected),
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
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

  void _paperChanged(
    int pageIndex,
    String value,
    double width,
    double height, {
    bool recordUndo = true,
    int? caretSource,
    List<Map<String, dynamic>>? textStyles,
  }) {
    final note = current!;
    var caretPage = caretSource ?? pageIndex;
    final controller = session.controllerForPage(
      caretPage,
      note.pages[caretPage].text,
    );
    var caretOffset = controller.selection.baseOffset.clamp(
      0,
      controller.text.length,
    );
    final initialCaretPage = caretPage;
    final composing =
        controller.value.composing.isValid &&
        !controller.value.composing.isCollapsed;
    if (recordUndo) {
      if (composing) {
        if (session.composingPages.add(pageIndex)) snapshot();
      } else if (!session.composingPages.remove(pageIndex)) {
        snapshot();
      }
    }
    setState(() {
      note.pages[pageIndex].text = value;
      if (textStyles != null) {
        note.pages[pageIndex].textStyles = textStyles;
      }
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
          if (caretPage == i + 1) caretOffset += overflow.length;
          if (caretPage == i && caretOffset >= split) {
            caretPage++;
            caretOffset -= split;
          }
          final first = session.controllerForPage(
            i,
            note.pages[i].text,
            serializedRanges: note.pages[i].textStyles,
          );
          first.value = TextEditingValue(
            text: note.pages[i].text,
            selection: TextSelection.collapsed(
              offset: first.selection.baseOffset.clamp(
                0,
                note.pages[i].text.length,
              ),
            ),
          );
          final next = session.controllerForPage(
            i + 1,
            note.pages[i + 1].text,
            serializedRanges: note.pages[i + 1].textStyles,
          );
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
    if (caretPage != initialCaretPage) {
      final target = caretPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || current?.id != note.id) return;
        session.focusNodeForPage(target).requestFocus();
        _panCanvas(
          Offset(
            0,
            -(height + 24) *
                (target - initialCaretPage) *
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
    if (points.isEmpty && !session.textBoxSelected) {
      return null;
    }
    final strokeBounds = points.isEmpty
        ? null
        : Rect.fromLTRB(
            points.map((p) => p[0]).reduce(math.min),
            points.map((p) => p[1]).reduce(math.min),
            points.map((p) => p[0]).reduce(math.max),
            points.map((p) => p[1]).reduce(math.max),
          );
    final textBounds = session.textBoxSelected ? _textBoxBounds(page) : null;
    if (strokeBounds == null) return textBounds!.inflate(8);
    if (textBounds == null) return strokeBounds.inflate(8);
    return strokeBounds.expandToInclude(textBounds).inflate(8);
  }

  Rect _textBoxBounds(NotebookPage page) {
    final width = current?.landscape == true ? 980.0 : 760.0;
    final height = current?.landscape == true ? 760.0 : 980.0;
    final lines = math.max(1, '\n'.allMatches(page.text).length + 1);
    final contentHeight = (lines * 28.0 + 32.0).clamp(48.0, height - 32.0);
    final base = Rect.fromLTWH(24, 24, width - 48, contentHeight);
    final scaled = Rect.fromLTWH(
      base.left,
      base.top,
      base.width * page.textBoxScale,
      base.height * page.textBoxScale,
    );
    return scaled.shift(Offset(page.textBoxOffsetX, page.textBoxOffsetY));
  }

  bool _strokeIncluded(Map<String, dynamic> style) {
    final kind = style['kind'] as String?;
    if (kind == 'tape') return session.lassoIncludes['Tape'] ?? true;
    if (kind == 'shape' || kind == 'placedShape') {
      return session.lassoIncludes['Shapes'] ?? true;
    }
    if (kind == 'arrow') return session.lassoIncludes['Arrows'] ?? true;
    if (kind == 'image') return session.lassoIncludes['Images'] ?? true;
    return session.lassoIncludes['Handwriting'] ?? true;
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final intersects =
          ((a.dy > point.dy) != (b.dy > point.dy)) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
      if (intersects) inside = !inside;
    }
    return inside;
  }

  List<List<double>> _shapePoints(ShapeType type, Rect bounds) {
    final width = math.max(bounds.width, 1.0);
    final height = math.max(bounds.height, 1.0);
    final center = bounds.center;
    final left = bounds.left;
    final top = bounds.top;
    final right = bounds.right;
    final bottom = bounds.bottom;
    switch (type) {
      case ShapeType.rectangle:
        return [
          [left, top, 1],
          [right, top, 1],
          [right, bottom, 1],
          [left, bottom, 1],
          [left, top, 1],
        ];
      case ShapeType.ellipse:
        return [
          for (var i = 0; i <= 48; i++)
            [
              center.dx + width / 2 * math.cos(2 * math.pi * i / 48),
              center.dy + height / 2 * math.sin(2 * math.pi * i / 48),
              1,
            ],
        ];
      case ShapeType.triangle:
        return [
          [center.dx, top, 1],
          [right, bottom, 1],
          [left, bottom, 1],
          [center.dx, top, 1],
        ];
      case ShapeType.diamond:
        return [
          [center.dx, top, 1],
          [right, center.dy, 1],
          [center.dx, bottom, 1],
          [left, center.dy, 1],
          [center.dx, top, 1],
        ];
      case ShapeType.hexagon:
        return [
          for (var i = 0; i <= 6; i++)
            [
              center.dx + width / 2 * math.cos(math.pi / 3 * i),
              center.dy + height / 2 * math.sin(math.pi / 3 * i),
              1,
            ],
        ];
      case ShapeType.star:
        return [
          for (var i = 0; i <= 10; i++)
            [
              center.dx +
                  (i.isEven ? width / 2 : width / 4) *
                      math.cos(-math.pi / 2 + math.pi * i / 5),
              center.dy +
                  (i.isEven ? height / 2 : height / 4) *
                      math.sin(-math.pi / 2 + math.pi * i / 5),
              1,
            ],
        ];
      case ShapeType.heart:
        return [
          for (var i = 0; i <= 40; i++)
            () {
              final t = 2 * math.pi * i / 40;
              final x = 16 * math.pow(math.sin(t), 3).toDouble();
              final y =
                  -(13 * math.cos(t) -
                      5 * math.cos(2 * t) -
                      2 * math.cos(3 * t) -
                      math.cos(4 * t));
              return [
                center.dx + x / 16 * width / 2,
                center.dy + y / 17 * height / 2,
                1.0,
              ];
            }(),
        ];
    }
  }

  void applyShapeToolSettingsToSelection() {
    if (session.tool != EditorTool.shapes) return;
    final page = _activePage;
    for (final index in session.selection) {
      if (index >= page.inkStyles.length) continue;
      final style = page.inkStyles[index];
      if (style['kind'] != 'placedShape') continue;
      style
        ..['color'] = session.shapeToolStrokeColor
        ..['fillColor'] = session.shapeToolFillColor
        ..['fill'] = session.shapeToolFilled
        ..['width'] = session.shapeToolStrokeWidth;
    }
  }

  bool _selectionContains(Offset point) {
    if (session.lassoType == LassoType.freehand) {
      final path = selectionPath;
      return path != null && path.length >= 3 && _pointInPolygon(point, path);
    }
    return selectionBox?.contains(point) ?? false;
  }

  void _captureSelectionGeometry() {
    final page = _activePage;
    _selectionStartTextScale = page.textBoxScale;
    _selectionStartTextRotation = page.textBoxRotation;
    _selectionOriginalStrokes = {
      for (final index in session.selection)
        if (index < page.strokes.length)
          index: [
            for (final point in page.strokes[index]) List<double>.from(point),
          ],
    };
    final bounds = selectedBounds();
    _selectionCenter = bounds?.center;
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
    if (session.tool == EditorTool.shapes) {
      snapshot();
      _shapePlacementMoved = false;
      activeStyle = {
        'kind': 'placedShape',
        'shapeType': session.shapeType.name,
        'materialVersion': 0,
        'width': session.shapeToolStrokeWidth,
        'color': session.shapeToolStrokeColor,
        'fill': session.shapeToolFilled,
        'fillColor': session.shapeToolFillColor,
      };
      setState(
        () => activeStroke = _shapePoints(
          session.shapeType,
          Rect.fromCenter(center: e.localPosition, width: 1, height: 1),
        ),
      );
      return;
    } else if (session.tool == EditorTool.select) {
      final bounds = selectedBounds();
      final center = bounds?.center;
      final rotationHandle = center == null
          ? null
          : Offset(center.dx, bounds!.top - 24);
      final resizeHandle = bounds?.bottomRight;
      if (rotationHandle != null &&
          (e.localPosition - rotationHandle).distance <= 14) {
        final selectionCenter = center!;
        selectionTransformMode = SelectionTransformMode.rotate;
        _selectionCenter = selectionCenter;
        _selectionStartAngle = math.atan2(
          e.localPosition.dy - selectionCenter.dy,
          e.localPosition.dx - selectionCenter.dx,
        );
        _captureSelectionGeometry();
      } else if (resizeHandle != null &&
          (e.localPosition - resizeHandle).distance <= 14) {
        final selectionCenter = center!;
        selectionTransformMode = SelectionTransformMode.resize;
        _selectionCenter = selectionCenter;
        _selectionStartDistance = (e.localPosition - selectionCenter).distance;
        _captureSelectionGeometry();
      } else if (bounds?.contains(e.localPosition) == true) {
        movingSelection = true;
        selectionTransformMode = SelectionTransformMode.move;
        _captureSelectionGeometry();
      } else {
        selectionTransformMode = SelectionTransformMode.lasso;
        setState(() => session.selection.clear());
        session.textBoxSelected = false;
        if (session.lassoType == LassoType.freehand) {
          selectionPath = [e.localPosition];
        }
      }
    } else if (session.tool == EditorTool.eraser) {
      eraseAt(e.localPosition, pageIndex: pageIndex);
    } else {
      snapshot();
      normalizeStyles();
      activeStyle = session.inkStyle();
      _inkHeld = false;
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
    if (session.tool == EditorTool.shapes) {
      final start = gestureStart!;
      final bounds = Rect.fromPoints(start, e.localPosition);
      if (bounds.width >= 4 || bounds.height >= 4) {
        _shapePlacementMoved = true;
      }
      setState(() {
        activeStroke = _shapePoints(session.shapeType, bounds);
      });
      lastPoint = e.localPosition;
    } else if (session.tool == EditorTool.eraser) {
      final start = lastPoint ?? e.localPosition;
      final delta = e.localPosition - start;
      final steps = math.max(
        1,
        (delta.distance / math.max(1, session.eraserRadius / 2)).ceil(),
      );
      for (var i = 1; i <= steps; i++) {
        eraseAt(
          start + delta * (i / steps),
          pageIndex: activeStrokePageIndex,
          persist: false,
        );
      }
      if (editedGesture) save();
    } else if (session.tool == EditorTool.select) {
      setState(() {
        if (selectionTransformMode == SelectionTransformMode.move) {
          if (!editedGesture) {
            snapshot();
            editedGesture = true;
          }
          final delta = e.localPosition - lastPoint!;
          final page = _activePage;
          if (session.textBoxSelected) {
            page.textBoxOffsetX += delta.dx;
            page.textBoxOffsetY += delta.dy;
          }
          for (final i in session.selection) {
            if (i < page.strokes.length) {
              for (final p in page.strokes[i]) {
                p[0] += delta.dx;
                p[1] += delta.dy;
              }
            }
          }
        } else if (selectionTransformMode == SelectionTransformMode.resize ||
            selectionTransformMode == SelectionTransformMode.rotate) {
          if (!editedGesture) {
            snapshot();
            editedGesture = true;
          }
          final center = _selectionCenter;
          final originals = _selectionOriginalStrokes;
          if (center != null && originals != null) {
            var scale = 1.0;
            var angle = 0.0;
            if (selectionTransformMode == SelectionTransformMode.resize) {
              scale =
                  ((e.localPosition - center).distance /
                          math.max(1, _selectionStartDistance))
                      .clamp(0.1, 10.0);
            } else {
              final currentAngle = math.atan2(
                e.localPosition.dy - center.dy,
                e.localPosition.dx - center.dx,
              );
              angle = currentAngle - _selectionStartAngle;
            }
            final sinAngle = math.sin(angle);
            final cosAngle = math.cos(angle);
            final page = _activePage;
            if (session.textBoxSelected) {
              page.textBoxScale = (_selectionStartTextScale * scale).clamp(
                0.25,
                4.0,
              );
            }
            for (final entry in originals.entries) {
              if (entry.key >= page.strokes.length) continue;
              page.strokes[entry.key] = [
                for (final point in entry.value)
                  () {
                    final dx = point[0] - center.dx;
                    final dy = point[1] - center.dy;
                    final sx = dx * scale;
                    final sy = dy * scale;
                    return [
                      center.dx + sx * cosAngle - sy * sinAngle,
                      center.dy + sx * sinAngle + sy * cosAngle,
                      point[2],
                    ];
                  }(),
              ];
            }
            if (session.textBoxSelected) {
              page.textBoxRotation = _selectionStartTextRotation + angle;
            }
          }
        } else {
          if (session.lassoType == LassoType.freehand) {
            selectionPath ??= [];
            selectionPath!.add(e.localPosition);
          } else {
            selectionBox = Rect.fromPoints(gestureStart!, e.localPosition);
          }
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
    _scheduleInkHold();
    lastPoint = e.localPosition;
  }

  void eraseAt(Offset position, {int? pageIndex, bool persist = true}) {
    final targetIndex = pageIndex ?? activeStrokePageIndex;
    if (current == null || targetIndex >= current!.pages.length) return;
    final page = current!.pages[targetIndex];
    final radius = session.eraserRadius.clamp(4.0, 60.0);
    normalizeStyles();

    bool canEraseStyle(Map<String, dynamic> style) {
      final kind = style['kind'] as String?;
      final opacity = (style['opacity'] as num?)?.toDouble() ?? 1.0;
      if (kind == 'tape') {
        return session.eraserFilters['Tape'] ?? true;
      }
      if (kind == 'highlighter' || (kind == null && opacity < 1.0)) {
        return session.eraserFilters['Highlighter'] ?? true;
      }
      if (kind == 'pencil') {
        return session.eraserFilters['Pencil'] ?? true;
      }
      return session.eraserFilters['Pen'] ?? true;
    }

    if (session.eraserType == EraserType.stroke) {
      final hits = <int>[];
      for (var i = 0; i < page.strokes.length; i++) {
        if (i < page.inkStyles.length && !canEraseStyle(page.inkStyles[i])) {
          continue;
        }
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
      if (hits.isEmpty) return;
      setState(() {
        if (!editedGesture) {
          snapshot();
          editedGesture = true;
        }
        for (final i in hits.reversed) {
          page.strokes.removeAt(i);
          page.inkStyles.removeAt(i);
        }
        if (persist) save();
      });
      return;
    }

    // Precision & Standard: slice only the exact pixels/points within radius!
    bool anyModified = false;
    final newStrokes = <List<List<double>>>[];
    final newStyles = <Map<String, dynamic>>[];

    for (var i = 0; i < page.strokes.length; i++) {
      final stroke = page.strokes[i];
      final style = i < page.inkStyles.length
          ? page.inkStyles[i]
          : <String, dynamic>{};
      if (!canEraseStyle(style) || stroke.isEmpty) {
        newStrokes.add(stroke);
        newStyles.add(style);
        continue;
      }

      double minX = stroke[0][0], maxX = stroke[0][0];
      double minY = stroke[0][1], maxY = stroke[0][1];
      for (final p in stroke) {
        if (p[0] < minX) minX = p[0];
        if (p[0] > maxX) maxX = p[0];
        if (p[1] < minY) minY = p[1];
        if (p[1] > maxY) maxY = p[1];
      }
      final bbox = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(radius + 4.0);
      if (!bbox.contains(position)) {
        newStrokes.add(stroke);
        newStyles.add(style);
        continue;
      }

      // Densify points along stroke segments so fast swipes don't skip
      final dense = <List<double>>[];
      for (var j = 0; j < stroke.length; j++) {
        final p1 = stroke[j];
        if (j == 0) {
          dense.add(p1);
        } else {
          final p0 = stroke[j - 1];
          final dist = (Offset(p1[0], p1[1]) - Offset(p0[0], p0[1])).distance;
          final step = math.max(1.8, radius / 2.5);
          if (dist > step) {
            final count = (dist / step).ceil();
            for (var k = 1; k < count; k++) {
              final t = k / count;
              dense.add([
                p0[0] + (p1[0] - p0[0]) * t,
                p0[1] + (p1[1] - p0[1]) * t,
                p0[2] + (p1[2] - p0[2]) * t,
              ]);
            }
          }
          dense.add(p1);
        }
      }

      final segments = <List<List<double>>>[];
      List<List<double>> currentSegment = [];
      bool strokeHit = false;

      for (final p in dense) {
        final isInside = (Offset(p[0], p[1]) - position).distance <= radius;
        if (isInside) {
          strokeHit = true;
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            currentSegment = [];
          }
        } else {
          currentSegment.add(p);
        }
      }
      if (currentSegment.isNotEmpty) {
        segments.add(currentSegment);
      }

      if (strokeHit) {
        anyModified = true;
        for (final seg in segments) {
          if (seg.isNotEmpty) {
            newStrokes.add(seg);
            newStyles.add(Map<String, dynamic>.from(style));
          }
        }
      } else {
        newStrokes.add(stroke);
        newStyles.add(style);
      }
    }

    if (anyModified) {
      setState(() {
        if (!editedGesture) {
          snapshot();
          editedGesture = true;
        }
        page.strokes
          ..clear()
          ..addAll(newStrokes);
        page.inkStyles
          ..clear()
          ..addAll(newStyles);
        if (persist) save();
      });
    }
  }

  void clearActivePageInk() {
    final page = _activePage;
    if (page.strokes.isEmpty) return;
    snapshot();
    setState(() {
      page.strokes.clear();
      page.inkStyles.clear();
      session.selection.clear();
      save();
    });
  }

  void removeAllTape() {
    final page = _activePage;
    if (!page.inkStyles.any((style) => style['kind'] == 'tape')) return;
    snapshot();
    setState(() {
      normalizeStyles();
      for (var i = page.strokes.length - 1; i >= 0; i--) {
        if (i < page.inkStyles.length && page.inkStyles[i]['kind'] == 'tape') {
          page.strokes.removeAt(i);
          page.inkStyles.removeAt(i);
        }
      }
      save();
    });
  }

  Future<void> _showCustomColorPicker() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (ctx) =>
          CustomColorPickerDialog(initialColor: session.color ?? 0xff151515),
    );
    if (selected != null) {
      setState(() {
        session.color = selected.toARGB32();
      });
    }
  }

  void deleteSelection() {
    if (session.selection.isEmpty && !session.textBoxSelected) {
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
      if (session.textBoxSelected) {
        page.text = '';
        page.textStyles.clear();
        session
            .controllerForPage(
              activeStrokePageIndex,
              page.text,
              serializedRanges: page.textStyles,
            )
            .clear();
      }
      session.selection.clear();
      session.textBoxSelected = false;
      save();
    });
  }

  void finishStroke() {
    _inkHoldTimer?.cancel();
    if (activePointer == null) {
      return;
    }
    final page = _activePage;
    setState(() {
      if (activeStroke != null) {
        final originalPoints = activeStroke!
            .map((p) => List<double>.from(p))
            .toList();
        var finalStroke = activeStroke!;
        var finalStyle = Map<String, dynamic>.from(activeStyle!);

        final holdToShape =
            _inkHeld &&
            ((finalStyle['kind'] == 'pen' &&
                    finalStyle['holdForLine'] == true) ||
                (finalStyle['kind'] == 'pencil' &&
                    finalStyle['drawAndHold'] == true));
        if (finalStyle['kind'] == 'tape' &&
            finalStyle['straight'] == true &&
            finalStroke.length > 1) {
          finalStroke = [finalStroke.first, finalStroke.last];
        } else if ((finalStyle['kind'] == 'shape' || holdToShape) &&
            (finalStyle['requireHold'] != true || _inkHeld) &&
            finalStroke.length >= 2) {
          final recognized = ShapeRecognition.recognize(finalStroke);
          finalStroke = recognized.stroke;
          if (finalStyle['snapToShapes'] == true) {
            for (final point in finalStroke) {
              Offset? closest;
              var distance = 10.0;
              for (var i = 0; i < page.strokes.length; i++) {
                if (i >= page.inkStyles.length ||
                    page.inkStyles[i]['kind'] != 'shape') {
                  continue;
                }
                for (final target in page.strokes[i]) {
                  final candidate = Offset(target[0], target[1]);
                  final d = (candidate - Offset(point[0], point[1])).distance;
                  if (d < distance) {
                    distance = d;
                    closest = candidate;
                  }
                }
              }
              if (closest != null) {
                point[0] = closest.dx;
                point[1] = closest.dy;
              }
            }
          }
          if (recognized.isClosed && finalStyle['shapeFill'] == true) {
            finalStyle['fill'] = true;
            finalStyle['fillColor'] = finalStyle['color'];
          }
        }

        if (finalStyle['kind'] == 'placedShape' && !_shapePlacementMoved) {
          // A click alone only starts a placement; the shape is created on drag
          // release so its final dimensions come from the user's gesture.
        } else if (finalStyle['kind'] == 'shape' ||
            holdToShape ||
            !identical(finalStroke, activeStroke)) {
          if (finalStyle['kind'] == 'shape' || holdToShape) {
            finalStyle['originalPoints'] = originalPoints;
          }
          page.strokes.add(finalStroke);
          page.inkStyles.add(finalStyle);
          session.selection
            ..clear()
            ..add(page.strokes.length - 1);
          save();
        } else {
          page.strokes.add(finalStroke);
          page.inkStyles.add(finalStyle);
          session.selection
            ..clear()
            ..add(page.strokes.length - 1);
          save();
        }
      } else if (session.tool == EditorTool.select &&
          selectionTransformMode == SelectionTransformMode.lasso) {
        for (var i = 0; i < page.strokes.length; i++) {
          final style = i < page.inkStyles.length
              ? page.inkStyles[i]
              : const <String, dynamic>{};
          if (_strokeIncluded(style) &&
              page.strokes[i].any(
                (p) => _selectionContains(Offset(p[0], p[1])),
              )) {
            session.selection.add(i);
          }
        }
        if ((session.lassoIncludes['Text Boxes'] ?? true) &&
            page.text.isNotEmpty) {
          final textBounds = _textBoxBounds(page);
          final selected = selectionPath != null
              ? selectionPath!.any(
                  (point) => _pointInPolygon(point, [
                    textBounds.topLeft,
                    textBounds.topRight,
                    textBounds.bottomRight,
                    textBounds.bottomLeft,
                  ]),
                )
              : selectionBox?.overlaps(textBounds) == true;
          if (selected) session.textBoxSelected = true;
        }
      } else if (session.tool == EditorTool.eraser &&
          session.eraserAutoDeselect) {
        session.tool = session.previousTool;
      } else if (editedGesture) {
        save();
      }
      activeStroke = null;
      activeStyle = null;
      activePointer = null;
      selectionBox = null;
      selectionPath = null;
      gestureStart = null;
      movingSelection = false;
      selectionTransformMode = SelectionTransformMode.none;
      _selectionOriginalStrokes = null;
      _selectionCenter = null;
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
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: (progress > 0.02 || isCreating) ? 1.0 : 0.0,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: (0.88 + 0.12 * progress).clamp(0.88, 1.0),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : CircularProgressIndicator(
                            value: progress.clamp(0.04, 1.0),
                            strokeWidth: 2.2,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
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
        ),
      ),
    );
  }
}

class CanvasScrollIndicator extends StatefulWidget {
  const CanvasScrollIndicator({
    super.key,
    required this.session,
    required this.constraints,
    required this.pageWidth,
    required this.pageHeight,
    required this.note,
    required this.onScrollTo,
    this.isCreatingPage = false,
    this.bottomOverscroll = 0.0,
  });

  final EditorSession session;
  final BoxConstraints constraints;
  final double pageWidth;
  final double pageHeight;
  final Notebook note;
  final ValueChanged<double> onScrollTo;
  final bool isCreatingPage;
  final double bottomOverscroll;

  @override
  State<CanvasScrollIndicator> createState() => _CanvasScrollIndicatorState();
}

class _CanvasScrollIndicatorState extends State<CanvasScrollIndicator> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session.view,
      builder: (context, _) {
        final scale = widget.session.view.value.getMaxScaleOnAxis();
        final hasCover = widget.note.kind == 'Notebook';
        final paperCount = widget.note.pages.length;
        final totalSheets = (hasCover ? 1 : 0) + paperCount;
        final totalContentHeight =
            totalSheets * widget.pageHeight + (totalSheets + 1) * 24.0;
        final totalHeight = totalContentHeight * scale;
        final viewportHeight = widget.constraints.maxHeight;

        if (totalHeight <= viewportHeight + 1.0) {
          return const SizedBox.shrink();
        }

        final minY = viewportHeight - totalHeight;
        final currentTy = widget.session.view.value.storage[13].clamp(
          minY,
          0.0,
        );
        final scrollFraction = (-currentTy / -minY).clamp(0.0, 1.0);

        final trackHeight = math.max(40.0, viewportHeight - 16.0);
        final thumbHeight = ((viewportHeight / totalHeight) * trackHeight)
            .clamp(32.0, trackHeight - 10.0);
        final travelSpace = math.max(1.0, trackHeight - thumbHeight);
        final thumbTop = scrollFraction * travelSpace;

        final isActive = _isHovered || _isDragging;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            key: const Key('canvas-scroll-indicator'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final targetTop = (details.localPosition.dy - thumbHeight / 2)
                  .clamp(0.0, travelSpace);
              final frac = targetTop / travelSpace;
              final targetTy = -frac * -minY;
              widget.onScrollTo(targetTy);
            },
            onVerticalDragStart: (_) => setState(() => _isDragging = true),
            onVerticalDragEnd: (_) => setState(() => _isDragging = false),
            onVerticalDragCancel: () => setState(() => _isDragging = false),
            onVerticalDragUpdate: (details) {
              final deltaY = details.delta.dy;
              final deltaFrac = deltaY / travelSpace;
              final currentFrac = (-currentTy / -minY).clamp(0.0, 1.0);
              final newFrac = (currentFrac + deltaFrac).clamp(0.0, 1.0);
              final targetTy = -newFrac * -minY;
              widget.onScrollTo(targetTy);
            },
            child: Container(
              width: isActive ? 10.0 : 7.0,
              height: trackHeight,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: thumbTop,
                    left: 1.0,
                    right: 1.0,
                    height: thumbHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.50)
                            : Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    this.selectionPath,
    this.selectedBounds,
    this.hasSelection = false,
  }) : _fingerprint = Object.hash(
         color,
         selectionBox,
         selectedBounds,
         Object.hashAll(selected),
         selectionPath == null ? null : Object.hashAll(selectionPath),
         Object.hashAll(
           strokes.map((stroke) => Object.hashAll(stroke.expand((p) => p))),
         ),
         Object.hashAll(styles.map((style) => style.toString())),
       );
  final int _fingerprint;
  final List<Map<String, dynamic>> styles;
  final Set<int> selected;
  final Rect? selectionBox;
  final List<Offset>? selectionPath;
  final Rect? selectedBounds;
  final bool hasSelection;
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
      if (opacity < 1 && style['materialVersion'] != 1) {
        canvas.saveLayer(
          null,
          Paint()..color = Colors.white.withValues(alpha: opacity),
        );
      }
      if (style['fill'] == true && stroke.length >= 3) {
        final fillPath = Path();
        fillPath.moveTo(stroke[0][0], stroke[0][1]);
        for (var i = 1; i < stroke.length; i++) {
          fillPath.lineTo(stroke[i][0], stroke[i][1]);
        }
        fillPath.close();
        final fillColor = style['fillColor'] is int
            ? Color(style['fillColor'] as int)
            : strokeColor;
        canvas.drawPath(
          fillPath,
          Paint()
            ..color = fillColor.withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
      }
      if (style['materialVersion'] == 1) {
        InkMaterial(style).paint(canvas, stroke, strokeColor);
      } else {
        final isTape = style['kind'] == 'tape';
        final paint = Paint()
          ..color = strokeColor
          ..strokeCap = isTape ? StrokeCap.square : StrokeCap.round
          ..strokeJoin = isTape ? StrokeJoin.miter : StrokeJoin.round;
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
      }
      if (opacity < 1 && style['materialVersion'] != 1) {
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
    if (selectionPath != null && selectionPath!.length > 1) {
      final path = Path()
        ..moveTo(selectionPath!.first.dx, selectionPath!.first.dy);
      for (final point in selectionPath!.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    if (selectedBounds != null && hasSelection) {
      final bounds = selectedBounds!;
      final handlePaint = Paint()..color = color;
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawLine(
        Offset(bounds.center.dx, bounds.top),
        Offset(bounds.center.dx, bounds.top - 24),
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(bounds.center.dx, bounds.top - 24),
        5,
        handlePaint,
      );
      for (final point in [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomLeft,
        bounds.bottomRight,
      ]) {
        canvas.drawCircle(point, 5, handlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant InkPainter oldDelegate) =>
      _fingerprint != oldDelegate._fingerprint;
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
