import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class Notebook {
  Notebook({
    required this.id,
    required this.title,
    this.text = '',
    List<List<List<double>>>? strokes,
  }) : strokes = strokes ?? [];
  String id;
  String title;
  String text;
  List<List<List<double>>> strokes;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'strokes': strokes,
  };
  factory Notebook.fromJson(Map<String, dynamic> json) {
    final strokes = (json['strokes'] as List)
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
    return Notebook(
      id: json['id'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
      strokes: strokes,
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
