part of '../../../../workspace_tools.dart';

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
                    painter: LassoArrowPainter(
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
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        'Pen Settings',
                        () => showPenFeatureMenu(
                          context,
                          targetRect: widget.targetRect,
                          session: widget.session,
                          feature: PenFeature.settings,
                          onUpdate: widget.onUpdate,
                        ),
                      ),
                      _buildFeatureRow(
                        'Writing Aids',
                        () => showPenFeatureMenu(
                          context,
                          targetRect: widget.targetRect,
                          session: widget.session,
                          feature: PenFeature.writingAids,
                          onUpdate: widget.onUpdate,
                        ),
                      ),
                      _buildFeatureRow(
                        'Math Assist',
                        () => showPenFeatureMenu(
                          context,
                          targetRect: widget.targetRect,
                          session: widget.session,
                          feature: PenFeature.mathAssist,
                          onUpdate: widget.onUpdate,
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

  Widget _buildFeatureRow(String label, VoidCallback onTap) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(color: Color(0xff242426)),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          title: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            color: Colors.white38,
            size: 17,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
