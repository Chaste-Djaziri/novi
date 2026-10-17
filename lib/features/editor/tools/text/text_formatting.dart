import 'package:flutter/material.dart';

class TextStyleRange {
  TextStyleRange({
    required this.start,
    required this.end,
    Map<String, dynamic>? style,
  }) : style = style ?? {};

  int start;
  int end;
  final Map<String, dynamic> style;

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'style': style,
  };

  factory TextStyleRange.fromJson(Map<String, dynamic> json) =>
      TextStyleRange(
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 0,
        style: Map<String, dynamic>.from(json['style'] as Map? ?? const {}),
      );
}

class StyledTextController extends TextEditingController {
  StyledTextController({
    super.text,
    List<Map<String, dynamic>>? serializedRanges,
  }) : ranges = [
         for (final value in serializedRanges ?? const [])
           TextStyleRange.fromJson(value),
       ] {
    addListener(_adjustRangesAfterTextChange);
    _previousText = text;
  }

  final List<TextStyleRange> ranges;
  TextStyle? baseStyle;
  String _previousText = '';
  bool _adjusting = false;

  List<Map<String, dynamic>> get serializedRanges => [
    for (final range in ranges) range.toJson(),
  ];

  void applyStyle(
    TextSelection selection,
    Map<String, dynamic> patch,
  ) {
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start == end) return;
    final next = <TextStyleRange>[];
    for (final range in ranges) {
      if (range.end <= start || range.start >= end) {
        next.add(range);
        continue;
      }
      if (range.start < start) {
        next.add(
          TextStyleRange(
            start: range.start,
            end: start,
            style: Map<String, dynamic>.from(range.style),
          ),
        );
      }
      if (range.end > end) {
        next.add(
          TextStyleRange(
            start: end,
            end: range.end,
            style: Map<String, dynamic>.from(range.style),
          ),
        );
      }
    }
    next.add(
      TextStyleRange(
        start: start,
        end: end,
        style: Map<String, dynamic>.from(patch),
      ),
    );
    ranges
      ..clear()
      ..addAll(_mergeRanges(next));
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fallback = baseStyle ?? style ?? const TextStyle();
    if (text.isEmpty || ranges.isEmpty) {
      return TextSpan(style: fallback, text: text);
    }
    final boundaries = <int>{0, text.length};
    for (final range in ranges) {
      boundaries
        ..add(range.start.clamp(0, text.length))
        ..add(range.end.clamp(0, text.length));
    }
    final sorted = boundaries.toList()..sort();
    final children = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start == end) continue;
      final merged = <String, dynamic>{};
      for (final range in ranges) {
        if (range.start <= start && range.end >= end) {
          merged.addAll(range.style);
        }
      }
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: fallback.merge(_toTextStyle(merged)),
        ),
      );
    }
    return TextSpan(style: fallback, children: children);
  }

  TextStyle _toTextStyle(Map<String, dynamic> values) {
    final decorations = <TextDecoration>[];
    if (values['underline'] == true) decorations.add(TextDecoration.underline);
    if (values['strikethrough'] == true) {
      decorations.add(TextDecoration.lineThrough);
    }
    return TextStyle(
      fontSize: (values['fontSize'] as num?)?.toDouble(),
      fontFamily: values['fontFamily'] as String?,
      fontWeight: values['bold'] == true ? FontWeight.bold : null,
      fontStyle: values['italic'] == true ? FontStyle.italic : null,
      color: values['color'] is int ? Color(values['color'] as int) : null,
      backgroundColor: values['backgroundColor'] is int
          ? Color(values['backgroundColor'] as int)
          : null,
      decoration: decorations.isEmpty
          ? null
          : TextDecoration.combine(decorations),
    );
  }

  void _adjustRangesAfterTextChange() {
    if (_adjusting) return;
    final current = text;
    if (current == _previousText) return;
    var prefix = 0;
    while (prefix < _previousText.length &&
        prefix < current.length &&
        _previousText.codeUnitAt(prefix) == current.codeUnitAt(prefix)) {
      prefix++;
    }
    var oldSuffix = _previousText.length;
    var newSuffix = current.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        _previousText.codeUnitAt(oldSuffix - 1) ==
            current.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }
    final delta = (newSuffix - prefix) - (oldSuffix - prefix);
    for (final range in ranges) {
      if (range.start >= oldSuffix) {
        range.start += delta;
        range.end += delta;
      } else if (range.end > prefix) {
        range.end = (range.end + delta).clamp(prefix, current.length);
      }
    }
    ranges.removeWhere((range) => range.start >= range.end);
    _previousText = current;
  }

  List<TextStyleRange> _mergeRanges(List<TextStyleRange> source) {
    final sorted = [...source]
      ..sort((a, b) => a.start == b.start
          ? a.end.compareTo(b.end)
          : a.start.compareTo(b.start));
    final merged = <TextStyleRange>[];
    for (final range in sorted) {
      if (range.start >= range.end) continue;
      if (merged.isNotEmpty &&
          merged.last.end == range.start &&
          _mapsEqual(merged.last.style, range.style)) {
        merged.last.end = range.end;
      } else {
        merged.add(range);
      }
    }
    return merged;
  }

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    removeListener(_adjustRangesAfterTextChange);
    super.dispose();
  }
}
