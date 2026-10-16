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
  PenFeature? _featurePage;

  @override
  Widget build(BuildContext context) {
    if (_featurePage != null) {
      return ToolMenuPopup(
        targetRect: widget.targetRect,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.18, 0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _buildFeaturePage(_featurePage!),
        ),
      );
    }
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
                        () =>
                            setState(() => _featurePage = PenFeature.settings),
                      ),
                      _buildFeatureRow(
                        'Writing Aids',
                        () => setState(
                          () => _featurePage = PenFeature.writingAids,
                        ),
                      ),
                      _buildFeatureRow(
                        'Math Assist',
                        () => setState(
                          () => _featurePage = PenFeature.mathAssist,
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

  Widget _buildFeaturePage(PenFeature feature) {
    final title = switch (feature) {
      PenFeature.settings => 'Pen Settings',
      PenFeature.writingAids => 'Writing Aids',
      PenFeature.mathAssist => 'Math Assist',
    };
    return Padding(
      key: ValueKey(feature),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _featurePage = null),
                icon: const Icon(
                  CupertinoIcons.chevron_left,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          if (feature == PenFeature.mathAssist) ...[
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xfff8f5ec),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Text(
                '(6x − 5 + 3)(2x + 1) = 12x² + 2x − 2',
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _featureToggle(
              'Suggestions',
              widget.session.penMathSuggestions,
              (v) => widget.session.penMathSuggestions = v,
            ),
            const Text(
              'Get suggestions and solutions when you\'re working on math equations.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ] else if (feature == PenFeature.writingAids) ...[
            _featureToggle(
              'Check Spelling',
              widget.session.penSpelling,
              (v) => widget.session.penSpelling = v,
            ),
            const SizedBox(height: 12),
            const Text(
              'Recognition Language   Auto Detect',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ] else ...[
            _featureToggle(
              'Reduce Latency',
              widget.session.penReduceLatency,
              (v) => widget.session.penReduceLatency = v,
            ),
            _featureToggle(
              'Draw and Hold',
              widget.session.penHoldForLine,
              (v) => widget.session.penHoldForLine = v,
            ),
            _featureToggle('Pen Gestures', true, (_) {}),
          ],
        ],
      ),
    );
  }

  Widget _featureToggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xff2c2c2e),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile.adaptive(
          title: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          value: value,
          onChanged: (next) {
            onChanged(next);
            widget.onUpdate();
            setState(() {});
          },
          activeThumbColor: const Color(0xff34c759),
        ),
      ),
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
