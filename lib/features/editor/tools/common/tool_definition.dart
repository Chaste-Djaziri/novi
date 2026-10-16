import 'package:flutter/widgets.dart';

/// Contract used by editor tools while the legacy editor is extracted.
abstract interface class ToolDefinition {
  String get toolId;
  String get label;

  void activate();
  void deactivate();

  Widget buildToolbar(BuildContext context);
  Widget buildOptions(BuildContext context);
  Widget buildIndicator(BuildContext context, Offset position);

  void pointerDown(PointerDownEvent event);
  void pointerMove(PointerMoveEvent event);
  void pointerUp(PointerUpEvent event);

  Map<String, dynamic> serializeStyle();
  bool canErase(Map<String, dynamic> style);
  CustomPainter buildPainter();
}
