part of '../../../../workspace_tools.dart';

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
    final scoped =
        widget.session.hasActiveTextSelection(widget.note) ||
        widget.session.textFormatScope == TextFormatScope.textBox;
    widget.onFontSize(next);
    if (!scoped) {
      widget.note.fontSize = next;
      widget.session.fontSize = next;
    }
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
                    painter: LassoArrowPainter(
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
                    painter: LassoArrowPainter(
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
                            final selected = session.applySelectedTextStyle(
                              note,
                              {'fontFamily': name},
                            );
                            final textBox =
                                session.textFormatScope ==
                                TextFormatScope.textBox;
                            if (!selected && !textBox) {
                              session.fontFamily = name;
                              note.fontFamily = name;
                            } else if (!selected) {
                              final pageIndex = session.activeTextPage.clamp(
                                0,
                                note.pages.length - 1,
                              );
                              final page = note.pages[pageIndex];
                              final controller = session.controllerForPage(
                                pageIndex,
                                page.text,
                                serializedRanges: page.textStyles,
                              );
                              if (controller.text.isNotEmpty) {
                                controller.applyStyle(
                                  TextSelection(
                                    baseOffset: 0,
                                    extentOffset: controller.text.length,
                                  ),
                                  {'fontFamily': name},
                                );
                                page.textStyles = controller.serializedRanges;
                              }
                            }
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
                    painter: LassoArrowPainter(
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
                          final scoped =
                              widget.session.hasActiveTextSelection(
                                widget.note,
                              ) ||
                              widget.session.textFormatScope ==
                                  TextFormatScope.textBox;
                          if (widget.onBold != null && scoped) {
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
                          final next = !session.italicText;
                          final selected = session.applySelectedTextStyle(
                            note,
                            {'italic': next},
                          );
                          if (!selected &&
                              session.textFormatScope !=
                                  TextFormatScope.textBox) {
                            setState(() {
                              session.italicText = next;
                              note.italicText = next;
                            });
                          } else if (!selected) {
                            final pageIndex = session.activeTextPage.clamp(
                              0,
                              note.pages.length - 1,
                            );
                            final page = note.pages[pageIndex];
                            final controller = session.controllerForPage(
                              pageIndex,
                              page.text,
                              serializedRanges: page.textStyles,
                            );
                            if (controller.text.isNotEmpty) {
                              controller.applyStyle(
                                TextSelection(
                                  baseOffset: 0,
                                  extentOffset: controller.text.length,
                                ),
                                {'italic': next},
                              );
                              page.textStyles = controller.serializedRanges;
                            }
                          }
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
                          final next = !session.underlineText;
                          final selected = session.applySelectedTextStyle(
                            note,
                            {'underline': next},
                          );
                          if (!selected &&
                              session.textFormatScope !=
                                  TextFormatScope.textBox) {
                            setState(() {
                              session.underlineText = next;
                              note.underlineText = next;
                            });
                          } else if (!selected) {
                            final pageIndex = session.activeTextPage.clamp(
                              0,
                              note.pages.length - 1,
                            );
                            final page = note.pages[pageIndex];
                            final controller = session.controllerForPage(
                              pageIndex,
                              page.text,
                              serializedRanges: page.textStyles,
                            );
                            if (controller.text.isNotEmpty) {
                              controller.applyStyle(
                                TextSelection(
                                  baseOffset: 0,
                                  extentOffset: controller.text.length,
                                ),
                                {'underline': next},
                              );
                              page.textStyles = controller.serializedRanges;
                            }
                          }
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
                          final next = !session.strikethroughText;
                          final selected = session.applySelectedTextStyle(
                            note,
                            {'strikethrough': next},
                          );
                          if (!selected &&
                              session.textFormatScope !=
                                  TextFormatScope.textBox) {
                            setState(() {
                              session.strikethroughText = next;
                              note.strikethroughText = next;
                            });
                          } else if (!selected) {
                            final pageIndex = session.activeTextPage.clamp(
                              0,
                              note.pages.length - 1,
                            );
                            final page = note.pages[pageIndex];
                            final controller = session.controllerForPage(
                              pageIndex,
                              page.text,
                              serializedRanges: page.textStyles,
                            );
                            if (controller.text.isNotEmpty) {
                              controller.applyStyle(
                                TextSelection(
                                  baseOffset: 0,
                                  extentOffset: controller.text.length,
                                ),
                                {'strikethrough': next},
                              );
                              page.textStyles = controller.serializedRanges;
                            }
                          }
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
                    painter: LassoArrowPainter(
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
                                final color = col.toARGB32();
                                final selected = widget.session
                                    .applySelectedTextStyle(widget.note, {
                                      'color': color,
                                    });
                                final textBox = widget.session
                                    .applyTextBoxStyle(widget.note, {
                                      'color': color,
                                    });
                                if (!selected && !textBox) {
                                  setState(() {
                                    widget.session.textColor = color;
                                    widget.note.textColor = color;
                                  });
                                }
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
        final selected = widget.session.applySelectedTextStyle(widget.note, {
          'color': argb,
        });
        final textBox = widget.session.applyTextBoxStyle(widget.note, {
          'color': argb,
        });
        if (!selected && !textBox) {
          setState(() {
            widget.session.textColor = argb;
            widget.note.textColor = argb;
          });
        }
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
                    painter: LassoArrowPainter(
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
              painter: AlignmentIconPainter(
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
                    painter: LassoArrowPainter(
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
                    painter: LassoArrowPainter(
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
        final selected =
            bgColor != null &&
            widget.session.applySelectedTextStyle(widget.note, {
              'backgroundColor': bgColor,
            });
        if (!selected) {
          setState(() {
            widget.session.textBoxPreset = index;
            widget.session.textBoxBgColor = bgColor;
            widget.session.textBoxBorderColor = borderColor;
            widget.session.textBoxBorder = borderW;
            widget.note.textBoxBgColor = bgColor;
            widget.note.textBoxBorderColor = borderColor;
            widget.note.textBoxBorder = borderW;
          });
        }
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
                  painter: TextBoxStyleIconPainter(color: Colors.white60),
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
              final color = col.toARGB32();
              final selected = session.applySelectedTextStyle(widget.note, {
                'backgroundColor': color,
              });
              if (!selected) {
                setState(() {
                  session.textBoxBgColor = color;
                  widget.note.textBoxBgColor = color;
                });
              }
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
