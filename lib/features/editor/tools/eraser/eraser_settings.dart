import '../common/tool_state.dart';

class EraserSettings extends ToolState {
  EraserSettings({this.radius = 14});

  @override
  String get toolId => 'eraser';
  double radius;
  String type = 'standard';
  final Set<String> filters = {'Pen', 'Pencil', 'Highlighter', 'Tape'};

  @override
  Map<String, dynamic> toJson() => {
    'toolId': toolId,
    'radius': radius,
    'type': type,
    'filters': filters.toList()..sort(),
  };
}
