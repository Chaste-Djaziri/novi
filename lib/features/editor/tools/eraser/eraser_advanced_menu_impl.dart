part of '../../../../workspace_tools.dart';

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
                                iconPainter: const PenTipPainter(),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 40,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildFilterRow(
                                title: 'Pencil',
                                iconPainter: const PencilTipPainter(),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 40,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildFilterRow(
                                title: 'Highlighter',
                                iconPainter: const HighlighterTipPainter(),
                              ),
                              Divider(
                                height: 1,
                                thickness: 0.8,
                                indent: 40,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              _buildFilterRow(
                                title: 'Tape',
                                iconPainter: const TapeStripPainter(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            widget.session.eraserFilters.updateAll(
                              (k, v) => true,
                            );
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
                        style: TextStyle(color: Colors.white38, fontSize: 11),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
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
                                padding: const EdgeInsets.only(
                                  left: 14,
                                  right: 8,
                                ),
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
                                        key: const ValueKey(
                                          'switch-auto-deselect',
                                        ),
                                        value:
                                            widget.session.eraserAutoDeselect,
                                        activeTrackColor: const Color(
                                          0xff34c759,
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            widget.session.eraserAutoDeselect =
                                                val;
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
          CustomPaint(size: const Size(16, 16), painter: iconPainter),
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
