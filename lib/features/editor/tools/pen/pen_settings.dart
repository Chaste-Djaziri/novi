import '../common/tool_state.dart';

class PenSettings extends WritingToolState {
  PenSettings({this.penType = 'fountain'}) : super(toolId: 'pen');

  String penType;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'penType': penType,
  };
}
