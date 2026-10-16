part of '../../../../workspace_tools.dart';

// Extensions share the State implementation while keeping controls modular.
// ignore_for_file: invalid_use_of_protected_member

extension FloatingToolControlsTexttoolbar on FloatingToolControlsState {
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
}
