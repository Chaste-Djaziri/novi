import 'package:flutter/foundation.dart';

/// Mutable settings owned by one editor tool rather than by the toolbar.
abstract class ToolState extends ChangeNotifier {
  String get toolId;
  Map<String, dynamic> toJson();
}

/// Shared writing settings used by pen-like tools.
class WritingToolState extends ToolState {
  WritingToolState({this.toolId = 'pen'});

  @override
  final String toolId;
  double width = 3;
  int? color;
  double opacity = 1;
  bool holdForLine = true;

  void update({double? width, int? color, double? opacity, bool? holdForLine}) {
    if (width != null) this.width = width;
    if (color != null) this.color = color;
    if (opacity != null) this.opacity = opacity;
    if (holdForLine != null) this.holdForLine = holdForLine;
    notifyListeners();
  }

  @override
  Map<String, dynamic> toJson() => {
    'toolId': toolId,
    'width': width,
    'color': color,
    'opacity': opacity,
    'holdForLine': holdForLine,
  };
}
