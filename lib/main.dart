import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'notebook.dart';
import 'library_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoviApp());
}

class NoviApp extends StatelessWidget {
  const NoviApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Novi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff090909),
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Color(0xffbbbbbb),
        surface: Color(0xff1c1c1c),
        onSurface: Color(0xffeeeeee),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff242424),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: const Color(0xff333333),
      useMaterial3: true,
    ),
    home: const Workspace(),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  LibraryStore? store;
  List<Notebook> notes = [];
  Notebook? current;
  final text = TextEditingController();
  final undo = <Notebook>[];
  final redo = <Notebook>[];
  List<List<double>>? activeStroke;
  int? activePointer;
  bool drawing = true;
  bool inLibrary = true;
  String status = 'Opening local library…';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final opened = LibraryStore('${directory.path}/novi.sqlite');
      if (!mounted) {
        opened.close();
        return;
      }
      try {
        notes = opened.load();
      } catch (_) {
        opened.close();
        rethrow;
      }
      store = opened;
      if (notes.isNotEmpty) {
        select(notes.first);
      }
      setState(() {
        status = 'Saved locally';
        inLibrary = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Could not open library: $e');
      }
    }
  }

  void select(Notebook note) {
    setState(() {
      current = note;
      inLibrary = false;
      drawing = note.kind != 'Text document';
      text.text = note.text;
      undo.clear();
      redo.clear();
      activeStroke = null;
      activePointer = null;
    });
  }

  void snapshot() {
    undo.add(current!.copy());
    if (undo.length > 100) {
      undo.removeAt(0);
    }
    redo.clear();
  }

  void save() {
    try {
      store!.save(current!);
      status = 'Saved locally';
    } catch (e) {
      status = 'Save failed — keep Novi open: $e';
    }
  }

  Future<void> create() async {
    final note = await showDialog<Notebook>(
      context: context,
      builder: (_) => const CreateDocumentDialog(),
    );
    if (note == null || !mounted) {
      return;
    }
    try {
      store!.save(note);
      notes.add(note);
      select(note);
      setState(() => status = 'Saved locally');
    } catch (e) {
      setState(() => status = 'Could not create document: $e');
    }
  }

  Future<void> styleDocument() async {
    final changed = await showDialog<Notebook>(
      context: context,
      builder: (_) => CreateDocumentDialog(existing: current),
    );
    if (changed == null || !mounted) {
      return;
    }
    snapshot();
    notes[notes.indexWhere((n) => n.id == changed.id)] = changed;
    setState(() {
      current = changed;
      save();
    });
  }

  void toggleFavorite(Notebook note) {
    final changed = note.copy()..favorite = !note.favorite;
    try {
      store!.save(changed);
      setState(() {
        notes[notes.indexWhere((n) => n.id == note.id)] = changed;
        if (current?.id == note.id) {
          current = changed;
        }
      });
    } catch (e) {
      setState(() => status = 'Could not save favorite: $e');
    }
  }

  void history(bool backwards) {
    final source = backwards ? undo : redo;
    final target = backwards ? redo : undo;
    if (source.isEmpty) {
      return;
    }
    target.add(current!.copy());
    final restored = source.removeLast();
    notes[notes.indexWhere((n) => n.id == restored.id)] = restored;
    setState(() {
      current = restored;
      text.text = restored.text;
      save();
    });
  }

  Future<void> transfer(String action) async {
    final backup = action == 'backup' || action == 'restore';
    final importing = action == 'import' || action == 'restore';
    final extension = backup ? 'novibackup' : 'novi';
    try {
      if (importing) {
        final file = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: extension, extensions: [extension]),
          ],
        );
        if (file == null) {
          return;
        }
        final imported = decodePortable(
          await file.readAsBytes(),
          backup: backup,
        );
        // Restore adds copies, preserving all existing local work.
        for (var i = 0; i < imported.length; i++) {
          imported[i].id = '${newId()}-$i';
        }
        store!.merge(imported);
        if (!mounted) {
          return;
        }
        notes.addAll(imported);
        if (imported.isNotEmpty) {
          select(imported.first);
        }
        setState(
          () => status = '${imported.length} notebook(s) imported as copies',
        );
      } else {
        final destination = await getSaveLocation(
          suggestedName: backup
              ? 'Novi-library.$extension'
              : 'Notebook.$extension',
          acceptedTypeGroups: [
            XTypeGroup(label: extension, extensions: [extension]),
          ],
        );
        if (destination == null) {
          return;
        }
        final bytes = encodePortable(
          backup ? notes : [current!],
          backup: backup,
        );
        await File(destination.path).writeAsBytes(bytes, flush: true);
        if (mounted) {
          setState(
            () =>
                status = backup ? 'Library backup saved' : 'Notebook exported',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => status = 'File operation failed: $e');
      }
    }
  }

  @override
  void dispose() {
    text.dispose();
    store?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: inLibrary || current == null
        ? LibraryView(
            notes: notes,
            enabled: store != null,
            onCreate: create,
            onOpen: select,
            onFavorite: toggleFavorite,
            onTransfer: transfer,
          )
        : editor(),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xff262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      child: Text(
        '$status  ·  Offline · No account required',
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
    ),
  );

  Widget editor() {
    final note = current!;
    final darkPaper = note.tone == 'Dark';
    final foreground = darkPaper ? Colors.white : const Color(0xff222222);
    return Column(
      children: [
        Container(
          color: const Color(0xff151515),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to documents',
                onPressed: () => setState(() => inLibrary = true),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 12),
              const Wordmark(),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  note.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Document style',
                onPressed: styleDocument,
                icon: const Icon(Icons.tune),
              ),
              PopupMenuButton<String>(
                tooltip: 'Import, export and backup',
                onSelected: transfer,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'export',
                    child: Text('Export notebook'),
                  ),
                  PopupMenuItem(
                    value: 'backup',
                    child: Text('Back up library'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Text(
                '${note.kind} / ${note.paper}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.draw_outlined),
                    label: Text('Draw'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.text_fields),
                    label: Text('Type'),
                  ),
                ],
                selected: {drawing},
                onSelectionChanged: (s) => setState(() => drawing = s.first),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Undo',
                onPressed: undo.isEmpty ? null : () => history(true),
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: redo.isEmpty ? null : () => history(false),
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(
                    constraints.maxWidth,
                    (note.landscape ? 980 : 760) + 48,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: note.landscape ? 980 : 760,
                        height: note.landscape ? 760 : 980,
                        child: ClipRect(
                          child: CustomPaint(
                            painter: PaperPainter(note.paper, note.tone),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 28,
                                  top: 28,
                                  right: 28,
                                  bottom: 28,
                                  child: IgnorePointer(
                                    ignoring: drawing,
                                    child: TextField(
                                      controller: text,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      style: TextStyle(
                                        color: foreground,
                                        height: 1.6,
                                        fontSize: 16,
                                      ),
                                      cursorColor: foreground,
                                      decoration: InputDecoration(
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        hintText: 'Write your thoughts…',
                                        hintStyle: TextStyle(
                                          color: foreground.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          snapshot();
                                          current!.text = value;
                                          save();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: !drawing,
                                    child: Listener(
                                      onPointerDown: (e) {
                                        if (activeStroke != null) {
                                          return;
                                        }
                                        setState(() {
                                          snapshot();
                                          activePointer = e.pointer;
                                          activeStroke = [
                                            [
                                              e.localPosition.dx,
                                              e.localPosition.dy,
                                              e.pressure,
                                            ],
                                          ];
                                        });
                                      },
                                      onPointerMove: (e) {
                                        if (activeStroke == null ||
                                            activePointer != e.pointer) {
                                          return;
                                        }
                                        setState(
                                          () => activeStroke!.add([
                                            e.localPosition.dx,
                                            e.localPosition.dy,
                                            e.pressure,
                                          ]),
                                        );
                                      },
                                      onPointerUp: (e) {
                                        if (activePointer == e.pointer) {
                                          finishStroke();
                                        }
                                      },
                                      onPointerCancel: (e) {
                                        if (activePointer == e.pointer) {
                                          finishStroke();
                                        }
                                      },
                                      child: CustomPaint(
                                        painter: InkPainter([
                                          ...note.strokes,
                                          ?activeStroke,
                                        ], color: foreground),
                                        size: Size.infinite,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void finishStroke() {
    if (activeStroke == null) {
      return;
    }
    setState(() {
      current!.strokes.add(activeStroke!);
      activeStroke = null;
      activePointer = null;
      save();
    });
  }
}

class InkPainter extends CustomPainter {
  InkPainter(this.strokes, {this.color = const Color(0xff222222)});
  final Color color;
  final List<List<List<double>>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < stroke.length; i++) {
        final p = stroke[i];
        paint.strokeWidth = 1.5 + 2 * p[2].clamp(0, 1);
        final a = Offset(p[0], p[1]);
        if (i == 0) {
          canvas.drawCircle(a, paint.strokeWidth / 2, paint);
        } else {
          final previous = stroke[math.max(0, i - 1)];
          canvas.drawLine(Offset(previous[0], previous[1]), a, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant InkPainter oldDelegate) => true;
}
