import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';

import 'desktop_ui.dart';
import 'notebook.dart';

enum LassoType { rectangular, freehand }

enum WritingMode { pen, pencil, highlighter, tape, drawShape }

enum PenType { fountain, ballpoint, brush }

enum EraserType { precision, standard, stroke }

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

  // Writing Mode and Options
  WritingMode writingMode = WritingMode.pen;
  PenType penType = PenType.fountain;
  bool penHoldForLine = true;

  // Draw Shape settings
  bool shapeRequireHoldToSnap = false;
  bool shapeSnapToOtherShapes = true;
  bool shapeFillColor = true;

  // Tape settings
  bool tapeStraight = false;

  // Width Presets
  double thinWidth = 2.0;
  double mediumWidth = 4.0;
  double thickWidth = 7.0;
  int selectedWidthIndex = 0;

  // Eraser Settings & Presets
  EraserType eraserType = EraserType.standard;
  final Map<String, bool> eraserFilters = {
    'Pen': true,
    'Pencil': true,
    'Highlighter': true,
    'Tape': true,
  };
  bool eraserAutoDeselect = false;
  double eraserSmallRadius = 6.0;
  double eraserMediumRadius = 14.0;
  double eraserLargeRadius = 26.0;
  int selectedEraserSizeIndex = 1;

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

class _EraserIconPainter extends CustomPainter {
  const _EraserIconPainter({this.color = Colors.white, this.accentColor});
  final Color color;
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-size.width / 2, -size.height / 2);

    final w = size.width * 0.58;
    final h = size.height * 0.9;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4.5));

    if (accentColor != null) {
      final topRect = Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        rect.top + h * 0.45,
      );
      final topRRect = RRect.fromRectAndCorners(
        topRect,
        topLeft: const Radius.circular(4.5),
        topRight: const Radius.circular(4.5),
      );
      canvas.drawRRect(
        topRRect,
        Paint()
          ..color = accentColor!
          ..style = PaintingStyle.fill,
      );
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(rrect, strokePaint);

    final lineY = rect.top + h * 0.45;
    canvas.drawLine(
      Offset(rect.left, lineY),
      Offset(rect.right, lineY),
      strokePaint..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}

class _PenTipPainter extends CustomPainter {
  const _PenTipPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.75, size.height * 0.15);
    path.lineTo(size.width * 0.35, size.height * 0.6);
    path.lineTo(size.width * 0.25, size.height * 0.8);
    path.lineTo(size.width * 0.45, size.height * 0.7);
    path.lineTo(size.width * 0.85, size.height * 0.25);
    path.close();
    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.8),
      Offset(size.width * 0.45, size.height * 0.55),
      paint..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.9),
      Offset(size.width * 0.5, size.height * 0.9),
      paint..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _PenTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PencilTipPainter extends CustomPainter {
  const _PencilTipPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.75, size.height * 0.1);
    path.lineTo(size.width * 0.88, size.height * 0.23);
    path.lineTo(size.width * 0.4, size.height * 0.75);
    path.lineTo(size.width * 0.2, size.height * 0.82);
    path.lineTo(size.width * 0.27, size.height * 0.62);
    path.close();
    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.36, size.height * 0.66),
      Offset(size.width * 0.45, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PencilTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HighlighterTipPainter extends CustomPainter {
  const _HighlighterTipPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.35);
    path.lineTo(size.width * 0.55, size.height * 0.1);
    path.lineTo(size.width * 0.8, size.height * 0.35);
    path.lineTo(size.width * 0.55, size.height * 0.6);
    path.close();
    canvas.drawPath(path, paint);

    final nib = Path();
    nib.moveTo(size.width * 0.3, size.height * 0.35);
    nib.lineTo(size.width * 0.18, size.height * 0.65);
    nib.lineTo(size.width * 0.32, size.height * 0.8);
    nib.lineTo(size.width * 0.55, size.height * 0.6);
    canvas.drawPath(nib, paint);

    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.88),
      Offset(size.width * 0.85, size.height * 0.88),
      paint..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlighterTipPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TapeStripPainter extends CustomPainter {
  const _TapeStripPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.4);
    path.lineTo(size.width * 0.22, size.height * 0.3);
    path.lineTo(size.width * 0.15, size.height * 0.2);
    path.lineTo(size.width * 0.22, size.height * 0.1);
    path.lineTo(size.width * 0.85, size.height * 0.6);
    path.lineTo(size.width * 0.78, size.height * 0.7);
    path.lineTo(size.width * 0.85, size.height * 0.8);
    path.lineTo(size.width * 0.78, size.height * 0.9);
    path.lineTo(size.width * 0.15, size.height * 0.4);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TapeStripPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DrawShapePainter extends CustomPainter {
  const _DrawShapePainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.38),
      size.width * 0.22,
      paint,
    );

    final rect = Rect.fromLTWH(
      size.width * 0.44,
      size.height * 0.18,
      size.width * 0.38,
      size.height * 0.38,
    );
    canvas.drawRect(rect, paint);

    final tri = Path();
    tri.moveTo(size.width * 0.5, size.height * 0.54);
    tri.lineTo(size.width * 0.78, size.height * 0.9);
    tri.lineTo(size.width * 0.22, size.height * 0.9);
    tri.close();
    canvas.drawPath(tri, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawShapePainter oldDelegate) =>
      oldDelegate.color != color;
}

