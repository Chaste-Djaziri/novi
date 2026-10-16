import 'dart:async';

import 'package:flutter/material.dart';

import 'desktop_ui.dart';
import 'paper_layout.dart';

/// One page-wide editor. Blank rows are real text; no movable text boxes.
class PaperTextEditor extends StatefulWidget {
  const PaperTextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.layout,
    required this.fontSize,
    required this.bold,
    required this.foreground,
    required this.onChanged,
    required this.pageWidth,
    required this.pageHeight,
    this.fontFamily = 'Modern',
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.textAlign = TextAlign.left,
    this.lineHeight,
    this.lineHeightAuto = true,
    this.textColor,
    this.textBoxBgColor,
    this.textBoxBorderColor,
    this.textBoxRadius = 0.0,
    this.textBoxBorder = 0.0,
    this.textBoxPadding = 10.0,
    this.textBoxShadow = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final PaperLayout layout;
  final double fontSize;
  final bool bold;
  final Color foreground;
  final ValueChanged<String> onChanged;
  final double pageWidth;
  final double pageHeight;
  final String fontFamily;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final TextAlign textAlign;
  final double? lineHeight;
  final bool lineHeightAuto;
  final int? textColor;
  final int? textBoxBgColor;
  final int? textBoxBorderColor;
  final double textBoxRadius;
  final double textBoxBorder;
  final double textBoxPadding;
  final bool textBoxShadow;
  @override
  State<PaperTextEditor> createState() => _PaperTextEditorState();
}

class _PaperTextEditorState extends State<PaperTextEditor> {
  Offset? down;
  late String _previousText;
  bool _wasComposing = false;
  @override
  void initState() {
    super.initState();
    _previousText = widget.controller.text;
    widget.controller.addListener(_compositionChanged);
  }

  void _compositionChanged() {
    final value = widget.controller.value;
    final composing = value.composing.isValid && !value.composing.isCollapsed;
    final committedWithoutTextChange =
        _wasComposing && !composing && value.text == _previousText;
    _previousText = value.text;
    _wasComposing = composing;
    if (committedWithoutTextChange) {
      scheduleMicrotask(() {
        if (mounted && widget.controller.text == value.text) {
          widget.onChanged(value.text);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_compositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedFontFamily = switch (widget.fontFamily) {
      'Classic' => 'Georgia',
      'Technical' || 'Monospace' => 'Courier',
      'Handwritten' => 'Caveat',
      _ => 'Inter',
    };
    final effectiveColor = widget.textColor != null
        ? Color(widget.textColor!)
        : widget.foreground;
    var baseStyle = widget.layout.textStyle(
      widget.fontSize,
      widget.bold,
      effectiveColor,
    );
    if (widget.italic) {
      baseStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
    }
    TextDecoration? decoration;
    if (widget.underline && widget.strikethrough) {
      decoration = TextDecoration.combine([
        TextDecoration.underline,
        TextDecoration.lineThrough,
      ]);
    } else if (widget.underline) {
      decoration = TextDecoration.underline;
    } else if (widget.strikethrough) {
      decoration = TextDecoration.lineThrough;
    }
    if (decoration != null) {
      baseStyle = baseStyle.copyWith(decoration: decoration);
    }
    if (widget.fontFamily != 'Modern') {
      baseStyle = baseStyle.copyWith(fontFamily: resolvedFontFamily);
    }
    if (!widget.lineHeightAuto &&
        widget.lineHeight != null &&
        widget.fontSize > 0) {
      baseStyle = baseStyle.copyWith(
        height: widget.lineHeight! / widget.fontSize,
      );
    }
    final style = DefaultTextStyle.of(context).style.merge(baseStyle);
    final scaler = MediaQuery.textScalerOf(context);
    final sample = widget.layout.painter('M', widget.pageWidth, style, scaler);
    final baseline = sample.computeLineMetrics().first.baseline;
    sample.dispose();
    final top = (widget.layout.lineHeight(widget.fontSize) - baseline).clamp(
      0.0,
      widget.layout.lineHeight(widget.fontSize),
    );
    final hasDecoration = widget.textBoxBgColor != null ||
        (widget.textBoxBorder > 0 && widget.textBoxBorderColor != null) ||
        widget.textBoxShadow;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => down = event.localPosition,
      onPointerMove: (event) {
        if (down != null && (event.localPosition - down!).distance > 5) {
          down = null;
        }
      },
      onPointerUp: (event) {
        if (down == null) return;
        final point = Offset(
          event.localPosition.dx,
          event.localPosition.dy - top + widget.layout.edge,
        );
        down = null;
        final value = widget.layout.caretAt(
          widget.controller.value,
          point,
          widget.pageWidth,
          style,
          scaler,
        );
        if (value.text == widget.controller.text) return;
        scheduleMicrotask(() {
          if (!mounted) return;
          widget.controller.value = value;
          widget.focusNode.requestFocus();
          widget.onChanged(value.text);
        });
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.layout.edge,
          top,
          widget.layout.edge,
          widget.layout.edge,
        ),
        child: Container(
          decoration: hasDecoration
              ? BoxDecoration(
                  color: widget.textBoxBgColor != null
                      ? Color(widget.textBoxBgColor!)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(widget.textBoxRadius),
                  border: widget.textBoxBorder > 0 &&
                          widget.textBoxBorderColor != null
                      ? Border.all(
                          color: Color(widget.textBoxBorderColor!),
                          width: widget.textBoxBorder,
                        )
                      : null,
                  boxShadow: widget.textBoxShadow
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                )
              : null,
          padding: hasDecoration ? EdgeInsets.all(widget.textBoxPadding) : null,
          child: DesktopTextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            maxLines: null,
            expands: true,
            textAlign: widget.textAlign,
            textAlignVertical: TextAlignVertical.top,
            style: style,
            cursorColor: widget.foreground,
            borderless: true,
            strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
            scrollPhysics: const NeverScrollableScrollPhysics(),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
