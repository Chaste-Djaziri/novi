import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'desktop_ui.dart';

import 'package:flutter/material.dart';

import 'notebook.dart';

enum EditorTool { pen, highlighter, eraser, select, text, hand }

class EditorSession {
  EditorSession(Notebook note)
    : text = TextEditingController(text: note.text),
      tool = note.kind == 'Text document' ? EditorTool.text : EditorTool.pen;
  final TextEditingController text;
  final FocusNode textFocus = FocusNode();
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
    return pageFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  final TransformationController view = TransformationController();
  final List<Notebook> undo = [];
  final List<Notebook> redo = [];
  final Set<int> selection = {};
  EditorTool tool;
  EditorTool previousTool = EditorTool.pen;
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
  static const futureTools = <String, IconData>{
    'Shapes': CupertinoIcons.square,
    'Images': CupertinoIcons.photo,
    'Stickers': CupertinoIcons.smiley,
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
    icon: Icon(icon, size: 18),
    onPressed: null,
  );
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xff202020),
      border: Border(bottom: BorderSide(color: Color(0xff383838))),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 42,
          child: LayoutBuilder(
            builder: (context, bounds) {
              final tools = EditorTool.values
                  .where((tool) => tool != EditorTool.hand || hasStylus)
                  .toList();
              final extras = bounds.maxWidth >= 1200
                  ? futureTools.entries.take(5).toList()
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
                        DesktopIconButton(
                          tooltip: 'Delete selected ink',
                          onPressed: onDelete,
                          icon: const Icon(CupertinoIcons.trash, size: 18),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (bounds.maxWidth - 230).clamp(
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
                                  horizontal: 2,
                                ),
                                child: Tooltip(
                                  message: switch (tool) {
                                    EditorTool.pen => 'Pen',
                                    EditorTool.highlighter => 'Highlighter',
                                    EditorTool.eraser => 'Stroke eraser',
                                    EditorTool.select => 'Select ink',
                                    EditorTool.text => 'Type',
                                    EditorTool.hand => 'Hand / pan',
                                  },
                                  child: DesktopToolButton(
                                    key: ValueKey('tool-${tool.name}'),
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
                                    label: Text(switch (tool) {
                                      EditorTool.pen => 'Draw',
                                      EditorTool.highlighter => 'Highlight',
                                      EditorTool.eraser => 'Erase',
                                      EditorTool.select => 'Select',
                                      EditorTool.text => 'Type',
                                      EditorTool.hand => 'Hand',
                                    }),
                                    selected: session.tool == tool,
                                    onSelected: (_) => onTool(tool),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                          icon: const Icon(
                            CupertinoIcons.doc_badge_plus,
                            size: 18,
                          ),
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
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: 52,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                key: const Key('context-controls'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff292929),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xff414141)),
                ),
                child: _settings(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _settings() => Row(
    children: [
      if (session.tool == EditorTool.text) ...[
        const Text(
          'Text size',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(width: 8),
        DesktopPopupButton<double>(
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
            if (v != null) {
              onFontSize(v);
            }
          },
        ),
        DesktopIconButton(
          tooltip: 'Bold text',
          isSelected: note.boldText,
          onPressed: onBold,
          icon: const Icon(CupertinoIcons.bold, size: 18),
        ),
      ] else if (session.tool == EditorTool.pen ||
          session.tool == EditorTool.highlighter ||
          session.tool == EditorTool.eraser) ...[
        Text(
          session.tool == EditorTool.eraser ? 'Eraser radius' : 'Stroke width',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        SizedBox(
          width: 140,
          child: DesktopSlider(
            value: session.width,
            min: 1,
            max: 12,

            onChanged: (v) {
              session.width = v;
              onSettings();
            },
          ),
        ),
        Text(
          '${session.width.toStringAsFixed(1)} px',
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(width: 18),
        if (session.tool != EditorTool.eraser) ...[
          Tooltip(
            message: 'Automatic ink contrast',
            child: DesktopButton(
              child: Text(session.color == null ? 'Auto ✓' : 'Auto'),
              onPressed: () {
                session.color = null;
                onSettings();
              },
            ),
          ),
          ...[0xff151515, 0xff666666, 0xffaaaaaa, 0xfffafafa].map(
            (color) => DesktopIconButton(
              tooltip:
                  'Ink shade ${[0xff151515, 0xff666666, 0xffaaaaaa, 0xfffafafa].indexOf(color) + 1}',
              onPressed: () {
                session.color = color;
                onSettings();
              },
              icon: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(color),
                  border: Border.all(
                    color: session.color == color ? Colors.white : Colors.grey,
                    width: session.color == color ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ] else
        Text(
          session.tool == EditorTool.select
              ? 'Drag to select ink · Drag selection to move · Delete to remove'
              : 'Drag to pan · Pinch or use zoom controls',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      const SizedBox(width: 24),
      DesktopIconButton(
        tooltip: 'Zoom out',
        onPressed: () => onZoom(0.8),
        icon: const Icon(CupertinoIcons.minus, size: 18),
      ),
      Text(
        '${(session.view.value.getMaxScaleOnAxis() * 100).round()}%',
        style: const TextStyle(fontSize: 11),
      ),
      DesktopIconButton(
        tooltip: 'Zoom in',
        onPressed: () => onZoom(1.25),
        icon: const Icon(CupertinoIcons.plus, size: 18),
      ),
      DesktopButton(
        onPressed: () => onZoom(0),
        child: const Text('Reset view', style: TextStyle(fontSize: 11)),
      ),
    ],
  );
}
