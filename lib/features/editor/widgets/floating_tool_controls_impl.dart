part of '../../../../workspace_tools.dart';

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
                painter: AlignmentIconPainter(
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
                painter: const LineHeightIconPainter(color: Colors.white),
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
                painter: TextBoxStyleIconPainter(
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
                painter: FavoriteTextIconPainter(
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
