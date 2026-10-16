part of '../../notebook.dart';

/// Local SQLite index and state persistence for the notebook library.
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

/// Encode one document or a full library backup using the v1 archive format.
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

/// Decode and validate a v1 document or library backup.
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
