import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';

import 'desktop_ui.dart';
import 'notebook.dart';

enum LassoType { rectangular, freehand }

enum EditorTool { select, pen, highlighter, eraser, text, hand }

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
  LassoType lassoType = LassoType.rectangular;
  final Map<String, bool> lassoIncludes = {
    'Handwriting': true,
    'Images': true,
    'Shapes': true,
    'Arrows': true,
    'Text Boxes': true,
    'Equations': true,
    'Tape': true,
    'Sticky Notes': true,
  };

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

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint,
  double dashWidth,
  double dashSpace,
) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final length = math.min(dashWidth, metric.length - distance);
      final extract = metric.extractPath(distance, distance + length);
      canvas.drawPath(extract, paint);
      distance += dashWidth + dashSpace;
    }
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(3),
    );
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint, 3.5, 2.5);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DashedLassoPainter extends CustomPainter {
  const _DashedLassoPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.2);
    path.cubicTo(
      size.width * 0.5,
      size.height * 0.05,
      size.width * 0.9,
      size.height * 0.25,
      size.width * 0.85,
      size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.8,
      size.height * 0.85,
      size.width * 0.45,
      size.height * 0.95,
      size.width * 0.2,
      size.height * 0.75,
    );
    path.cubicTo(
      size.width * 0.05,
      size.height * 0.6,
      size.width * 0.08,
      size.height * 0.35,
      size.width * 0.25,
      size.height * 0.2,
    );
    path.close();
    _drawDashedPath(canvas, path, paint, 3.5, 2.5);
  }

  @override
  bool shouldRepaint(covariant _DashedLassoPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LassoArrowPainter extends CustomPainter {
  const _LassoArrowPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height + 1)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1)
      ..close();
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final strokePath = Path()
      ..moveTo(0, size.height + 1)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1);
    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _LassoArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}

Future<void> showLassoToolMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Lasso Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return LassoToolMenuDialog(
        targetRect: targetRect,
        session: session,
        onUpdate: onUpdate,
      );
    },
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutQuad),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

class LassoToolMenuDialog extends StatefulWidget {
  const LassoToolMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<LassoToolMenuDialog> createState() => _LassoToolMenuDialogState();
}

class _LassoToolMenuDialogState extends State<LassoToolMenuDialog> {
  static const includedItems = [
    'Handwriting',
    'Images',
    'Shapes',
    'Arrows',
    'Text Boxes',
    'Equations',
    'Tape',
    'Sticky Notes',
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 286.0;
    const arrowWidth = 18.0;
    const arrowHeight = 9.0;

    final buttonCenterX =
        widget.targetRect.left + (widget.targetRect.width / 2);
    final cardLeft = (buttonCenterX - (cardWidth / 2)).clamp(
      12.0,
      screenSize.width - cardWidth - 12.0,
    );
    final arrowLeft = (buttonCenterX - cardLeft - (arrowWidth / 2)).clamp(
      16.0,
      cardWidth - 16.0 - arrowWidth,
    );
    final cardTop = widget.targetRect.bottom + 6.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          left: cardLeft,
          top: cardTop,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1c1c1e),
                      borderColor: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xff1c1c1e),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 28,
                        spreadRadius: 4,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Lasso Tool',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Lasso Type',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeCard(
                              type: LassoType.rectangular,
                              title: 'Rectangular',
                              key: const Key('lasso-type-rectangular'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTypeCard(
                              type: LassoType.freehand,
                              title: 'Freehand',
                              key: const Key('lasso-type-freehand'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Included in Selection',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff242426),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 0.8,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < includedItems.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    thickness: 0.8,
                                    indent: 14,
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                _buildToggleRow(includedItems[i]),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required LassoType type,
    required String title,
    required Key key,
  }) {
    final isSelected = widget.session.lassoType == type;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          widget.session.lassoType = type;
        });
        widget.onUpdate();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 76,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff2c2c2e) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.0 : 0.6,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(26, 20),
              painter: type == LassoType.rectangular
                  ? _DashedRectPainter(
                      color: isSelected ? Colors.white : Colors.white70,
                    )
                  : _DashedLassoPainter(
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String title) {
    final value = widget.session.lassoIncludes[title] ?? true;
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.74,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              key: ValueKey('lasso-switch-$title'),
              value: value,
              activeTrackColor: const Color(0xff34c759),
              onChanged: (val) {
                setState(() {
                  widget.session.lassoIncludes[title] = val;
                });
                widget.onUpdate();
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
        : Rect.fromLTWH(
            MediaQuery.of(context).size.width / 2 - 20,
            44,
            40,
            30,
          );
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
            .where((tool) => tool != EditorTool.hand || widget.hasStylus)
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
                      tooltip:
                          widget.showPages ? 'Hide pages' : 'Page manager',
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
                    icon: const Icon(
                      CupertinoIcons.arrow_uturn_left,
                      size: 18,
                    ),
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
                        (tool) {
                          final isSelect = tool == EditorTool.select;
                          final isSelected = widget.session.tool == tool;
                          final button = DesktopToolButton(
                            tooltip: switch (tool) {
                              EditorTool.select => 'Lasso Selection (V)',
                              EditorTool.pen => 'Draw',
                              EditorTool.highlighter => 'Highlight',
                              EditorTool.eraser => 'Erase',
                              EditorTool.text => 'Type',
                              EditorTool.hand => 'Hand',
                            },
                            avatar: isSelect
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomPaint(
                                        size: const Size(15, 12),
                                        painter: _DashedRectPainter(
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
                                : Icon(switch (tool) {
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.5,
                            ),
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
                        },
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
                        itemBuilder: (_) =>
                            WorkspaceToolbar.futureTools.keys
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
                    icon: const Icon(
                      CupertinoIcons.square_arrow_up,
                      size: 18,
                    ),
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
