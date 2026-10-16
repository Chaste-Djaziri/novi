import '../common/tool_state.dart';

class HighlighterSettings extends WritingToolState {
  HighlighterSettings() : super(toolId: 'highlighter') {
    opacity = 0.35;
  }
}
