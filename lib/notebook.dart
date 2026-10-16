import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class NotebookPage {
  NotebookPage({
    this.text = '',
    List<List<List<double>>>? strokes,
    List<Map<String, dynamic>>? inkStyles,
  }) : strokes = strokes ?? [],
       inkStyles = inkStyles ?? [];

  String text;
  List<List<List<double>>> strokes;
  List<Map<String, dynamic>> inkStyles;

  Map<String, dynamic> toJson() => {
    'text': text,
    'strokes': strokes,
    'inkStyles': inkStyles,
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
  double fontSize;
  bool boldText;
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
    'inkStyles': inkStyles,
    'fontSize': fontSize,
    'boldText': boldText,
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
      inkStyles: inkStyles,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
      boldText: json['boldText'] as bool? ?? false,
      strokes: strokes,
      pages: pages,
    );
  }

  Notebook copy() => Notebook.fromJson(
    jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>,
  );
}

class LibraryStore {
  LibraryStore(String path) : db = sqlite3.open(path) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute(
      'CREATE TABLE IF NOT EXISTS notebooks (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }
  final Database db;
  List<Notebook> load() => db
      .select('SELECT data FROM notebooks ORDER BY rowid')
      .map(
        (r) => Notebook.fromJson(
          jsonDecode(r['data'] as String) as Map<String, dynamic>,
        ),
      )
      .toList();
  void save(Notebook note) => db.execute(
    'INSERT OR REPLACE INTO notebooks (id, data) VALUES (?, ?)',
    [note.id, jsonEncode(note.toJson())],
  );
  List<String> loadOpenTabs() {
    try {
      final rows = db.select(
        "SELECT value FROM app_state WHERE key = 'open_tabs'",
      );
      if (rows.isEmpty) return [];
      final list = jsonDecode(rows.first['value'] as String) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
  void saveOpenTabs(List<String> ids) {
    try {
      db.execute(
        'INSERT OR REPLACE INTO app_state (key, value) VALUES (?, ?)',
        ['open_tabs', jsonEncode(ids)],
      );
    } catch (_) {}
  }
  void merge(List<Notebook> notes) {
    db.execute('BEGIN');
    try {
      for (final note in notes) {
        save(note);
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => db.close();
}

Uint8List encodePortable(List<Notebook> notes, {required bool backup}) {
  final bytes = utf8.encode(
    jsonEncode({
      'format': backup ? 'novibackup' : 'novi',
      'version': 1,
      'notebooks': notes.map((n) => n.toJson()).toList(),
    }),
  );
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('manifest.json', bytes.length, bytes)),
    ),
  );
}

List<Notebook> decodePortable(Uint8List bytes, {required bool backup}) {
  if (bytes.length > 50 * 1024 * 1024) {
    throw const FormatException('File exceeds 50 MB limit');
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.findFile('manifest.json');
  if (file == null || file.size > 50 * 1024 * 1024) {
    throw const FormatException('Missing or oversized manifest');
  }
  final json = jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
  if (json['version'] != 1 ||
      json['format'] != (backup ? 'novibackup' : 'novi')) {
    throw const FormatException('Unsupported document format or version');
  }
  final notes = (json['notebooks'] as List)
      .map((n) => Notebook.fromJson(n as Map<String, dynamic>))
      .toList();
  if (!backup && notes.length != 1) {
    throw const FormatException('Expected one notebook');
  }
  return notes;
}
