import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

part 'core/persistence/notebook_store.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class NotebookPage {
  NotebookPage({
    this.text = '',
    List<List<List<double>>>? strokes,
    List<Map<String, dynamic>>? inkStyles,
    this.isBookmarked = false,
  }) : strokes = strokes ?? [],
       inkStyles = inkStyles ?? [];

  String text;
  List<List<List<double>>> strokes;
  List<Map<String, dynamic>> inkStyles;
  bool isBookmarked;

  Map<String, dynamic> toJson() => {
    'text': text,
    'strokes': strokes,
    'inkStyles': inkStyles,
    if (isBookmarked) 'isBookmarked': true,
  };

  factory NotebookPage.fromJson(Map<String, dynamic> json) {
    final strokes = (json['strokes'] as List? ?? [])
        .map(
          (s) => (s as List).map((p) {
            final values = (p as List)
                .map((n) => (n as num).toDouble())
                .toList();
            if (values.length != 3 || values.any((n) => !n.isFinite)) {
              throw const FormatException('Invalid stroke');
            }
            return values;
          }).toList(),
        )
        .toList();
    return NotebookPage(
      text: json['text'] as String? ?? '',
      inkStyles: (json['inkStyles'] as List? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList(),
      strokes: strokes,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
    );
  }

  NotebookPage copy() => NotebookPage.fromJson(
    jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
  );
}

class Notebook {
  Notebook({
    required this.id,
    required this.title,
    String text = '',
    this.kind = 'Notebook',
    this.paper = 'Blank',
    this.tone = 'White',
    this.cover = 0xff303030,
    this.coverImage,
    this.landscape = false,
    this.favorite = false,
    List<Map<String, dynamic>>? inkStyles,
    this.fontSize = 16,
    this.boldText = false,
    this.fontFamily = 'Modern',
    this.italicText = false,
    this.underlineText = false,
    this.strikethroughText = false,
    this.textAlign = 'left',
    this.lineHeight,
    this.lineHeightAuto = true,
    this.textColor,
    this.textBoxBgColor,
    this.textBoxBorderColor,
    this.textBoxRadius = 0.0,
    this.textBoxBorder = 0.0,
    this.textBoxPadding = 10.0,
    this.textBoxShadow = false,
    this.coverBookmarked = false,
    List<List<List<double>>>? strokes,
    List<NotebookPage>? pages,
  }) : _pages = pages ?? [
         NotebookPage(
           text: text,
           strokes: strokes ?? [],
           inkStyles: inkStyles ?? [],
         ),
       ];

  String id;
  String title;
  String kind;
  String paper;
  String tone;
  int cover;
  String? coverImage;
  bool landscape;
  bool favorite;
  bool coverBookmarked;
  double fontSize;
  bool boldText;
  String fontFamily;
  bool italicText;
  bool underlineText;
  bool strikethroughText;
  String textAlign;
  double? lineHeight;
  bool lineHeightAuto;
  int? textColor;
  int? textBoxBgColor;
  int? textBoxBorderColor;
  double textBoxRadius;
  double textBoxBorder;
  double textBoxPadding;
  bool textBoxShadow;
  List<NotebookPage>? _pages;

  List<NotebookPage> get pages {
    if (_pages == null || _pages!.isEmpty) {
      _pages = [NotebookPage()];
    }
    return _pages!;
  }

  set pages(List<NotebookPage> value) {
    _pages = value;
  }

  String get text => pages.isNotEmpty ? pages.first.text : '';
  set text(String value) {
    if (pages.isEmpty) pages.add(NotebookPage());
    pages.first.text = value;
  }

  List<List<List<double>>> get strokes =>
      pages.isNotEmpty ? pages.first.strokes : [];
  set strokes(List<List<List<double>>> value) {
    if (pages.isEmpty) pages.add(NotebookPage());
    pages.first.strokes = value;
  }

