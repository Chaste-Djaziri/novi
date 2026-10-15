import 'package:flutter/material.dart';

import 'notebook.dart';

const documentKinds = ['Notebook', 'Whiteboard', 'Text document', 'Quick note'];
const papers = ['Blank', 'Dotted', 'Squared', 'Ruled', 'Wide ruled'];
const coverColors = [
  0xff303030,
  0xff484848,
  0xff656565,
  0xff909090,
  0xffbcbcbc,
  0xffe0e0e0,
];
IconData kindIcon(String kind) => switch (kind) {
  'Whiteboard' => Icons.dashboard_outlined,
  'Text document' => Icons.article_outlined,
  'Quick note' => Icons.edit_note,
  _ => Icons.book_outlined,
};
Color paperColor(String tone) => switch (tone) {
  'Dark' => const Color(0xff222222),
  'Gray' => const Color(0xffdddddd),
  _ => const Color(0xfffafafa),
};

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});
  @override
  Widget build(BuildContext context) => const Text(
    'novi.',
    style: TextStyle(
      color: Colors.white,
      fontSize: 38,
      fontWeight: FontWeight.w800,
      letterSpacing: -2,
    ),
  );
}

class PaperPainter extends CustomPainter {
  PaperPainter(this.pattern, this.tone);
  final String pattern;
  final String tone;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paperColor(tone));
    final paint = Paint()
      ..color = (tone == 'Dark' ? Colors.white : Colors.black).withValues(
        alpha: 0.12,
      )
      ..strokeWidth = 0.6;
    final spacing = pattern == 'Wide ruled' ? 36.0 : 24.0;
    if (pattern == 'Blank') {
      return;
    }
    for (double y = spacing; y < size.height; y += spacing) {
      if (pattern == 'Dotted') {
        for (double x = spacing; x < size.width; x += spacing) {
          canvas.drawCircle(Offset(x, y), 1, paint);
        }
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
    if (pattern == 'Squared') {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperPainter oldDelegate) =>
      pattern != oldDelegate.pattern || tone != oldDelegate.tone;
}

class DocumentCover extends StatelessWidget {
  const DocumentCover(this.note, {super.key});
  final Notebook note;
  @override
  Widget build(BuildContext context) {
    final foreground = Color(note.cover).computeLuminance() > 0.45
        ? Colors.black87
        : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: Color(note.cover),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kindIcon(note.kind), color: foreground, size: 23),
                const Spacer(),
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  note.kind.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.65),
                    fontSize: 9,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryView extends StatefulWidget {
  const LibraryView({
    super.key,
    required this.notes,
    required this.enabled,
    required this.onCreate,
    required this.onOpen,
    required this.onFavorite,
    required this.onTransfer,
  });
  final List<Notebook> notes;
  final bool enabled;
  final VoidCallback onCreate;
  final ValueChanged<Notebook> onOpen;
  final ValueChanged<Notebook> onFavorite;
  final ValueChanged<String> onTransfer;
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  bool favorites = false;
  bool grid = true;
  String query = '';
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final notes = widget.notes
        .where(
          (n) =>
              (!favorites || n.favorite) &&
              (filter == 'All' || n.kind == filter) &&
              n.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Row(
      children: [
        Material(
          color: const Color(0xff151515),
          child: Container(
            width: 212,
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Wordmark(),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 0, 36),
                  child: Text(
                    'SPACE FOR YOUR MIND',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selectedTileColor: const Color(0xff303030),
                  selected: !favorites,
                  leading: const Icon(Icons.folder_outlined, size: 20),
                  title: const Text('Documents'),
                  onTap: () => setState(() => favorites = false),
                ),
                const SizedBox(height: 6),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selectedTileColor: const Color(0xff303030),
                  selected: favorites,
                  leading: const Icon(Icons.star_border, size: 20),
                  title: const Text('Favorites'),
                  onTap: () => setState(() => favorites = true),
                ),
                const Spacer(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.archive_outlined, size: 20),
                  title: const Text(
                    'Back up library',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: widget.enabled
                      ? () => widget.onTransfer('backup')
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.restore, size: 20),
                  title: const Text(
                    'Restore backup',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: widget.enabled
                      ? () => widget.onTransfer('restore')
                      : null,
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'On your device.\nAlways yours.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            favorites ? 'Favorites' : 'Documents',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.notes.length} documents · A little room for every idea',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search documents',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.enabled
                          ? () => widget.onTransfer('import')
                          : null,
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Import'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: widget.enabled ? widget.onCreate : null,
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: filter,
                      underline: const SizedBox(),
                      items: ['All', ...documentKinds]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => filter = v!),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: grid ? 'List view' : 'Grid view',
                      onPressed: () => setState(() => grid = !grid),
                      icon: Icon(
                        grid ? Icons.view_list_outlined : Icons.grid_view,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xff262626)),
                const SizedBox(height: 16),
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_stories_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                query.isNotEmpty || favorites || filter != 'All'
                                    ? 'No matching documents'
                                    : 'Your next idea starts here',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Notebooks, whiteboards, text, and quick notes.',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: widget.enabled
                                    ? widget.onCreate
                                    : null,
                                child: const Text('Create a document'),
                              ),
                            ],
                          ),
                        )
                      : grid
                      ? GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 205,
                                mainAxisExtent: 264,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                          itemCount: notes.length,
                          itemBuilder: (_, i) {
                            final n = notes[i];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: InkWell(
                                          onTap: () => widget.onOpen(n),
                                          child: DocumentCover(n),
                                        ),
                                      ),
                                      Positioned(
                                        right: 3,
                                        top: 3,
                                        child: IconButton(
                                          tooltip: 'Favorite ${n.title}',
                                          onPressed: () => widget.onFavorite(n),
                                          icon: Icon(
                                            n.favorite
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 18,
                                            color:
                                                Color(n.cover)
                                                        .computeLuminance() >
                                                    0.45
                                                ? Colors.black87
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${n.kind} · ${n.paper}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : ListView(
                          children: notes
                              .map(
                                (n) => ListTile(
                                  leading: Icon(kindIcon(n.kind)),
                                  title: Text(n.title),
                                  subtitle: Text('${n.kind} · ${n.paper}'),
                                  trailing: IconButton(
                                    tooltip: 'Favorite ${n.title}',
                                    icon: Icon(
                                      n.favorite
                                          ? Icons.star
                                          : Icons.star_border,
                                    ),
                                    onPressed: () => widget.onFavorite(n),
                                  ),
                                  onTap: () => widget.onOpen(n),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CreateDocumentDialog extends StatefulWidget {
  const CreateDocumentDialog({super.key, this.existing});
  final Notebook? existing;
  @override
  State<CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<CreateDocumentDialog> {
  late final TextEditingController name;
  late Notebook draft;
  @override
  void initState() {
    super.initState();
    draft = widget.existing?.copy() ?? Notebook(id: newId(), title: '');
    name = TextEditingController(text: draft.title);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Make room for an idea'
                        : 'Document style',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a format. Make it yours.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: documentKinds
                  .map(
                    (kind) => ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(kindIcon(kind), size: 17),
                      label: Text(kind),
                      selected: draft.kind == kind,
                      onSelected: (_) => setState(() {
                        draft.kind = kind;
                        if (kind == 'Whiteboard') {
                          draft.landscape = true;
                          draft.paper = 'Dotted';
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 135,
                  height: 174,
                  child: DocumentCover(
                    Notebook(
                      id: 'preview',
                      title: name.text.trim().isEmpty
                          ? 'Your next idea'
                          : name.text,
                      cover: draft.cover,
                      kind: draft.kind,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('document-name'),
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Untitled document',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'COVER',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: coverColors
                            .map(
                              (color) => Tooltip(
                                message:
                                    'Cover ${coverColors.indexOf(color) + 1}',
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => draft.cover = color),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Color(color),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: draft.cover == color
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: draft.cover == color
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color:
                                                Color(color)
                                                        .computeLuminance() >
                                                    0.45
                                                ? Colors.black
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Paper templates',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: papers
                  .map(
                    (pattern) => InkWell(
                      onTap: () => setState(() => draft.paper = pattern),
                      child: SizedBox(
                        width: 104,
                        child: Column(
                          children: [
                            Container(
                              width: 104,
                              height: 115,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: draft.paper == pattern
                                      ? Colors.white
                                      : const Color(0xff444444),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CustomPaint(
                                  painter: PaperPainter(pattern, draft.tone),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(pattern, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                DropdownButton<String>(
                  value: draft.tone,
                  items: ['White', 'Gray', 'Dark']
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v paper')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => draft.tone = v!),
                ),
                DropdownButton<bool>(
                  value: draft.landscape,
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Portrait')),
                    DropdownMenuItem(value: true, child: Text('Landscape')),
                  ],
                  onChanged: (v) => setState(() => draft.landscape = v!),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Local by default. No account needed.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    draft.title = name.text.trim().isEmpty
                        ? 'Untitled ${draft.kind.toLowerCase()}'
                        : name.text.trim();
                    Navigator.pop(context, draft);
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    widget.existing == null ? 'Create' : 'Save style',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
