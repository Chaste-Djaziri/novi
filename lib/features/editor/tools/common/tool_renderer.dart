import 'package:flutter/widgets.dart';

/// Rendering seam shared by tool modules and the paper canvas.
abstract interface class ToolRenderer {
  CustomPainter buildPainter({required Map<String, dynamic> style});
  CustomPainter buildIndicator({required Map<String, dynamic> style, required Offset position});
}
