import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single coordinate system for paper rules, text baselines, wrapping and clicks.
class PaperLayout {
  const PaperLayout(this.pattern);
  final String pattern;
  double get spacing => pattern == 'Wide ruled' ? 36 : 24;
  double get edge => 8;
  double lineHeight(double fontSize) =>
      spacing * math.max(1, (fontSize * 1.2 / spacing).ceil());
  TextStyle textStyle(double fontSize, bool bold, Color color) => TextStyle(
    fontSize: fontSize,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    height: lineHeight(fontSize) / fontSize,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );
  TextPainter painter(
    String text,
    double width,
    TextStyle style,
    TextScaler scaler,
  ) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    textHeightBehavior: const TextHeightBehavior(
      applyHeightToFirstAscent: true,
      applyHeightToLastDescent: true,
    ),
  )..layout(maxWidth: math.max(1, width - edge * 2));

  /// UTF-16 split position at a visual line boundary, preserving all text.
  int splitOffset(
    String text,
    double width,
    double height,
    TextStyle style,
    TextScaler scaler,
  ) {
    final p = painter(text, width, style, scaler);
    final capacity = math.max(
      1,
      ((height - spacing) / lineHeight(style.fontSize!)).floor(),
    );
    if (p.computeLineMetrics().length <= capacity) {
      p.dispose();
      return text.length;
    }
    final position = p.getPositionForOffset(
      Offset(0, capacity * lineHeight(style.fontSize!) + 0.1),
    );
    final offset = p.getLineBoundary(position).start;
    p.dispose();
    return offset.clamp(0, text.length);
  }

  /// An empty area below text is represented by real empty rows, not a text box.
  TextEditingValue caretAt(
    TextEditingValue value,
    Offset point,
    double width,
    TextStyle style,
    TextScaler scaler,
  ) {
    final p = painter(value.text, width, style, scaler);
    final metrics = p.computeLineMetrics();
    final row = math.max(
      0,
      ((point.dy - edge) / lineHeight(style.fontSize!)).floor(),
    );
    final existingRows = math.max(1, metrics.length);
    if (row >= existingRows) {
      final result = value.text + '\n' * (row - existingRows + 1);
      p.dispose();
      return TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
    final position = p.getPositionForOffset(
      Offset(
        math.max(0, point.dx - edge),
        row * lineHeight(style.fontSize!) + lineHeight(style.fontSize!) / 2,
      ),
    );
    p.dispose();
    return value.copyWith(
      selection: TextSelection.collapsed(offset: position.offset),
      composing: TextRange.empty,
    );
  }
}
