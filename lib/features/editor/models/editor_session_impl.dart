part of '../../../workspace_tools.dart';

/// Per-document editor state. The toolbar and canvas consume this model;
/// persistence remains owned by the workspace controller.
class EditorSession {
  EditorSession(Notebook note)
    : text = TextEditingController(text: note.text),
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

  final TextEditingController text;
  final FocusNode textFocus = FocusNode();
  int activeTextPage = 0;
  final Map<int, TextEditingController> pageControllers = {};
  final Map<int, FocusNode> pageFocusNodes = {};

  TextEditingController controllerForPage(int index, String initialText) {
    if (index == 0) return text;
    return pageControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialText),
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
    'pencilReduceLatency': pencilReduceLatency,
    'pencilDrawAndHold': pencilDrawAndHold,
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
