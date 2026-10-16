part of '../../../../workspace_tools.dart';

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
                              for (
                                int i = 0;
                                i < includedItems.length;
                                i++
                              ) ...[
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

/* class _PenTipPainter extends CustomPainter {
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
} */

class _LineHeightIconPainter extends CustomPainter {
  const _LineHeightIconPainter({this.color = Colors.white});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Vertical double arrow on the left
    final arrowX = size.width * 0.28;
    canvas.drawLine(
      Offset(arrowX, size.height * 0.2),
      Offset(arrowX, size.height * 0.8),
      paint,
    );
    // Top arrow head
    canvas.drawLine(
      Offset(arrowX - 2.5, size.height * 0.35),
      Offset(arrowX, size.height * 0.2),
      paint,
    );
    canvas.drawLine(
      Offset(arrowX + 2.5, size.height * 0.35),
      Offset(arrowX, size.height * 0.2),
      paint,
    );
    // Bottom arrow head
    canvas.drawLine(
      Offset(arrowX - 2.5, size.height * 0.65),
      Offset(arrowX, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(arrowX + 2.5, size.height * 0.65),
      Offset(arrowX, size.height * 0.8),
      paint,
    );

    // Horizontal bars on the right
    final lineStartX = size.width * 0.52;
    final lineEndX = size.width * 0.88;
    canvas.drawLine(
      Offset(lineStartX, size.height * 0.3),
      Offset(lineEndX, size.height * 0.3),
      paint,
    );
    canvas.drawLine(
      Offset(lineStartX, size.height * 0.5),
      Offset(lineEndX, size.height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(lineStartX, size.height * 0.7),
      Offset(lineEndX, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LineHeightIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TextBoxStyleIconPainter extends CustomPainter {
  const _TextBoxStyleIconPainter({
    this.color = Colors.white,
    this.bgColor,
    this.preset = 0,
  });
  final Color color;
  final int? bgColor;
  final int preset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));

    if (preset > 0 && bgColor != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Color(bgColor!)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      // Diagonal slash box (No fill / default)
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(rrect, paint);
      canvas.drawLine(
        Offset(rect.left + 2, rect.top + 2),
        Offset(rect.right - 2, rect.bottom - 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TextBoxStyleIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bgColor != bgColor ||
      oldDelegate.preset != preset;
}

class _FavoriteTextIconPainter extends CustomPainter {
  const _FavoriteTextIconPainter({
    this.color = Colors.white,
    this.isSaved = false,
  });
  final Color color;
  final bool isSaved;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(rrect, paint);

    // Letter 'T'
    final tPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final cx = size.width * 0.44;
    final cy = size.height * 0.52;
    canvas.drawLine(
      Offset(cx - 3.5, cy - 3.5),
      Offset(cx + 3.5, cy - 3.5),
      tPaint,
    );
    canvas.drawLine(Offset(cx, cy - 3.5), Offset(cx, cy + 4.5), tPaint);

    // Heart badge at top right
    final hx = size.width * 0.78;
    final hy = size.height * 0.28;
    final heartPath = Path();
    heartPath.moveTo(hx, hy);
    heartPath.cubicTo(hx - 2, hy - 2.5, hx - 3.5, hy, hx, hy + 3.5);
    heartPath.cubicTo(hx + 3.5, hy, hx + 2, hy - 2.5, hx, hy);
    heartPath.close();

    canvas.drawPath(
      heartPath,
      Paint()
        ..color = isSaved ? const Color(0xffff375f) : color
        ..style = isSaved ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _FavoriteTextIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSaved != isSaved;
}

class _AlignmentIconPainter extends CustomPainter {
  const _AlignmentIconPainter({
    this.color = Colors.white,
    this.alignment = TextAlign.left,
  });
  final Color color;
  final TextAlign alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final widths = [
      size.width * 0.8,
      size.width * 0.55,
      size.width * 0.8,
      size.width * 0.45,
    ];
    final ys = [
      size.height * 0.22,
      size.height * 0.41,
      size.height * 0.60,
      size.height * 0.79,
    ];

    for (var i = 0; i < 4; i++) {
      final w = widths[i];
      final y = ys[i];
      double startX;
      if (alignment == TextAlign.center) {
        startX = (size.width - w) / 2;
      } else if (alignment == TextAlign.right) {
        startX = size.width - w - 2;
      } else {
        startX = 2;
      }
      canvas.drawLine(Offset(startX, y), Offset(startX + w, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AlignmentIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.alignment != alignment;
}
