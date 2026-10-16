part of '../../../../workspace_tools.dart';

// Extensions share the State implementation while keeping controls modular.
// ignore_for_file: invalid_use_of_protected_member

extension FloatingToolControlsErasertoolbar on FloatingToolControlsState {
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
                    painter: EraserIconPainter(
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
}