  List<Map<String, dynamic>> get inkStyles =>
      pages.isNotEmpty ? pages.first.inkStyles : [];
  set inkStyles(List<Map<String, dynamic>> value) {
    if (pages.isEmpty) pages.add(NotebookPage());
    pages.first.inkStyles = value;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'kind': kind,
    'paper': paper,
    'tone': tone,
    'cover': cover,
    'coverImage': coverImage,
    'landscape': landscape,
    'favorite': favorite,
    if (coverBookmarked) 'coverBookmarked': true,
    'inkStyles': inkStyles,
    'fontSize': fontSize,
    'boldText': boldText,
    if (fontFamily != 'Modern') 'fontFamily': fontFamily,
    if (italicText) 'italicText': true,
    if (underlineText) 'underlineText': true,
    if (strikethroughText) 'strikethroughText': true,
    if (textAlign != 'left') 'textAlign': textAlign,
    if (lineHeight != null) 'lineHeight': lineHeight,
    if (!lineHeightAuto) 'lineHeightAuto': false,
    if (textColor != null) 'textColor': textColor,
    if (textBoxBgColor != null) 'textBoxBgColor': textBoxBgColor,
    if (textBoxBorderColor != null) 'textBoxBorderColor': textBoxBorderColor,
    if (textBoxRadius > 0) 'textBoxRadius': textBoxRadius,
    if (textBoxBorder > 0) 'textBoxBorder': textBoxBorder,
    if (textBoxPadding != 10.0) 'textBoxPadding': textBoxPadding,
    if (textBoxShadow) 'textBoxShadow': true,
    'strokes': strokes,
    'pages': pages.map((p) => p.toJson()).toList(),
  };

  factory Notebook.fromJson(Map<String, dynamic> json) {
    final strokes = (json['strokes'] as List? ?? [])
        .map(
          (s) => (s as List).map((p) {
            final values = (p as List)
                .map((n) => (n as num).toDouble())
                .toList();
            if (values.length != 3 || values.any((n) => !n.isFinite)) {
              throw const FormatException('Invalid stroke');
            }
            return values;
          }).toList(),
        )
        .toList();
    final text = json['text'] as String? ?? '';
    final inkStyles = (json['inkStyles'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final pagesJson = json['pages'] as List?;
    final pages = pagesJson != null && pagesJson.isNotEmpty
        ? pagesJson
            .map((p) => NotebookPage.fromJson(p as Map<String, dynamic>))
            .toList()
        : [NotebookPage(text: text, strokes: strokes, inkStyles: inkStyles)];

    return Notebook(
      id: json['id'] as String,
      title: json['title'] as String,
      text: text,
      kind: json['kind'] as String? ?? 'Notebook',
      paper: json['paper'] as String? ?? 'Blank',
      tone: json['tone'] as String? ?? 'White',
      cover: json['cover'] as int? ?? 0xff303030,
      coverImage: json['coverImage'] as String?,
      landscape: json['landscape'] as bool? ?? false,
      favorite: json['favorite'] as bool? ?? false,
      coverBookmarked: json['coverBookmarked'] as bool? ?? false,
      inkStyles: inkStyles,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      boldText: json['boldText'] as bool? ?? false,
      fontFamily: json['fontFamily'] as String? ?? 'Modern',
      italicText: json['italicText'] as bool? ?? false,
      underlineText: json['underlineText'] as bool? ?? false,
      strikethroughText: json['strikethroughText'] as bool? ?? false,
      textAlign: json['textAlign'] as String? ?? 'left',
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
      lineHeightAuto: json['lineHeightAuto'] as bool? ?? true,
      textColor: json['textColor'] as int?,
      textBoxBgColor: json['textBoxBgColor'] as int?,
      textBoxBorderColor: json['textBoxBorderColor'] as int?,
      textBoxRadius: (json['textBoxRadius'] as num?)?.toDouble() ?? 0.0,
      textBoxBorder: (json['textBoxBorder'] as num?)?.toDouble() ?? 0.0,
      textBoxPadding: (json['textBoxPadding'] as num?)?.toDouble() ?? 10.0,
      textBoxShadow: json['textBoxShadow'] as bool? ?? false,
      strokes: strokes,
      pages: pages,
    );
  }

  Notebook copy() => Notebook.fromJson(
    jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
  );
}

