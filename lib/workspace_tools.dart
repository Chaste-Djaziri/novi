import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'desktop_ui.dart';

import 'package:flutter/material.dart';

import 'notebook.dart';

enum EditorTool { pen, highlighter, eraser, select, text, hand }

class EditorSession {
  EditorSession(Notebook note)
    : text = TextEditingController(text: note.text),
      tool = note.kind == 'Text document' ? EditorTool.text : EditorTool.select {
    textFocus.addListener(() {
      if (textFocus.hasFocus) activeTextPage = 0;
    });
  }
  final TextEditingController text;
  final FocusNode textFocus = FocusNode();
  int activeTextPage = 0;
  final Map<int, TextEditingController> pageControllers = {};
  final Map<int, FocusNode> pageFocusNodes = {};

  TextEditingController controllerForPage(int index, String initialText) {
    if (index == 0) return text;
    return pageControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialText),
    );
  }

  FocusNode focusNodeForPage(int index) {
    if (index == 0) return textFocus;
    return pageFocusNodes.putIfAbsent(index, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) activeTextPage = index;
      });
      return node;
    });
  }

  final TransformationController view = TransformationController();
  final List<Notebook> undo = [];
  final List<Notebook> redo = [];
  final Set<int> selection = {};
  final Set<int> composingPages = {};
  EditorTool tool;
  EditorTool previousTool = EditorTool.select;
  double width = 3;
  int? color;
  void dispose() {
    text.dispose();
    textFocus.dispose();
    for (final c in pageControllers.values) {
      c.dispose();
    }
    for (final f in pageFocusNodes.values) {
      f.dispose();
    }
    view.dispose();
  }
}

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({
    super.key,
    required this.session,
    required this.note,
    required this.onTool,
    required this.onSettings,
    required this.onUndo,
    required this.onRedo,
    required this.onDelete,
    required this.onZoom,
    required this.onStyle,
    required this.onFontSize,
    required this.onBold,
    this.hasStylus = false,
    this.onAddPage,
    this.onExport,
    this.onTogglePages,
    this.showPages = false,
  });
  final EditorSession session;
  final Notebook note;
  final ValueChanged<EditorTool> onTool;
  final VoidCallback onSettings;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onDelete;
  final ValueChanged<double> onZoom;
  final VoidCallback onStyle;
  final ValueChanged<double> onFontSize;
  final VoidCallback onBold;
  final bool hasStylus;
  final VoidCallback? onAddPage;
  final VoidCallback? onExport;
  final VoidCallback? onTogglePages;
  final bool showPages;
  static const futureTools = <String, IconData>{
    'Stickers': CupertinoIcons.smiley,
    'Images': CupertinoIcons.photo,
    'Shapes': CupertinoIcons.square_on_circle,
    'Sticky notes': CupertinoIcons.doc_text,
    'Laser pointer': CupertinoIcons.sparkles,
    'Recording': CupertinoIcons.mic,
    'Ruler': CupertinoIcons.resize,
    'Equations': CupertinoIcons.function,
    'Graphing': CupertinoIcons.graph_square,
    'Code tools': CupertinoIcons.chevron_left_slash_chevron_right,
  };
  Widget planned(String name, IconData icon) => DesktopIconButton(
    tooltip: '$name — Coming later',
    icon: Icon(icon, size: 17),
    onPressed: null,
  );
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: const BoxDecoration(
      color: Color(0xff1d1d20),
      border: Border(bottom: BorderSide(color: Color(0xff2d2d32), width: 0.8)),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final tools = EditorTool.values
            .where((tool) => tool != EditorTool.hand || hasStylus)
            .toList();
        final extras = bounds.maxWidth >= 1200
            ? futureTools.entries.take(5).toList()
            : bounds.maxWidth >= 1050
                ? futureTools.entries.take(3).toList()
                : <MapEntry<String, IconData>>[];
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              top: 5,
              bottom: 5,
              child: Row(
                children: [
                  if (onTogglePages != null)
                    DesktopIconButton(
                      key: const Key('toolbar-toggle-pages'),
                      tooltip:
                          showPages ? 'Hide pages' : 'Page manager',
                      onPressed: onTogglePages,
                      icon: Icon(
                        CupertinoIcons.sidebar_left,
                        size: 18,
                        color: showPages
                            ? const Color(0xff007aff)
                            : Colors.white70,
                      ),
                    ),
                  DesktopIconButton(
                    tooltip: 'Undo',
                    onPressed: onUndo,
                    icon: const Icon(
                      CupertinoIcons.arrow_uturn_left,
                      size: 18,
                    ),
                  ),
                  DesktopIconButton(
                    tooltip: 'Redo',
                    onPressed: onRedo,
                    icon: const Icon(
                      CupertinoIcons.arrow_uturn_right,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (bounds.maxWidth - 240).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    key: const Key('centered-tools'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...tools.map(
                        (tool) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2.5,
                          ),
                          child: DesktopToolButton(
                            key: ValueKey('tool-${tool.name}'),
                            tooltip: switch (tool) {
                              EditorTool.pen => 'Draw',
                              EditorTool.highlighter => 'Highlight',
                              EditorTool.eraser => 'Erase',
                              EditorTool.select => 'Select',
                              EditorTool.text => 'Type',
                              EditorTool.hand => 'Hand',
                            },
                            avatar: Icon(switch (tool) {
                              EditorTool.pen => CupertinoIcons.pencil,
                              EditorTool.highlighter =>
                                CupertinoIcons.pencil_outline,
                              EditorTool.eraser =>
                                CupertinoIcons.pencil_slash,
                              EditorTool.select => CupertinoIcons.crop,
                              EditorTool.text =>
                                CupertinoIcons.textformat,
                              EditorTool.hand =>
                                CupertinoIcons.hand_raised,
                            }, size: 17),
                            selected: session.tool == tool,
                            onSelected: (_) => onTool(tool),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 18,
                        color: const Color(0xff383840),
                      ),
                      const SizedBox(width: 6),
                      ...extras.map(
                        (entry) => planned(entry.key, entry.value),
                      ),
                      planned('Calculator', CupertinoIcons.number),
                      DesktopPopupMenuButton<String>(
                        tooltip: 'More Tools',
                        onSelected: (_) {},
                        itemBuilder: (_) => futureTools.keys
                            .map(
                              (name) => DesktopMenuItem(
                                value: name,
                                enabled: false,
                                child: Text('$name — Coming later'),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 5,
              bottom: 5,
              child: Row(
                children: [
                  DesktopIconButton(
                    tooltip: 'Add page',
                    onPressed: onAddPage,
                    icon: const Icon(CupertinoIcons.doc_append, size: 18),
                  ),
                  DesktopIconButton(
                    tooltip: 'Document style',
                    onPressed: onStyle,
                    icon: const Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 18,
                    ),
                  ),
                  DesktopIconButton(
                    tooltip: 'Export notebook',
                    onPressed: onExport,
                    icon: const Icon(
                      CupertinoIcons.square_arrow_up,
                      size: 18,
                    ),
                  ),
                  DesktopIconButton(
                    tooltip: 'Delete selected ink',
                    onPressed: onDelete,
                    icon: const Icon(CupertinoIcons.trash, size: 18),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class FloatingToolControls extends StatefulWidget {
  const FloatingToolControls({
    super.key,
    required this.session,
    required this.note,
    required this.onSettings,
    required this.onFontSize,
    required this.onBold,
    required this.onZoom,
    required this.onDelete,
  });

  final EditorSession session;
  final Notebook note;
  final VoidCallback onSettings;
  final ValueChanged<double> onFontSize;
  final VoidCallback onBold;
  final ValueChanged<double> onZoom;
  final VoidCallback? onDelete;

  @override
  State<FloatingToolControls> createState() => FloatingToolControlsState();
}

class FloatingToolControlsState extends State<FloatingToolControls> {
  bool _isHovered = false;
  Offset dragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final note = widget.note;

    return Transform.translate(
      offset: dragOffset,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              key: const Key('context-controls'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isHovered
                    ? const Color(0xf528282c)
                    : const Color(0xee212124),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isHovered ? 0.48 : 0.32,
                    ),
                    blurRadius: _isHovered ? 20 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const Key('floating-drag-handle'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {},
                    onPanUpdate: (details) {
                      setState(() {
                        dragOffset += details.delta;
                      });
                    },
                    onDoubleTap: () {
                      setState(() {
                        dragOffset = Offset.zero;
                      });
                    },
                    child: Tooltip(
                      message: 'Drag to move · Double click to reset',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Icon(
                            Icons.drag_indicator,
                            size: 16,
                            color: _isHovered ? Colors.white54 : Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (session.tool == EditorTool.text) ...[
              Tooltip(
                message: 'Text size',
                child: const Icon(
                  CupertinoIcons.textformat_size,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Text size: ${note.fontSize.round()}',
                child: DesktopPopupButton<double>(
                  value: note.fontSize,
                  items: {12.0, 16.0, 20.0, 24.0, 32.0, note.fontSize}
                      .map(
                        (s) => DesktopMenuItem(
                          value: s,
                          child: Text(
                            '${s.round()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) widget.onFontSize(v);
                  },
                ),
              ),
              const SizedBox(width: 6),
              DesktopIconButton(
                tooltip: 'Bold text',
                isSelected: note.boldText,
                onPressed: widget.onBold,
                icon: const Icon(CupertinoIcons.bold, size: 16),
              ),
            ] else if (session.tool == EditorTool.pen ||
                session.tool == EditorTool.highlighter ||
                session.tool == EditorTool.eraser) ...[
              Tooltip(
                message: session.tool == EditorTool.eraser
                    ? 'Eraser radius: ${session.width.toStringAsFixed(1)} px'
                    : 'Stroke width: ${session.width.toStringAsFixed(1)} px',
                child: Icon(
                  session.tool == EditorTool.eraser
                      ? CupertinoIcons.circle_grid_hex
                      : CupertinoIcons.line_horizontal_3,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: Tooltip(
                  message:
                      '${session.tool == EditorTool.eraser ? "Eraser radius" : "Stroke width"}: ${session.width.toStringAsFixed(1)} px',
                  child: DesktopSlider(
                    value: session.width,
                    min: 1,
                    max: session.tool == EditorTool.eraser ? 24 : 12,
                    onChanged: (v) {
                      session.width = v;
                      widget.onSettings();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: '${session.width.toStringAsFixed(1)} px',
                child: Container(
                  width: (session.width * 1.5).clamp(4.0, 18.0),
                  height: (session.width * 1.5).clamp(4.0, 18.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: session.tool == EditorTool.eraser
                        ? Colors.white24
                        : (session.color != null
                            ? Color(session.color!)
                            : Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              if (session.tool != EditorTool.eraser) ...[
                DesktopIconButton(
                  tooltip: 'Automatic ink contrast',
                  isSelected: session.color == null,
                  onPressed: () {
                    session.color = null;
                    widget.onSettings();
                  },
                  icon: const Icon(CupertinoIcons.wand_rays, size: 16),
                ),
                const SizedBox(width: 4),
                ...[0xff151515, 0xff666666, 0xffaaaaaa, 0xfffafafa].map(
                  (color) => DesktopIconButton(
                    tooltip:
                        'Ink shade ${[0xff151515, 0xff666666, 0xffaaaaaa, 0xfffafafa].indexOf(color) + 1}',
                    onPressed: () {
                      session.color = color;
                      widget.onSettings();
                    },
                    icon: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(color),
                        border: Border.all(
                          color: session.color == color
                              ? Colors.white
                              : Colors.grey.shade600,
                          width: session.color == color ? 2.5 : 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                DesktopIconButton(
                  tooltip: 'Delete selected ink',
                  onPressed: widget.onDelete,
                  icon: const Icon(CupertinoIcons.trash, size: 16),
                ),
            ] else if (session.tool == EditorTool.select) ...[
              Tooltip(
                message: 'Select ink strokes',
                child: const Icon(
                  CupertinoIcons.crop,
                  size: 16,
                  color: Color(0xff007aff),
                ),
              ),
              const SizedBox(width: 6),
              DesktopIconButton(
                tooltip: 'Delete selected ink',
                onPressed: widget.onDelete,
                icon: const Icon(CupertinoIcons.trash, size: 16),
              ),
              DesktopIconButton(
                tooltip: 'Clear selection',
                onPressed: () {
                  session.selection.clear();
                  widget.onSettings();
                },
                icon: const Icon(CupertinoIcons.xmark_circle, size: 16),
              ),
            ] else ...[
              Tooltip(
                message: 'Hand / pan mode',
                child: const Icon(
                  CupertinoIcons.hand_raised,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
            const SizedBox(width: 14),
            Container(
              width: 1,
              height: 16,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 10),
            DesktopIconButton(
              tooltip: 'Zoom out',
              onPressed: () => widget.onZoom(0.8),
              icon: const Icon(CupertinoIcons.minus, size: 16),
            ),
            Tooltip(
              message: 'Current zoom',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(session.view.value.getMaxScaleOnAxis() * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            DesktopIconButton(
              tooltip: 'Zoom in',
              onPressed: () => widget.onZoom(1.25),
              icon: const Icon(CupertinoIcons.plus, size: 16),
            ),
            DesktopIconButton(
              tooltip: 'Reset view',
              onPressed: () => widget.onZoom(0),
              icon: const Icon(Icons.aspect_ratio, size: 16),
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
