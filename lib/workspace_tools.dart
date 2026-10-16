import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSwitch;
import 'package:flutter/material.dart';

import 'desktop_ui.dart';
import 'library_ui.dart' show CustomColorPickerDialog;
import 'notebook.dart';
import 'ink_material.dart';
import 'features/editor/tools/common/tool_types.dart';
import 'features/editor/tools/common/writing_icon_painters.dart';
import 'features/editor/tools/common/editor_icon_painters.dart';
import 'features/editor/widgets/tool_menu_popup.dart';

// Temporary compatibility export for callers migrating from this legacy file.
export 'features/editor/tools/common/tool_types.dart';

part 'features/editor/models/editor_session_impl.dart';
part 'features/editor/tools/pen/pen_menu_impl.dart';
part 'features/editor/tools/pencil/pencil_menu_impl.dart';
part 'features/editor/tools/tape/tape_menu_impl.dart';
part 'features/editor/tools/shape/shape_menu_impl.dart';
part 'features/editor/tools/select/lasso_menu_impl.dart';
part 'features/editor/tools/eraser/eraser_type_menu_impl.dart';
part 'features/editor/tools/eraser/eraser_advanced_menu_impl.dart';
part 'features/editor/tools/text/text_popovers_impl.dart';
part 'features/editor/widgets/color_palette_menu_impl.dart';
part 'features/editor/widgets/editor_toolbar_impl.dart';
part 'features/editor/widgets/floating_tool_controls_impl.dart';
part 'features/editor/widgets/writing_controls_impl.dart';
part 'features/editor/widgets/eraser_controls_impl.dart';
part 'features/editor/widgets/text_controls_impl.dart';
part 'features/editor/widgets/zoom_controls_impl.dart';

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint,
  double dashWidth,
  double dashSpace,
) {
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final length = math.min(dashWidth, metric.length - distance);
      final extract = metric.extractPath(distance, distance + length);
      canvas.drawPath(extract, paint);
      distance += dashWidth + dashSpace;
    }
  }
}
