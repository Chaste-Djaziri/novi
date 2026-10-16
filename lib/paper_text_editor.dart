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
        if (mounted && widget.controller.text == value.text)
          widget.onChanged(value.text);
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
    final style = DefaultTextStyle.of(context).style.merge(
      widget.layout.textStyle(widget.fontSize, widget.bold, widget.foreground),
    );
    final scaler = MediaQuery.textScalerOf(context);
    final sample = widget.layout.painter('M', widget.pageWidth, style, scaler);
    final baseline = sample.computeLineMetrics().first.baseline;
    sample.dispose();
    final top = (widget.layout.lineHeight(widget.fontSize) - baseline).clamp(
      0.0,
      widget.layout.lineHeight(widget.fontSize),
    );
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
        child: DesktopTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: style,
          cursorColor: widget.foreground,
          borderless: true,
          strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
          scrollPhysics: const NeverScrollableScrollPhysics(),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