Future<void> showDrawShapeMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Draw Shape Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return DrawShapeMenuDialog(
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

class DrawShapeMenuDialog extends StatefulWidget {
  const DrawShapeMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<DrawShapeMenuDialog> createState() => _DrawShapeMenuDialogState();
}

class _DrawShapeMenuDialogState extends State<DrawShapeMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 280.0;
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
                          'Draw Shape',
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
                        'Settings',
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
                          child: _buildToggle(
                            'Require Hold to Snap',
                            widget.session.shapeRequireHoldToSnap,
                            (val) {
                              setState(() {
                                widget.session.shapeRequireHoldToSnap = val;
                              });
                              widget.onUpdate();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Advanced Options',
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
                              _buildToggle(
                                'Snap to Other Shapes',
                                widget.session.shapeSnapToOtherShapes,
                                (val) {
                                  setState(() {
                                    widget.session.shapeSnapToOtherShapes = val;
                                  });
                                  widget.onUpdate();
                                },
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 14,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildToggle(
                                'Fill Color',
                                widget.session.shapeFillColor,
                                (val) {
                                  setState(() {
                                    widget.session.shapeFillColor = val;
                                  });
                                  widget.onUpdate();
                                },
                              ),
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

  Widget _buildToggle(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 8),
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
              key: ValueKey('switch-$title'),
              value: value,
              activeTrackColor: const Color(0xff34c759),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTapeMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
  VoidCallback? onRemoveAllTape,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Tape Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return TapeMenuDialog(
        targetRect: targetRect,
        session: session,
        onUpdate: onUpdate,
        onRemoveAllTape: onRemoveAllTape,
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

class TapeMenuDialog extends StatefulWidget {
  const TapeMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
    this.onRemoveAllTape,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;
  final VoidCallback? onRemoveAllTape;

  @override
  State<TapeMenuDialog> createState() => _TapeMenuDialogState();
}

class _TapeMenuDialogState extends State<TapeMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 280.0;
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
                          'Tape',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xff242426),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'hide  ',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'content',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'hide  ',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    width: 58,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xff242426),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Straight Tape',
                                style: TextStyle(
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
                                key: const ValueKey('switch-straight-tape'),
                                value: widget.session.tapeStraight,
                                activeTrackColor: const Color(0xff34c759),
                                onChanged: (val) {
                                  setState(() {
                                    widget.session.tapeStraight = val;
                                  });
                                  widget.onUpdate();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          key: const Key('remove-all-tape-button'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (widget.onRemoveAllTape != null) {
                              widget.onRemoveAllTape!();
                            }
                          },
                          child: const Text(
                            'Remove All Tape',
                            style: TextStyle(
                              color: Color(0xffff453a),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
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
}

Future<void> showPenMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Pen Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return PenMenuDialog(
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

class PenMenuDialog extends StatefulWidget {
  const PenMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<PenMenuDialog> createState() => _PenMenuDialogState();
}

class _PenMenuDialogState extends State<PenMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 280.0;
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
                          'Pen',
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
                        'Pen Type',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildPenTypeCard('Fountain', PenType.fountain),
                          const SizedBox(width: 8),
                          _buildPenTypeCard('Ballpoint', PenType.ballpoint),
                          const SizedBox(width: 8),
                          _buildPenTypeCard('Brush', PenType.brush),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xff242426),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Draw and Hold for Line',
                                style: TextStyle(
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
                                key: const ValueKey('switch-hold-for-line'),
                                value: widget.session.penHoldForLine,
                                activeTrackColor: const Color(0xff34c759),
                                onChanged: (val) {
                                  setState(() {
                                    widget.session.penHoldForLine = val;
                                  });
                                  widget.onUpdate();
                                },
                              ),
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
      ],
    );
  }

  Widget _buildPenTypeCard(String label, PenType type) {
    final isSelected = widget.session.penType == type;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            widget.session.penType = type;
          });
          widget.onUpdate();
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff2c2c2e) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == PenType.fountain
                    ? CupertinoIcons.pencil
                    : type == PenType.ballpoint
                        ? CupertinoIcons.pencil_outline
                        : CupertinoIcons.paintbrush,
                size: 20,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showColorPaletteMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
  VoidCallback? onOpenCustomColor,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Color Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return ColorPaletteMenuDialog(
        targetRect: targetRect,
        session: session,
        onUpdate: onUpdate,
        onOpenCustomColor: onOpenCustomColor,
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

class ColorPaletteMenuDialog extends StatelessWidget {
  const ColorPaletteMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
    this.onOpenCustomColor,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;
  final VoidCallback? onOpenCustomColor;

  static const defaultColors = [
    0xff151515,
    0xff475569,
    0xff94a3b8,
    0xffef4444,
    0xfff97316,
    0xffeab308,
    0xff22c55e,
    0xff14b8a6,
    0xff3b82f6,
    0xff6366f1,
    0xffa855f7,
    0xffec4899,
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 240.0;
    const arrowWidth = 18.0;
    const arrowHeight = 9.0;

    final buttonCenterX =
        targetRect.left + (targetRect.width / 2);
    final cardLeft = (buttonCenterX - (cardWidth / 2)).clamp(
      12.0,
      screenSize.width - cardWidth - 12.0,
    );
    final arrowLeft = (buttonCenterX - cardLeft - (arrowWidth / 2)).clamp(
      16.0,
      cardWidth - 16.0 - arrowWidth,
    );
    final cardTop = targetRect.bottom + 6.0;

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
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Ink Color',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: defaultColors.map((colorValue) {
                          final isSelected = session.color == colorValue;
                          return GestureDetector(
                            onTap: () {
                              session.color = colorValue;
                              onUpdate();
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(colorValue),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (onOpenCustomColor != null) {
                              onOpenCustomColor!();
                            }
                          },
                          icon: const Icon(
                            Icons.colorize,
                            size: 14,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'Custom Color...',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
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
}

Future<void> showEraserTypeMenu(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Eraser Type Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return EraserTypeMenuDialog(
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

class EraserTypeMenuDialog extends StatefulWidget {
  const EraserTypeMenuDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<EraserTypeMenuDialog> createState() => _EraserTypeMenuDialogState();
}

class _EraserTypeMenuDialogState extends State<EraserTypeMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 310.0;
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
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Eraser Type',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeCard(
                              title: 'Precision\nEraser',
                              type: EraserType.precision,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTypeCard(
                              title: 'Standard\nEraser',
                              type: EraserType.standard,
                              isBlueAccent: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTypeCard(
                              title: 'Stroke\nEraser',
                              type: EraserType.stroke,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.session.eraserType == EraserType.precision
                            ? 'Precise erasing of exact touched pixels'
                            : widget.session.eraserType == EraserType.standard
                                ? 'Efficient erasing without leaving any marks'
                                : 'Erases the entire stroke upon touch',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
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
    required String title,
    required EraserType type,
    bool isBlueAccent = false,
  }) {
    final isSelected = widget.session.eraserType == type;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          widget.session.eraserType = type;
        });
        widget.onUpdate();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 88,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff2c2c2e) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.0 : 0.6,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(20, 20),
              painter: _EraserIconPainter(
                color: isSelected ? Colors.white : Colors.white60,
                accentColor: isBlueAccent ? const Color(0xff007aff) : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11.5,
                height: 1.2,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showEraserAdvancedSettings(
  BuildContext context, {
  required Rect targetRect,
  required EditorSession session,
  required VoidCallback onUpdate,
  VoidCallback? onClearPage,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Eraser Settings',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return EraserAdvancedSettingsDialog(
        targetRect: targetRect,
        session: session,
        onUpdate: onUpdate,
        onClearPage: onClearPage,
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

class EraserAdvancedSettingsDialog extends StatefulWidget {
  const EraserAdvancedSettingsDialog({
    super.key,
    required this.targetRect,
    required this.session,
    required this.onUpdate,
    this.onClearPage,
  });

  final Rect targetRect;
  final EditorSession session;
  final VoidCallback onUpdate;
  final VoidCallback? onClearPage;

  @override
  State<EraserAdvancedSettingsDialog> createState() =>
      _EraserAdvancedSettingsDialogState();
}

class _EraserAdvancedSettingsDialogState
    extends State<EraserAdvancedSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 280.0;
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
                          'Advanced Settings',
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
                        'ERASER FILTER',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                              _buildFilterRow(
                                title: 'Pen',
                                iconPainter: const _PenTipPainter(),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 40,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildFilterRow(
                                title: 'Pencil',
                                iconPainter: const _PencilTipPainter(),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 40,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildFilterRow(
                                title: 'Highlighter',
                                iconPainter: const _HighlighterTipPainter(),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 40,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildFilterRow(
                                title: 'Tape',
                                iconPainter: const _TapeStripPainter(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            widget.session.eraserFilters.updateAll((k, v) => true);
                          });
                          widget.onUpdate();
                        },
                        child: const Text(
                          'Select all',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "The eraser ignores marks from any tool that's turned off.",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: TextButton(
                                  key: const Key('eraser-clear-page-button'),
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    if (widget.onClearPage != null) {
                                      widget.onClearPage!();
                                    }
                                  },
                                  child: const Text(
                                    'Clear Page',
                                    style: TextStyle(
                                      color: Color(0xffff453a),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 14,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              Container(
                                height: 44,
                                padding: const EdgeInsets.only(left: 14, right: 8),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Auto-Deselect',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.74,
                                      alignment: Alignment.centerRight,
                                      child: CupertinoSwitch(
                                        key: const ValueKey('switch-auto-deselect'),
                                        value: widget.session.eraserAutoDeselect,
                                        activeTrackColor: const Color(0xff34c759),
                                        onChanged: (val) {
                                          setState(() {
                                            widget.session.eraserAutoDeselect = val;
                                          });
                                          widget.onUpdate();
                                        },
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow({
    required String title,
    required CustomPainter iconPainter,
  }) {
    final value = widget.session.eraserFilters[title] ?? true;
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(16, 16),
            painter: iconPainter,
          ),
          const SizedBox(width: 10),
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
              key: ValueKey('eraser-filter-$title'),
              value: value,
              activeTrackColor: const Color(0xff34c759),
              onChanged: (val) {
                setState(() {
                  widget.session.eraserFilters[title] = val;
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
            .where((tool) =>
                tool != EditorTool.highlighter &&
                (tool != EditorTool.hand || widget.hasStylus))
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
                              EditorTool.pen => 'Writing (W)',
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
                                : switch (tool) {
                                    EditorTool.pen => CustomPaint(
                                        size: const Size(16, 16),
                                        painter: _PenTipPainter(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.white70,
                                        ),
                                      ),
                                    EditorTool.eraser => CustomPaint(
                                        size: const Size(16, 16),
                                        painter: _EraserIconPainter(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.white70,
                                        ),
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

  Widget _buildWritingToolbar(BuildContext context) {
    final session = widget.session;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 5 Writing modes
        _buildModeItem(
          key: _penModeKey,
          mode: WritingMode.pen,
          tooltip: 'Pen',
          iconPainter: _PenTipPainter(
            color: session.writingMode == WritingMode.pen
                ? Colors.black
                : Colors.white70,
          ),
          onTap: () {
            if (session.writingMode == WritingMode.pen) {
              showPenMenu(
                context,
                targetRect: _rectForKey(_penModeKey),
                session: session,
                onUpdate: () {
                  setState(() {});
                  widget.onSettings();
                },
              );
            } else {
              setState(() => session.writingMode = WritingMode.pen);
              widget.onSettings();
            }
          },
        ),
        const SizedBox(width: 4),
        _buildModeItem(
          key: _pencilModeKey,
          mode: WritingMode.pencil,
          tooltip: 'Pencil',
          iconPainter: _PencilTipPainter(
            color: session.writingMode == WritingMode.pencil
                ? Colors.black
                : Colors.white70,
          ),
          onTap: () {
            setState(() => session.writingMode = WritingMode.pencil);
            widget.onSettings();
          },
        ),
        const SizedBox(width: 4),
        _buildModeItem(
          key: _highlighterModeKey,
          mode: WritingMode.highlighter,
          tooltip: 'Highlighter',
          iconPainter: _HighlighterTipPainter(
            color: session.writingMode == WritingMode.highlighter
                ? Colors.black
                : Colors.white70,
          ),
          onTap: () {
            setState(() => session.writingMode = WritingMode.highlighter);
            widget.onSettings();
          },
        ),
        const SizedBox(width: 4),
        _buildModeItem(
          key: _tapeModeKey,
          mode: WritingMode.tape,
          tooltip: 'Tape (A)',
          iconPainter: _TapeStripPainter(
            color: session.writingMode == WritingMode.tape
                ? Colors.black
                : Colors.white70,
          ),
          onTap: () {
            if (session.writingMode == WritingMode.tape) {
              showTapeMenu(
                context,
                targetRect: _rectForKey(_tapeModeKey),
                session: session,
                onUpdate: () {
                  setState(() {});
                  widget.onSettings();
                },
                onRemoveAllTape: widget.onRemoveAllTape,
              );
            } else {
              setState(() => session.writingMode = WritingMode.tape);
              widget.onSettings();
            }
          },
        ),
        const SizedBox(width: 4),
        _buildModeItem(
          key: _shapeModeKey,
          mode: WritingMode.drawShape,
          tooltip: 'Draw Shape (D)',
          iconPainter: _DrawShapePainter(
            color: session.writingMode == WritingMode.drawShape
                ? Colors.black
                : Colors.white70,
          ),
          onTap: () {
            if (session.writingMode == WritingMode.drawShape) {
              showDrawShapeMenu(
                context,
                targetRect: _rectForKey(_shapeModeKey),
                session: session,
                onUpdate: () {
                  setState(() {});
                  widget.onSettings();
                },
              );
            } else {
              setState(() => session.writingMode = WritingMode.drawShape);
              widget.onSettings();
            }
          },
        ),
        const SizedBox(width: 10),
        Container(
          width: 1,
          height: 16,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(width: 10),

        // 3 Width Presets: Thin, Medium, Thick
        _buildWidthPreset(0, 14, 2.0, 'Thin stroke (2px)'),
        const SizedBox(width: 5),
        _buildWidthPreset(1, 18, 3.5, 'Medium stroke (4px)'),
        const SizedBox(width: 5),
        _buildWidthPreset(2, 22, 5.5, 'Thick stroke (7px)'),

        const SizedBox(width: 10),
        Container(
          width: 1,
          height: 16,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(width: 10),

        // Color Presets: Red, Blue, Active Dropdown, Custom Picker (+)
        _buildColorDot(
          colorValue: 0xffef4444,
          tooltip: 'Red ink',
        ),
        const SizedBox(width: 6),
        _buildColorDot(
          colorValue: 0xff3b82f6,
          tooltip: 'Blue ink',
        ),
        const SizedBox(width: 6),
        GestureDetector(
          key: _colorDropdownKey,
          onTap: () {
            showColorPaletteMenu(
              context,
              targetRect: _rectForKey(_colorDropdownKey),
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
              onOpenCustomColor: widget.onOpenCustomColor,
            );
          },
          child: Tooltip(
            message: 'Select ink color',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xff2a2a2d),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: session.color != null
                          ? Color(session.color!)
                          : const Color(0xff151515),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 11,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: 'Custom color...',
          child: GestureDetector(
            onTap: widget.onOpenCustomColor,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.0,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add,
                  size: 13,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeItem({
    required GlobalKey key,
    required WritingMode mode,
    required String tooltip,
    required CustomPainter iconPainter,
    required VoidCallback onTap,
  }) {
    final isSelected = widget.session.writingMode == mode;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 8 : 6,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff3f8a96) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(17, 17),
                painter: iconPainter,
              ),
              if (isSelected) ...[
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 12,
                  color: Colors.black,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidthPreset(
    int index,
    double lineLength,
    double strokeHeight,
    String tooltip,
  ) {
    final isSelected = widget.session.selectedWidthIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.session.selectedWidthIndex = index;
          widget.session.width = [
            widget.session.thinWidth,
            widget.session.mediumWidth,
            widget.session.thickWidth,
          ][index];
        });
        widget.onSettings();
      },
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 30,
          height: 26,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff353538) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Container(
              width: lineLength,
              height: strokeHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(strokeHeight / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot({
    required int colorValue,
    required String tooltip,
  }) {
    final isSelected = widget.session.color == colorValue;
    return GestureDetector(
      onTap: () {
        setState(() => widget.session.color = colorValue);
        widget.onSettings();
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(colorValue),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              width: isSelected ? 2.0 : 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEraserToolbar(BuildContext context) {
    final session = widget.session;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eraser Type pill button with dropdown chevron
        GestureDetector(
          key: _eraserTypeKey,
          onTap: () {
            showEraserTypeMenu(
              context,
              targetRect: _rectForKey(_eraserTypeKey),
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Eraser Type',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xff2c2c2f),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(16, 16),
                    painter: _EraserIconPainter(
                      color: Colors.white,
                      accentColor: session.eraserType == EraserType.standard
                          ? const Color(0xff007aff)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    session.eraserType == EraserType.precision
                        ? 'Precision'
                        : session.eraserType == EraserType.standard
                            ? 'Standard'
                            : 'Stroke',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 12,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Tool Options sliders icon
        GestureDetector(
          key: _eraserOptionsKey,
          onTap: () {
            showEraserAdvancedSettings(
              context,
              targetRect: _rectForKey(_eraserOptionsKey),
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
              onClearPage: widget.onClearPage,
            );
          },
          child: Tooltip(
            message: 'Tool Options',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 17,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 3 Eraser Size dots: Small, Medium, Large
        _buildEraserSizeCircle(0, 6.0, session.eraserSmallRadius, 'Small eraser'),
        const SizedBox(width: 6),
        _buildEraserSizeCircle(1, 11.0, session.eraserMediumRadius, 'Medium eraser'),
        const SizedBox(width: 6),
        _buildEraserSizeCircle(2, 17.0, session.eraserLargeRadius, 'Large eraser'),
      ],
    );
  }

  Widget _buildEraserSizeCircle(
    int index,
    double dotSize,
    double radiusValue,
    String tooltip,
  ) {
    final isSelected = widget.session.selectedEraserSizeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.session.selectedEraserSizeIndex = index;
          widget.session.width = radiusValue;
        });
        widget.onSettings();
      },
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? const Color(0xff2c2c30)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? const Color(0xff007aff)
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2.0 : 0.8,
            ),
          ),
          child: Center(
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextToolbar(Notebook note) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Tooltip(
          message: 'Text size',
          child: Icon(
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
      ],
    );
  }

  Widget _buildZoomControls(EditorSession session) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
  }
}
