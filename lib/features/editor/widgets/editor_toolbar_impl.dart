part of '../../../../workspace_tools.dart';

class WorkspaceToolbar extends StatefulWidget {
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

  @override
  State<WorkspaceToolbar> createState() => _WorkspaceToolbarState();
}

class _WorkspaceToolbarState extends State<WorkspaceToolbar> {
  final GlobalKey _selectKey = GlobalKey();

  Widget planned(String name, IconData icon) => DesktopIconButton(
    tooltip: '$name — Coming later',
    icon: Icon(icon, size: 17),
    onPressed: null,
  );

  void _showLassoMenu(BuildContext context) {
    final box = _selectKey.currentContext?.findRenderObject() as RenderBox?;
    final rect = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero) & box.size)
        : Rect.fromLTWH(MediaQuery.of(context).size.width / 2 - 20, 44, 40, 30);
    showLassoToolMenu(
      context,
      targetRect: rect,
      session: widget.session,
      onUpdate: widget.onSettings,
    );
  }

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
            .where(
              (tool) =>
                  tool != EditorTool.highlighter &&
                  (tool != EditorTool.hand || widget.hasStylus),
            )
            .toList();
        final extras = bounds.maxWidth >= 1200
            ? WorkspaceToolbar.futureTools.entries.take(5).toList()
            : bounds.maxWidth >= 1050
            ? WorkspaceToolbar.futureTools.entries.take(3).toList()
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
                  if (widget.onTogglePages != null)
                    DesktopIconButton(
                      key: const Key('toolbar-toggle-pages'),
                      tooltip: widget.showPages ? 'Hide pages' : 'Page manager',
                      onPressed: widget.onTogglePages,
                      icon: Icon(
                        CupertinoIcons.sidebar_left,
                        size: 18,
                        color: widget.showPages
                            ? const Color(0xff007aff)
                            : Colors.white70,
                      ),
                    ),
                  DesktopIconButton(
                    tooltip: 'Undo',
                    onPressed: widget.onUndo,
                    icon: const Icon(CupertinoIcons.arrow_uturn_left, size: 18),
                  ),
                  DesktopIconButton(
                    tooltip: 'Redo',
                    onPressed: widget.onRedo,
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
                  maxWidth: (bounds.maxWidth - 240).clamp(0, double.infinity),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    key: const Key('centered-tools'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...tools.map((tool) {
                        final isSelect = tool == EditorTool.select;
                        final isSelected = widget.session.tool == tool;
                        final button = DesktopToolButton(
                          tooltip: switch (tool) {
                            EditorTool.select => 'Lasso Selection (V)',
                            EditorTool.pen => 'Writing (W)',
                            EditorTool.highlighter => 'Highlight',
                            EditorTool.eraser => 'Erase',
                            EditorTool.shapes => 'Shapes',
                            EditorTool.text => 'Type',
                            EditorTool.hand => 'Hand',
                          },
                          avatar: isSelect
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomPaint(
                                      size: const Size(15, 12),
                                      painter: DashedRectPainter(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 11,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ],
                                )
                              : switch (tool) {
                                  EditorTool.pen => CustomPaint(
                                    size: const Size(16, 16),
                                    painter: PenTipPainter(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white70,
                                    ),
                                  ),
                                  EditorTool.eraser => CustomPaint(
                                    size: const Size(16, 16),
                                    painter: EraserIconPainter(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white70,
                                    ),
                                  ),
                                  EditorTool.shapes => Icon(
                                    CupertinoIcons.square_on_circle,
                                    size: 17,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  EditorTool.text => Icon(
                                    CupertinoIcons.textbox,
                                    size: 17,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  EditorTool.hand => Icon(
                                    CupertinoIcons.hand_raised,
                                    size: 17,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  _ => Icon(
                                    CupertinoIcons.pencil,
                                    size: 17,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                },
                          selected: isSelected,
                          onSelected: (_) {
                            if (isSelect &&
                                widget.session.tool == EditorTool.select) {
                              _showLassoMenu(context);
                            } else {
                              widget.onTool(tool);
                            }
                          },
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                          child: isSelect
                              ? KeyedSubtree(
                                  key: const ValueKey('tool-select'),
                                  child: KeyedSubtree(
                                    key: _selectKey,
                                    child: button,
                                  ),
                                )
                              : KeyedSubtree(
                                  key: ValueKey('tool-${tool.name}'),
                                  child: button,
                                ),
                        );
                      }),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 18,
                        color: const Color(0xff383840),
                      ),
                      const SizedBox(width: 6),
                      ...extras.map((entry) => planned(entry.key, entry.value)),
                      planned('Calculator', CupertinoIcons.number),
                      DesktopPopupMenuButton<String>(
                        tooltip: 'More Tools',
                        onSelected: (_) {},
                        itemBuilder: (_) => WorkspaceToolbar.futureTools.keys
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
                    onPressed: widget.onAddPage,
                    icon: const Icon(CupertinoIcons.doc_append, size: 18),
                  ),
                  DesktopIconButton(
                    tooltip: 'Document style',
                    onPressed: widget.onStyle,
                    icon: const Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 18,
                    ),
                  ),
                  DesktopIconButton(
                    tooltip: 'Export notebook',
                    onPressed: widget.onExport,
                    icon: const Icon(CupertinoIcons.square_arrow_up, size: 18),
                  ),
                  DesktopIconButton(
                    tooltip: 'Delete selected ink',
                    onPressed: widget.onDelete,
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
