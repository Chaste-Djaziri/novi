import 'package:flutter/material.dart';

import 'notebook.dart';

enum EditorTool { pen, highlighter, eraser, select, text, hand }

class EditorSession {
  EditorSession(Notebook note)
    : text = TextEditingController(text: note.text),
      tool = note.kind == 'Text document' ? EditorTool.text : EditorTool.pen;
  final TextEditingController text;
  final TransformationController view = TransformationController();
  final List<Notebook> undo = [];
  final List<Notebook> redo = [];
  final Set<int> selection = {};
  EditorTool tool;
  double width = 3;
  int? color;
  void dispose() {
    text.dispose();
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
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff191919),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Undo',
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo, size: 20),
                ),
                IconButton(
                  tooltip: 'Redo',
                  onPressed: onRedo,
                  icon: const Icon(Icons.redo, size: 20),
                ),
                const SizedBox(width: 16),
                ...EditorTool.values.map(
                  (tool) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: switch (tool) {
                        EditorTool.pen => 'Pen',
                        EditorTool.highlighter => 'Highlighter',
                        EditorTool.eraser => 'Stroke eraser',
                        EditorTool.select => 'Select ink',
                        EditorTool.text => 'Type',
                        EditorTool.hand => 'Hand / pan',
                      },
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: Icon(switch (tool) {
                          EditorTool.pen => Icons.draw_outlined,
                          EditorTool.highlighter => Icons.highlight_outlined,
                          EditorTool.eraser => Icons.auto_fix_normal,
                          EditorTool.select => Icons.select_all,
                          EditorTool.text => Icons.text_fields,
                          EditorTool.hand => Icons.pan_tool_outlined,
                        }, size: 18),
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
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Delete selected ink',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
                IconButton(
                  tooltip: 'Document style',
                  onPressed: onStyle,
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (session.tool == EditorTool.text) ...[
                  const Text(
                    'Text size',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<double>(
                    value: note.fontSize,
                    items: {12.0, 16.0, 20.0, 24.0, 32.0, note.fontSize}
                        .map(
                          (s) => DropdownMenuItem(
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
                        onZoom(-v);
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Bold text',
                    isSelected: note.boldText,
                    onPressed: () => onZoom(-1000),
                    icon: const Icon(Icons.format_bold, size: 18),
                  ),
                ] else if (session.tool == EditorTool.pen ||
                    session.tool == EditorTool.highlighter ||
                    session.tool == EditorTool.eraser) ...[
                  Text(
                    session.tool == EditorTool.eraser
                        ? 'Eraser radius'
                        : 'Stroke width',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  SizedBox(
                    width: 140,
                    child: Slider(
                      value: session.width,
                      min: 1,
                      max: 12,
                      divisions: 22,
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
                      child: ActionChip(
                        label: Text(session.color == null ? 'Auto ✓' : 'Auto'),
                        onPressed: () {
                          session.color = null;
                          onSettings();
                        },
                      ),
                    ),
                    ...[0xff151515, 0xff666666, 0xffaaaaaa, 0xfffafafa].map(
                      (color) => IconButton(
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
                              color: session.color == color
                                  ? Colors.white
                                  : Colors.grey,
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
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => onZoom(0.8),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Text(
                  '${(session.view.value.getMaxScaleOnAxis() * 100).round()}%',
                  style: const TextStyle(fontSize: 11),
                ),
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => onZoom(1.25),
                  icon: const Icon(Icons.add, size: 18),
                ),
                TextButton(
                  onPressed: () => onZoom(0),
                  child: const Text(
                    'Reset view',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
