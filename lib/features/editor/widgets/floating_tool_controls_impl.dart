part of '../../../../workspace_tools.dart';

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
    this.onClearPage,
    this.onRemoveAllTape,
    this.onOpenCustomColor,
  });

  final EditorSession session;
  final Notebook note;
  final VoidCallback onSettings;
  final ValueChanged<double> onFontSize;
  final VoidCallback onBold;
  final ValueChanged<double> onZoom;
  final VoidCallback? onDelete;
  final VoidCallback? onClearPage;
  final VoidCallback? onRemoveAllTape;
  final VoidCallback? onOpenCustomColor;

  @override
  State<FloatingToolControls> createState() => FloatingToolControlsState();
}

class FloatingToolControlsState extends State<FloatingToolControls> {
  bool _isHovered = false;
  Offset dragOffset = Offset.zero;

  final GlobalKey _penModeKey = GlobalKey();
  final GlobalKey _pencilModeKey = GlobalKey();
  final GlobalKey _highlighterModeKey = GlobalKey();
  final GlobalKey _tapeModeKey = GlobalKey();
  final GlobalKey _shapeModeKey = GlobalKey();
  final GlobalKey _colorDropdownKey = GlobalKey();
  final GlobalKey _eraserTypeKey = GlobalKey();
  final GlobalKey _eraserOptionsKey = GlobalKey();
  final GlobalKey _textColorKey = GlobalKey();
  final GlobalKey _fontSizeKey = GlobalKey();
  final GlobalKey _fontFamilyKey = GlobalKey();
  final GlobalKey _textStyleKey = GlobalKey();
  final GlobalKey _textAlignKey = GlobalKey();
  final GlobalKey _lineHeightKey = GlobalKey();
  final GlobalKey _textBoxStyleKey = GlobalKey();

  Rect _rectForKey(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return Rect.fromLTWH(
      MediaQuery.of(context).size.width / 2 - 20,
      80,
      40,
      30,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final note = widget.note;

    if (session.tool == EditorTool.select) {
      return const SizedBox.shrink();
    }

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
                    ? const Color(0xf5242427)
                    : const Color(0xee1c1c1f),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isHovered ? 0.52 : 0.38,
                    ),
                    blurRadius: _isHovered ? 24 : 14,
                    offset: const Offset(0, 5),
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
                  if (session.tool == EditorTool.pen ||
                      session.tool == EditorTool.highlighter) ...[
                    _buildWritingToolbar(context),
                  ] else if (session.tool == EditorTool.eraser) ...[
                    _buildEraserToolbar(context),
                  ] else if (session.tool == EditorTool.shapes) ...[
                    _buildShapesToolbar(),
                  ] else if (session.tool == EditorTool.text) ...[
                    _buildTextToolbar(note),
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
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 8),
                  _buildZoomControls(session),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
