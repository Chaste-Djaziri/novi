part of '../../../../workspace_tools.dart';

// Extensions share the State implementation while keeping controls modular.
// ignore_for_file: invalid_use_of_protected_member

extension FloatingToolControlsWritingtoolbar on FloatingToolControlsState {
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
            if (session.writingMode == WritingMode.pencil) {
              showPenMenu(
                context,
                targetRect: _rectForKey(_pencilModeKey),
                session: session,
                onUpdate: () {
                  setState(() {});
                  widget.onSettings();
                },
              );
            } else {
              setState(() => session.writingMode = WritingMode.pencil);
              widget.onSettings();
            }
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
}
