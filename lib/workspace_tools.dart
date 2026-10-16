import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';

import 'desktop_ui.dart';
import 'library_ui.dart' show CustomColorPickerDialog;
import 'notebook.dart';
import 'ink_material.dart';
import 'features/editor/tools/common/tool_types.dart';
import 'features/editor/tools/common/writing_icon_painters.dart';

// Temporary compatibility export for callers migrating from this legacy file.
export 'features/editor/tools/common/tool_types.dart';

part 'features/editor/models/editor_session_impl.dart';
part 'features/editor/tools/pen/pen_menu_impl.dart';
part 'features/editor/tools/tape/tape_menu_impl.dart';
part 'features/editor/tools/shape/shape_menu_impl.dart';
part 'features/editor/tools/select/lasso_menu_impl.dart';
part 'features/editor/tools/eraser/eraser_type_menu_impl.dart';
part 'features/editor/tools/eraser/eraser_advanced_menu_impl.dart';

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

    final buttonCenterX = targetRect.left + (targetRect.width / 2);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
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
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
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

Future<void> showFontSizeMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  required ValueChanged<double> onFontSize,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Font Size Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FontSizeMenuDialog(
        targetRect: targetRect,
        note: note,
        session: session,
        onFontSize: onFontSize,
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

class FontSizeMenuDialog extends StatefulWidget {
  const FontSizeMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    required this.onFontSize,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final ValueChanged<double> onFontSize;
  final VoidCallback onUpdate;

  @override
  State<FontSizeMenuDialog> createState() => _FontSizeMenuDialogState();
}

class _FontSizeMenuDialogState extends State<FontSizeMenuDialog> {
  late double _size;

  @override
  void initState() {
    super.initState();
    _size = widget.note.fontSize;
  }

  void _setSize(double val) {
    final next = val.clamp(8.0, 96.0);
    setState(() => _size = next);
    widget.note.fontSize = next;
    widget.session.fontSize = next;
    widget.onFontSize(next);
    widget.onUpdate();
  }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1e1e22),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xff1e1e22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              key: const Key('font-size-value-pill'),
                              width: 44,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xff121214),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${_size.round()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.5,
                                  activeTrackColor: const Color(0xff007aff),
                                  inactiveTrackColor: Colors.white.withValues(
                                    alpha: 0.18,
                                  ),
                                  thumbColor: Colors.white,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8.5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                ),
                                child: Slider(
                                  key: const Key('font-size-slider'),
                                  value: _size.clamp(10.0, 72.0),
                                  min: 10.0,
                                  max: 72.0,
                                  onChanged: (v) => _setSize(v.roundToDouble()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xff2c2c2e),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    key: const Key('font-size-minus'),
                                    onTap: () => _setSize(_size - 2),
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(16),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.minus,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 0.8,
                                    height: 14,
                                    color: Colors.white12,
                                  ),
                                  InkWell(
                                    key: const Key('font-size-plus'),
                                    onTap: () => _setSize(_size + 2),
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(16),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.plus,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64]
                              .map((s) {
                                final isSel = _size.round() == s;
                                return GestureDetector(
                                  key: Key('font-size-$s'),
                                  onTap: () {
                                    _setSize(s.toDouble());
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? const Color(0xff007aff)
                                          : const Color(0xff2c2c2e),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$s',
                                      style: TextStyle(
                                        color: isSel
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 11,
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
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

Future<void> showFontFamilyMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Font Family Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FontFamilyMenuDialog(
        targetRect: targetRect,
        note: note,
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

class FontFamilyMenuDialog extends StatelessWidget {
  const FontFamilyMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 200.0;
    const arrowWidth = 18.0;
    const arrowHeight = 9.0;

    final buttonCenterX = targetRect.left + (targetRect.width / 2);
    final cardLeft = (buttonCenterX - (cardWidth / 2)).clamp(
      12.0,
      screenSize.width - cardWidth - 12.0,
    );
    final arrowLeft = (buttonCenterX - cardLeft - (arrowWidth / 2)).clamp(
      16.0,
      cardWidth - 16.0 - arrowWidth,
    );
    final cardTop = targetRect.bottom + 6.0;

    final families = [
      ('Modern', null),
      ('Classic', 'Georgia'),
      ('Technical', 'Courier'),
    ];

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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1e1e22),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e1e22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < families.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 0.6,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        InkWell(
                          key: Key('font-family-${families[i].$1}'),
                          onTap: () {
                            final name = families[i].$1;
                            session.fontFamily = name;
                            note.fontFamily = name;
                            onUpdate();
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    families[i].$1,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: families[i].$2,
                                    ),
                                  ),
                                ),
                                if (session.fontFamily == families[i].$1 ||
                                    (families[i].$1 == 'Technical' &&
                                        session.fontFamily == 'Monospace'))
                                  const Icon(
                                    CupertinoIcons.checkmark,
                                    size: 15,
                                    color: Color(0xff007aff),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      InkWell(
                        key: const Key('more-fonts-button'),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff2c2c2e),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'More Fonts...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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

Future<void> showTextStyleMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  VoidCallback? onBold,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Text Style Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return TextStyleMenuDialog(
        targetRect: targetRect,
        note: note,
        session: session,
        onBold: onBold,
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

class TextStyleMenuDialog extends StatefulWidget {
  const TextStyleMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    this.onBold,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final VoidCallback? onBold;
  final VoidCallback onUpdate;

  @override
  State<TextStyleMenuDialog> createState() => _TextStyleMenuDialogState();
}

class _TextStyleMenuDialogState extends State<TextStyleMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 190.0;
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

    final note = widget.note;
    final session = widget.session;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1e1e22),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e1e22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStyleItem(
                        keyName: 'style-bold',
                        isSelected: note.boldText,
                        label: 'B',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        onTap: () {
                          if (widget.onBold != null) {
                            widget.onBold!();
                          } else {
                            note.boldText = !note.boldText;
                          }
                          setState(() {});
                          widget.onUpdate();
                        },
                      ),
                      _buildStyleItem(
                        keyName: 'style-italic',
                        isSelected: session.italicText,
                        label: 'I',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'serif',
                          fontSize: 16,
                        ),
                        onTap: () {
                          setState(() {
                            session.italicText = !session.italicText;
                            note.italicText = session.italicText;
                          });
                          widget.onUpdate();
                        },
                      ),
                      _buildStyleItem(
                        keyName: 'style-underline',
                        isSelected: session.underlineText,
                        label: 'U',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        onTap: () {
                          setState(() {
                            session.underlineText = !session.underlineText;
                            note.underlineText = session.underlineText;
                          });
                          widget.onUpdate();
                        },
                      ),
                      _buildStyleItem(
                        keyName: 'style-strikethrough',
                        isSelected: session.strikethroughText,
                        label: 'S',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        onTap: () {
                          setState(() {
                            session.strikethroughText =
                                !session.strikethroughText;
                            note.strikethroughText = session.strikethroughText;
                          });
                          widget.onUpdate();
                        },
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

  Widget _buildStyleItem({
    required String keyName,
    required bool isSelected,
    required String label,
    required TextStyle style,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: Key(keyName),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.white : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: style.copyWith(
            color: isSelected ? const Color(0xff151515) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  const _DottedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addOval(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2));
    _drawDashedPath(canvas, path, paint, 3.5, 3.0);
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

Future<void> showTextColorMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Text Color Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return TextColorMenuDialog(
        targetRect: targetRect,
        note: note,
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

class TextColorMenuDialog extends StatefulWidget {
  const TextColorMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<TextColorMenuDialog> createState() => _TextColorMenuDialogState();
}

class _TextColorMenuDialogState extends State<TextColorMenuDialog> {
  int _tabIndex = 0;

  static const row1 = [
    0xffff3b30,
    0xffff9500,
    0xffffcc00,
    0xff34c759,
    0xff32ade6,
    0xff007aff,
    0xffaf52de,
    0xffff2d55,
  ];

  static const row2 = [
    0xffa8241d,
    0xff9e5714,
    0xff8e7300,
    0xff207337,
    0xff1e6a8d,
    0xff004f9e,
    0xff6c3189,
    0xff8b1853,
  ];

  static const row3 = [
    0xffffffff,
    0xffe5e5ea,
    0xff8e8e93,
    0xff3a3a3c,
    0xff000000,
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 320.0;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1a1c1e),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff1a1c1e),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xff2c2c2e),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.slider_horizontal_3,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Text Color',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff2c2c2e),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xff2c2c2e),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          children: [
                            _buildTab('Presets', 0),
                            _buildTab('Custom', 1),
                            _buildTab('History', 2),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [for (final c in row1) _buildColorCircle(c)],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [for (final c in row2) _buildColorCircle(c)],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final c in row3) ...[
                            _buildColorCircle(c),
                            const Spacer(),
                          ],
                          const Spacer(),
                          const Spacer(),
                          GestureDetector(
                            key: const Key('text-color-add-custom'),
                            onTap: () async {
                              final col = await showDialog<Color>(
                                context: context,
                                builder: (ctx) => CustomColorPickerDialog(
                                  initialColor:
                                      widget.session.textColor ?? 0xff000000,
                                ),
                              );
                              if (col != null) {
                                setState(() {
                                  widget.session.textColor = col.toARGB32();
                                  widget.note.textColor =
                                      widget.session.textColor;
                                });
                                widget.onUpdate();
                              }
                            },
                            child: CustomPaint(
                              size: const Size(28, 28),
                              painter: _DottedCirclePainter(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.plus,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        key: Key('color-tab-$label'),
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff48484a) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorCircle(int argb) {
    final isSelected =
        widget.session.textColor == argb ||
        (widget.session.textColor == null && argb == 0xff000000);
    return GestureDetector(
      key: Key('text-color-swatch-$argb'),
      onTap: () {
        setState(() {
          widget.session.textColor = argb;
          widget.note.textColor = argb;
        });
        widget.onUpdate();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: argb == 0xffffffff
              ? Border.all(color: Colors.white24, width: 0.8)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: isSelected
            ? Center(
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 14,
                  color:
                      (argb == 0xffffffff ||
                          argb == 0xffe5e5ea ||
                          argb == 0xffffcc00)
                      ? Colors.black
                      : Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}

Future<void> showTextAlignmentMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Text Alignment Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return TextAlignmentMenuDialog(
        targetRect: targetRect,
        note: note,
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

class TextAlignmentMenuDialog extends StatefulWidget {
  const TextAlignmentMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<TextAlignmentMenuDialog> createState() =>
      _TextAlignmentMenuDialogState();
}

class _TextAlignmentMenuDialogState extends State<TextAlignmentMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 156.0;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1e1e22),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e1e22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAlignButton(
                        keyName: 'align-left',
                        align: TextAlign.left,
                        tooltip: 'Left Align',
                      ),
                      _buildAlignButton(
                        keyName: 'align-center',
                        align: TextAlign.center,
                        tooltip: 'Center Align',
                      ),
                      _buildAlignButton(
                        keyName: 'align-right',
                        align: TextAlign.right,
                        tooltip: 'Right Align',
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

  Widget _buildAlignButton({
    required String keyName,
    required TextAlign align,
    required String tooltip,
  }) {
    final isSelected = widget.session.textAlign == align;
    return GestureDetector(
      key: Key(keyName),
      onTap: () {
        setState(() {
          widget.session.textAlign = align;
          widget.note.textAlign = align == TextAlign.center
              ? 'center'
              : align == TextAlign.right
              ? 'right'
              : 'left';
        });
        widget.onUpdate();
      },
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? Colors.white : Colors.transparent,
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(18, 14),
              painter: _AlignmentIconPainter(
                color: isSelected ? const Color(0xff151515) : Colors.white70,
                alignment: align,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showLineHeightMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Line Height Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return LineHeightMenuDialog(
        targetRect: targetRect,
        note: note,
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

class LineHeightMenuDialog extends StatefulWidget {
  const LineHeightMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<LineHeightMenuDialog> createState() => _LineHeightMenuDialogState();
}

class _LineHeightMenuDialogState extends State<LineHeightMenuDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 290.0;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1a1c1e),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff1a1c1e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'LINE HEIGHT',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff121214),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.session.lineHeight.round()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: const Color(0xff007aff),
                                inactiveTrackColor: const Color(0xff333336),
                                thumbColor: Colors.white,
                                overlayShape: SliderComponentShape.noOverlay,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                ),
                              ),
                              child: Slider(
                                key: const Key('line-height-slider'),
                                value: widget.session.lineHeight.clamp(
                                  16.0,
                                  64.0,
                                ),
                                min: 16.0,
                                max: 64.0,
                                onChanged: (val) {
                                  setState(() {
                                    widget.session.lineHeight = val;
                                    widget.note.lineHeight = val;
                                  });
                                  widget.onUpdate();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xff2c2c2e),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  key: const Key('line-height-minus'),
                                  onTap: () {
                                    setState(() {
                                      final val =
                                          (widget.session.lineHeight - 2).clamp(
                                            16.0,
                                            64.0,
                                          );
                                      widget.session.lineHeight = val;
                                      widget.note.lineHeight = val;
                                    });
                                    widget.onUpdate();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.minus,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 0.8,
                                  height: 14,
                                  color: Colors.white12,
                                ),
                                InkWell(
                                  key: const Key('line-height-plus'),
                                  onTap: () {
                                    setState(() {
                                      final val =
                                          (widget.session.lineHeight + 2).clamp(
                                            16.0,
                                            64.0,
                                          );
                                      widget.session.lineHeight = val;
                                      widget.note.lineHeight = val;
                                    });
                                    widget.onUpdate();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.plus,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Automatic',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Transform.scale(
                            scale: 0.74,
                            alignment: Alignment.centerRight,
                            child: CupertinoSwitch(
                              key: const Key('line-height-auto-switch'),
                              value: widget.session.lineHeightAuto,
                              activeTrackColor: const Color(0xff34c759),
                              onChanged: (val) {
                                setState(() {
                                  widget.session.lineHeightAuto = val;
                                  widget.note.lineHeightAuto = val;
                                });
                                widget.onUpdate();
                              },
                            ),
                          ),
                        ],
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

Future<void> showTextBoxStyleMenu(
  BuildContext context, {
  required Rect targetRect,
  required Notebook note,
  required EditorSession session,
  required VoidCallback onUpdate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Text Box Style Menu',
    barrierColor: Colors.transparent,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return TextBoxStyleMenuDialog(
        targetRect: targetRect,
        note: note,
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

class TextBoxStyleMenuDialog extends StatefulWidget {
  const TextBoxStyleMenuDialog({
    super.key,
    required this.targetRect,
    required this.note,
    required this.session,
    required this.onUpdate,
  });

  final Rect targetRect;
  final Notebook note;
  final EditorSession session;
  final VoidCallback onUpdate;

  @override
  State<TextBoxStyleMenuDialog> createState() => _TextBoxStyleMenuDialogState();
}

class _TextBoxStyleMenuDialogState extends State<TextBoxStyleMenuDialog> {
  int _tabIndex = 0; // 0: Presets, 1: Advanced

  static const presets = [
    (null, null, 0.0), // 0: None
    (0xff2c3238, null, 0.0), // 1: Dark slate
    (0xffa7e92f, null, 0.0), // 2: Lime green
    (0xfffcd5ce, null, 0.0), // 3: Peach
    (0xffffffff, 0xffe2e8f0, 1.0), // 4: White
    (0xffe63946, null, 0.0), // 5: Coral red
    (0xffffea00, null, 0.0), // 6: Yellow
    (0xffe9ecef, null, 0.0), // 7: Off-white
    (0xff3a506b, null, 0.0), // 8: Navy
    (0xfff8f9fa, 0xffdee2e6, 1.0), // 9: Light grey
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 330.0;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _LassoArrowPainter(
                      color: const Color(0xff1a1c1e),
                      borderColor: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff1a1c1e),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Center(
                        child: Text(
                          'Text Box Style',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Segmented Tab Control [ Presets | Advanced ]
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xff2c2c2e),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                key: const Key('tab-presets'),
                                onTap: () => setState(() => _tabIndex = 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _tabIndex == 0
                                        ? const Color(0xff48484a)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Presets',
                                    style: TextStyle(
                                      color: _tabIndex == 0
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                key: const Key('tab-advanced'),
                                onTap: () => setState(() => _tabIndex = 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _tabIndex == 1
                                        ? const Color(0xff48484a)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Advanced',
                                    style: TextStyle(
                                      color: _tabIndex == 1
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_tabIndex == 0)
                        _buildPresetsTab()
                      else
                        _buildAdvancedTab(),
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

  Widget _buildPresetsTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var i = 0; i < 5; i++) _buildPresetSwatch(i)],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var i = 5; i < 10; i++) _buildPresetSwatch(i)],
        ),
      ],
    );
  }

  Widget _buildPresetSwatch(int index) {
    final preset = presets[index];
    final isSelected = widget.session.textBoxPreset == index;
    final bgColor = preset.$1;
    final borderColor = preset.$2;
    final borderW = preset.$3;

    return GestureDetector(
      key: Key('preset-swatch-$index'),
      onTap: () {
        setState(() {
          widget.session.textBoxPreset = index;
          widget.session.textBoxBgColor = bgColor;
          widget.session.textBoxBorderColor = borderColor;
          widget.session.textBoxBorder = borderW;
          widget.note.textBoxBgColor = bgColor;
          widget.note.textBoxBorderColor = borderColor;
          widget.note.textBoxBorder = borderW;
        });
        widget.onUpdate();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 48,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor != null ? Color(bgColor) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xff007aff), width: 2.2)
              : Border.all(
                  color: borderColor != null
                      ? Color(borderColor)
                      : Colors.white.withValues(alpha: 0.18),
                  width: borderW > 0 ? borderW : 1.0,
                ),
        ),
        child: index == 0
            ? Center(
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: _TextBoxStyleIconPainter(color: Colors.white60),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildAdvancedTab() {
    final session = widget.session;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAdvancedRow(
          keyName: 'advanced-bg-color',
          label: 'Background Color',
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            size: 13,
            color: Colors.white54,
          ),
          onTap: () async {
            final col = await showDialog<Color>(
              context: context,
              builder: (ctx) => CustomColorPickerDialog(
                initialColor: session.textBoxBgColor ?? 0xff2c3238,
              ),
            );
            if (col != null) {
              setState(() {
                session.textBoxBgColor = col.toARGB32();
                widget.note.textBoxBgColor = session.textBoxBgColor;
              });
              widget.onUpdate();
            }
          },
        ),
        const SizedBox(height: 8),
        _buildAdvancedRow(
          keyName: 'advanced-border-color',
          label: 'Border Color',
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            size: 13,
            color: Colors.white54,
          ),
          onTap: () async {
            final col = await showDialog<Color>(
              context: context,
              builder: (ctx) => CustomColorPickerDialog(
                initialColor: session.textBoxBorderColor ?? 0xff505050,
              ),
            );
            if (col != null) {
              setState(() {
                session.textBoxBorderColor = col.toARGB32();
                widget.note.textBoxBorderColor = session.textBoxBorderColor;
              });
              widget.onUpdate();
            }
          },
        ),
        const SizedBox(height: 8),
        _buildStepperRow(
          minusKey: 'corner-minus',
          plusKey: 'corner-plus',
          label: '${session.textBoxRadius.round()} pt Round Corner',
          value: session.textBoxRadius,
          min: 0,
          max: 32,
          onChanged: (v) {
            setState(() {
              session.textBoxRadius = v;
              widget.note.textBoxRadius = v;
            });
            widget.onUpdate();
          },
        ),
        const SizedBox(height: 8),
        _buildAdvancedRow(
          keyName: 'advanced-shadow-row',
          label: 'Shadow',
          trailing: Transform.scale(
            scale: 0.74,
            alignment: Alignment.centerRight,
            child: CupertinoSwitch(
              key: const Key('advanced-shadow-switch'),
              value: session.textBoxShadow,
              activeTrackColor: const Color(0xff34c759),
              onChanged: (val) {
                setState(() {
                  session.textBoxShadow = val;
                  widget.note.textBoxShadow = val;
                });
                widget.onUpdate();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildStepperRow(
          minusKey: 'border-minus',
          plusKey: 'border-plus',
          label: '${session.textBoxBorder.round()} pt Border',
          value: session.textBoxBorder,
          min: 0,
          max: 10,
          onChanged: (v) {
            setState(() {
              session.textBoxBorder = v;
              widget.note.textBoxBorder = v;
            });
            widget.onUpdate();
          },
        ),
        const SizedBox(height: 8),
        _buildStepperRow(
          minusKey: 'padding-minus',
          plusKey: 'padding-plus',
          label: '${session.textBoxPadding.round()} pt Padding',
          value: session.textBoxPadding,
          min: 0,
          max: 32,
          onChanged: (v) {
            setState(() {
              session.textBoxPadding = v;
              widget.note.textBoxPadding = v;
            });
            widget.onUpdate();
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedRow({
    required String keyName,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xff222428),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required String minusKey,
    required String plusKey,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xff222428),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xff2c2c2e),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: Key(minusKey),
                  onTap: () {
                    final next = (value - (max > 10 ? 2 : 1)).clamp(min, max);
                    onChanged(next);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Icon(
                      CupertinoIcons.minus,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(width: 0.8, height: 12, color: Colors.white12),
                InkWell(
                  key: Key(plusKey),
                  onTap: () {
                    final next = (value + (max > 10 ? 2 : 1)).clamp(min, max);
                    onChanged(next);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Icon(
                      CupertinoIcons.plus,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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
                                    painter: PenTipPainter(
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
          iconPainter: PenTipPainter(
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
          iconPainter: PencilTipPainter(
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
          iconPainter: HighlighterTipPainter(
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
          iconPainter: TapeStripPainter(
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
          iconPainter: DrawShapePainter(
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
        _buildColorDot(colorValue: 0xffef4444, tooltip: 'Red ink'),
        const SizedBox(width: 6),
        _buildColorDot(colorValue: 0xff3b82f6, tooltip: 'Blue ink'),
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
                child: Icon(Icons.add, size: 13, color: Colors.white70),
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
              CustomPaint(size: const Size(17, 17), painter: iconPainter),
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
    final isSelected =
        (widget.session.width -
                [
                  widget.session.thinWidth,
                  widget.session.mediumWidth,
                  widget.session.thickWidth,
                ][index])
            .abs() <
        0.01;
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
            child: CustomPaint(
              size: const Size(24, 18),
              painter: InkSamplePainter(
                InkMaterial(
                  widget.session.inkStyle(
                    baseWidth: [
                      widget.session.thinWidth,
                      widget.session.mediumWidth,
                      widget.session.thickWidth,
                    ][index],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot({required int colorValue, required String tooltip}) {
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
        _buildEraserSizeCircle(
          0,
          6.0,
          session.eraserSmallRadius,
          'Small eraser',
        ),
        const SizedBox(width: 6),
        _buildEraserSizeCircle(
          1,
          11.0,
          session.eraserMediumRadius,
          'Medium eraser',
        ),
        const SizedBox(width: 6),
        _buildEraserSizeCircle(
          2,
          17.0,
          session.eraserLargeRadius,
          'Large eraser',
        ),
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
          widget.session.eraserRadius = radiusValue;
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
            color: isSelected ? const Color(0xff2c2c30) : Colors.transparent,
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
    final session = widget.session;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Color button ( ▾ ) (Screenshot 3)
        GestureDetector(
          key: _textColorKey,
          onTap: () {
            showTextColorMenu(
              context,
              targetRect: _rectForKey(_textColorKey),
              note: note,
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Color',
            child: Container(
              key: const Key('text-collapse-button'),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff121214),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: session.textColor != null
                        ? Color(session.textColor!)
                        : const Color(0xff000000),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 8,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 2. Font Size pill [ 24 ˅ ]
        GestureDetector(
          key: _fontSizeKey,
          onTap: () {
            showFontSizeMenu(
              context,
              targetRect: _rectForKey(_fontSizeKey),
              note: note,
              session: session,
              onFontSize: widget.onFontSize,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Font Size',
            child: Container(
              key: const Key('text-font-size-button'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xff121214),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${note.fontSize.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 11,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 3. Font Family pill [ Modern ˅ ]
        GestureDetector(
          key: _fontFamilyKey,
          onTap: () {
            showFontFamilyMenu(
              context,
              targetRect: _rectForKey(_fontFamilyKey),
              note: note,
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Font Family',
            child: Container(
              key: const Key('text-font-family-button'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xff121214),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.fontFamily,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    size: 11,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 4. Text Style button [ B I ] (Screenshot 1)
        GestureDetector(
          key: const Key('text-bold-italic-button'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            showTextStyleMenu(
              context,
              targetRect: _rectForKey(_textStyleKey),
              note: note,
              session: session,
              onBold: widget.onBold,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Text Style',
            child: Container(
              key: _textStyleKey,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (note.boldText ||
                        session.italicText ||
                        session.underlineText ||
                        session.strikethroughText)
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'B',
                    style: TextStyle(
                      color: note.boldText ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'I',
                    style: TextStyle(
                      color: session.italicText ? Colors.white : Colors.white60,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 5. Alignment button [ ≡ ]
        GestureDetector(
          key: _textAlignKey,
          onTap: () {
            showTextAlignmentMenu(
              context,
              targetRect: _rectForKey(_textAlignKey),
              note: note,
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Alignment',
            child: Container(
              key: const Key('text-alignment-button'),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                size: const Size(18, 16),
                painter: _AlignmentIconPainter(
                  color: Colors.white,
                  alignment: session.textAlign,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // 6. Line Height button [ ↕≡ ]
        GestureDetector(
          key: _lineHeightKey,
          onTap: () {
            showLineHeightMenu(
              context,
              targetRect: _rectForKey(_lineHeightKey),
              note: note,
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Line Height',
            child: Container(
              key: const Key('text-line-height-button'),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                size: const Size(18, 16),
                painter: const _LineHeightIconPainter(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 7. Divider |
        Container(
          width: 1,
          height: 18,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        const SizedBox(width: 8),

        // 8. Text Box Style button [ ⟍ ]
        GestureDetector(
          key: _textBoxStyleKey,
          onTap: () {
            showTextBoxStyleMenu(
              context,
              targetRect: _rectForKey(_textBoxStyleKey),
              note: note,
              session: session,
              onUpdate: () {
                setState(() {});
                widget.onSettings();
              },
            );
          },
          child: Tooltip(
            message: 'Text Box Style',
            child: Container(
              key: const Key('text-box-style-button'),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                size: const Size(20, 18),
                painter: _TextBoxStyleIconPainter(
                  color: Colors.white70,
                  bgColor: session.textBoxBgColor,
                  preset: session.textBoxPreset,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 9. Favorite Text Style [ T♡ ]
        GestureDetector(
          key: const Key('favorite-text-style-button'),
          onTap: () {
            setState(() {
              session.favoriteTextStyleSaved = !session.favoriteTextStyleSaved;
            });
            widget.onSettings();
          },
          child: Tooltip(
            message: session.favoriteTextStyleSaved
                ? 'Favorite style saved'
                : 'Save as favorite style',
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                size: const Size(20, 18),
                painter: _FavoriteTextIconPainter(
                  color: Colors.white70,
                  isSaved: session.favoriteTextStyleSaved,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // 10. Pin Text Tool button [ 📌 Pin Text Tool ]
        GestureDetector(
          key: const Key('pin-text-tool-button'),
          onTap: () {
            setState(() {
              session.pinTextTool = !session.pinTextTool;
            });
            widget.onSettings();
          },
          child: Tooltip(
            message: session.pinTextTool ? 'Unpin text tool' : 'Pin text tool',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: session.pinTextTool
                    ? const Color(0xff007aff)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: session.pinTextTool
                      ? const Color(0xff007aff)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.pin,
                    size: 13,
                    color: session.pinTextTool ? Colors.white : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Pin Text Tool',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
