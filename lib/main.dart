import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'notebook.dart';

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
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff53654a)),
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
      setState(() => status = 'Saved locally');
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Could not open library: $e');
      }
    }
  }

  void select(Notebook note) {
    setState(() {
      current = note;
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

  void create() {
    final note = Notebook(id: newId(), title: 'Notebook ${notes.length + 1}');
    try {
      store!.save(note);
      notes.add(note);
      select(note);
      setState(() => status = 'Saved locally');
    } catch (e) {
      setState(() => status = 'Could not create notebook: $e');
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
    appBar: AppBar(
      title: const Text('novi.  /  Your local workspace'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Import, export and backup',
          onSelected: transfer,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'import', child: Text('Import .novi')),
            PopupMenuItem(
              value: 'export',
              enabled: current != null,
              child: const Text('Export notebook'),
            ),
            const PopupMenuItem(
              value: 'backup',
              child: Text('Back up library'),
            ),
            const PopupMenuItem(
              value: 'restore',
              child: Text('Restore backup as copies'),
            ),
          ],
          enabled: store != null,
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: Row(
      children: [
        SizedBox(
          width: 220,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: store == null ? null : create,
                  icon: const Icon(Icons.add),
                  label: const Text('New notebook'),
                ),
              ),
              Expanded(
                child: ListView(
                  children: notes
                      .map(
                        (n) => ListTile(
                          selected: current?.id == n.id,
                          leading: const Icon(Icons.book_outlined),
                          title: Text(n.title),
                          subtitle: const Text('1 page · local'),
                          onTap: () => select(n),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: current == null
              ? const Center(
                  child: Text('Create your first notebook to start writing.'),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              current!.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
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
                            onSelectionChanged: (s) =>
                                setState(() => drawing = s.first),
                          ),
                          IconButton(
                            tooltip: 'Undo',
                            onPressed: undo.isEmpty
                                ? null
                                : () => history(true),
                            icon: const Icon(Icons.undo),
                          ),
                          IconButton(
                            tooltip: 'Redo',
                            onPressed: redo.isEmpty
                                ? null
                                : () => history(false),
                            icon: const Icon(Icons.redo),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: const Color(0xffeeeee8),
                        child: SingleChildScrollView(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: SizedBox(
                                width: 760,
                                height: 980,
                                child: Material(
                                  color: Colors.white,
                                  elevation: 2,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 28,
                                        top: 28,
                                        right: 28,
                                        child: IgnorePointer(
                                          ignoring: drawing,
                                          child: TextField(
                                            controller: text,
                                            maxLines: null,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Write your thoughts…',
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
                                              if (e.pointer == activePointer) {
                                                finishStroke();
                                              }
                                            },
                                            onPointerCancel: (e) {
                                              if (e.pointer == activePointer) {
                                                finishStroke();
                                              }
                                            },
                                            child: CustomPaint(
                                              painter: InkPainter([
                                                ...current!.strokes,
                                                ?activeStroke,
                                              ]),
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
                  ],
                ),
        ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(10),
      child: Text('$status  ·  Offline · No account required'),
    ),
  );
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
  InkPainter(this.strokes);
  final List<List<List<double>>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = const Color(0xff26362d)
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
