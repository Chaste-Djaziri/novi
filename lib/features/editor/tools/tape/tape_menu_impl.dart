part of '../../../../workspace_tools.dart';

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
