part of '../../../workspace_tools.dart';

/// Per-document editor state. The toolbar and canvas consume this model;
/// persistence remains owned by the workspace controller.
class EditorSession {
  EditorSession(Notebook note)
    : text = StyledTextController(
        text: note.text,
        serializedRanges: note.pages.first.textStyles,
      ),
      tool = note.kind == 'Text document' ? EditorTool.text : EditorTool.select,
      fontSize = note.fontSize,
      fontFamily = note.fontFamily,
      italicText = note.italicText,
      underlineText = note.underlineText,
      strikethroughText = note.strikethroughText,
      textColor = note.textColor,
      textAlign = note.textAlign == 'center'
          ? TextAlign.center
          : note.textAlign == 'right'
          ? TextAlign.right
          : TextAlign.left,
      lineHeight = note.lineHeight ?? 28.0,
      lineHeightAuto = note.lineHeightAuto,
      textBoxBgColor = note.textBoxBgColor,
      textBoxBorderColor = note.textBoxBorderColor,
      textBoxRadius = note.textBoxRadius,
      textBoxBorder = note.textBoxBorder,
      textBoxPadding = note.textBoxPadding,
      textBoxShadow = note.textBoxShadow {
    textFocus.addListener(() {
      if (textFocus.hasFocus) activeTextPage = 0;
    });
  }

  final StyledTextController text;
  final FocusNode textFocus = FocusNode();
  int activeTextPage = 0;
  final Map<int, StyledTextController> pageControllers = {};
  final Map<int, FocusNode> pageFocusNodes = {};

  StyledTextController controllerForPage(
    int index,
    String initialText, {
    List<Map<String, dynamic>>? serializedRanges,
  }) {
    if (index == 0) return text;
    return pageControllers.putIfAbsent(
      index,
      () => StyledTextController(
        text: initialText,
        serializedRanges: serializedRanges,
      ),
    );
  }

  FocusNode focusNodeForPage(int index) {
    if (index == 0) return textFocus;
    return pageFocusNodes.putIfAbsent(index, () {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) activeTextPage = index;
      });
      return node;
    });
  }

  final TransformationController view = TransformationController();
  final List<Notebook> undo = [];
  final List<Notebook> redo = [];
  final Set<int> selection = {};
  final Set<int> composingPages = {};
  EditorTool tool;
  EditorTool previousTool = EditorTool.select;
  double width = 3;
  double eraserRadius = 14;
  int? color;
  LassoType lassoType = LassoType.rectangular;
  final Map<String, bool> lassoIncludes = {
    'Handwriting': true,
    'Images': true,
    'Shapes': true,
    'Arrows': true,
    'Text Boxes': true,
    'Equations': true,
    'Tape': true,
    'Sticky Notes': true,
  };

  WritingMode writingMode = WritingMode.pen;
  PenType penType = PenType.fountain;
  bool penHoldForLine = true;
  bool penReduceLatency = true;
  bool penSpelling = true;
  bool penMathSuggestions = false;
  bool pencilReduceLatency = true;
  bool pencilDrawAndHold = false;
  bool shapeRequireHoldToSnap = false;
  bool shapeSnapToOtherShapes = true;
  bool shapeFillColor = true;
  bool tapeStraight = false;
  double thinWidth = 2.0;
  double mediumWidth = 4.0;
  double thickWidth = 7.0;
  int selectedWidthIndex = 0;
  EraserType eraserType = EraserType.standard;
  final Map<String, bool> eraserFilters = {
    'Pen': true,
    'Pencil': true,
    'Highlighter': true,
    'Tape': true,
  };
  bool eraserAutoDeselect = false;
  double eraserSmallRadius = 6.0;
  double eraserMediumRadius = 14.0;
  double eraserLargeRadius = 26.0;
  int selectedEraserSizeIndex = 1;

  double fontSize = 16.0;
  String fontFamily = 'Modern';
  bool italicText = false;
  bool underlineText = false;
  bool strikethroughText = false;
  int? textColor;
  TextAlign textAlign = TextAlign.left;
  double lineHeight = 28.0;
  bool lineHeightAuto = true;
  int textBoxPreset = 0;
  int? textBoxBgColor;
  int? textBoxBorderColor;
  double textBoxRadius = 0.0;
  double textBoxBorder = 0.0;
  double textBoxPadding = 10.0;
  bool textBoxShadow = false;
  bool pinTextTool = false;
  bool favoriteTextStyleSaved = false;
  TextFormatScope textFormatScope = TextFormatScope.selection;

  bool applySelectedTextStyle(Notebook note, Map<String, dynamic> patch) {
    if (textFormatScope != TextFormatScope.selection) return false;
    final pageIndex = activeTextPage.clamp(0, note.pages.length - 1);
    final page = note.pages[pageIndex];
    final controller = controllerForPage(
      pageIndex,
      page.text,
      serializedRanges: page.textStyles,
    );
    if (controller.selection.isCollapsed) return false;
    controller.applyStyle(controller.selection, patch);
    page.textStyles = controller.serializedRanges;
    return true;
  }

  bool applyTextBoxStyle(Notebook note, Map<String, dynamic> patch) {
    if (textFormatScope != TextFormatScope.textBox) return false;
    final pageIndex = activeTextPage.clamp(0, note.pages.length - 1);
    final page = note.pages[pageIndex];
    final controller = controllerForPage(
      pageIndex,
      page.text,
      serializedRanges: page.textStyles,
    );
    if (controller.text.isEmpty) return false;
    controller.applyStyle(
      TextSelection(baseOffset: 0, extentOffset: controller.text.length),
      patch,
    );
    page.textStyles = controller.serializedRanges;
    return true;
  }

  bool hasActiveTextSelection(Notebook note) {
    final pageIndex = activeTextPage.clamp(0, note.pages.length - 1);
    final page = note.pages[pageIndex];
    final controller = controllerForPage(
      pageIndex,
      page.text,
      serializedRanges: page.textStyles,
    );
    return !controller.selection.isCollapsed;
  }

  String get inkKind => tool == EditorTool.highlighter
      ? 'highlighter'
      : switch (writingMode) {
          WritingMode.pen => 'pen',
          WritingMode.pencil => 'pencil',
          WritingMode.highlighter => 'highlighter',
          WritingMode.tape => 'tape',
          WritingMode.drawShape => 'shape',
        };

  Map<String, dynamic> inkStyle({double? baseWidth}) => {
    'kind': inkKind,
    'penType': penType.name,
    'materialVersion': 1,
    'width': InkMaterial.toolWidth(inkKind, baseWidth ?? width),
    'color': color,
    'opacity': inkKind == 'highlighter'
        ? 0.35
        : inkKind == 'tape'
        ? 0.95
        : 1.0,
    'straight': tapeStraight,
    'holdForLine': penHoldForLine,
    'penReduceLatency': penReduceLatency,
    'penSpelling': penSpelling,
    'penMathSuggestions': penMathSuggestions,
    'pencilReduceLatency': pencilReduceLatency,
    'pencilDrawAndHold': pencilDrawAndHold,
    'drawAndHold': inkKind == 'pencil' ? pencilDrawAndHold : penHoldForLine,
    'requireHold': shapeRequireHoldToSnap,
    'snapToShapes': shapeSnapToOtherShapes,
    'shapeFill': shapeFillColor,
  };

  void dispose() {
    text.dispose();
    textFocus.dispose();
    for (final c in pageControllers.values) {
      c.dispose();
    }
    for (final f in pageFocusNodes.values) {
      f.dispose();
    }
    view.dispose();
  }
}
