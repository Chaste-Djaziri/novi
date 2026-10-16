import '../common/tool_state.dart';

class TapeSettings extends WritingToolState {
  TapeSettings() : super(toolId: 'tape') {
    opacity = 0.95;
  }

  bool straight = false;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'straight': straight,
  };
}
