import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_ui.dart';
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
  'Whiteboard' => CupertinoIcons.rectangle_grid_2x2,
  'Text document' => CupertinoIcons.doc_text,
  'Quick note' => CupertinoIcons.pencil,
  _ => CupertinoIcons.book,
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
    this.showSidebar = true,
    this.onStatus,
  });
  final List<Notebook> notes;
  final bool enabled;
  final void Function([String? kind]) onCreate;
  final ValueChanged<Notebook> onOpen;
  final ValueChanged<Notebook> onFavorite;
  final ValueChanged<String> onTransfer;
  final bool showSidebar;
  final ValueChanged<String>? onStatus;
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  bool favorites = false;
  bool grid = true;
  String query = '';
  String filter = 'All';

  void _openNewMenu(BuildContext btnContext) {
    final box = btnContext.findRenderObject() as RenderBox?;
    if (box == null) {
      widget.onCreate();
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    showNewDocumentMenu(
      context,
      targetRect: offset & size,
      onCreateKind: (kind) => widget.onCreate(kind),
      onImport: () => widget.onTransfer('import'),
      onFeatureNotice: (notice) => widget.onStatus?.call(notice),
    );
  }

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
        if (widget.showSidebar)
          Container(
            width: 212,
            margin: const EdgeInsets.fromLTRB(8, 0, 0, 8),
            decoration: BoxDecoration(
              color: const Color(0xff181818),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
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
                DesktopListTile(
                  selected: !favorites,
                  leading: const Icon(CupertinoIcons.folder, size: 20),
                  title: const Text('Documents'),
                  onTap: () => setState(() => favorites = false),
                ),
                const SizedBox(height: 6),
                DesktopListTile(
                  selected: favorites,
                  leading: const Icon(CupertinoIcons.star, size: 20),
                  title: const Text('Favorites'),
                  onTap: () => setState(() => favorites = true),
                ),
                const Spacer(),
                const Divider(),
                DesktopListTile(
                  leading: const Icon(CupertinoIcons.archivebox, size: 20),
                  title: const Text(
                    'Back up library',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: widget.enabled
                      ? () => widget.onTransfer('backup')
                      : null,
                ),
                DesktopListTile(
                  leading: const Icon(
                    CupertinoIcons.arrow_counterclockwise,
                    size: 20,
                  ),
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
          )
        else
          Container(
            width: 52,
            margin: const EdgeInsets.fromLTRB(8, 0, 0, 8),
            decoration: BoxDecoration(
              color: const Color(0xff181818),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                _buildRailItem(
                  tooltip: 'Documents',
                  icon: CupertinoIcons.folder,
                  selected: !favorites,
                  onPressed: () => setState(() => favorites = false),
                ),
                const SizedBox(height: 10),
                _buildRailItem(
                  tooltip: 'Favorites',
                  icon: CupertinoIcons.star,
                  selected: favorites,
                  onPressed: () => setState(() => favorites = true),
                ),
                const Spacer(),
                const Divider(indent: 8, endIndent: 8),
                _buildRailItem(
                  tooltip: 'Back up library',
                  icon: CupertinoIcons.archivebox,
                  selected: false,
                  onPressed: widget.enabled
                      ? () => widget.onTransfer('backup')
                      : null,
                ),
                const SizedBox(height: 6),
                _buildRailItem(
                  tooltip: 'Restore backup',
                  icon: CupertinoIcons.arrow_counterclockwise,
                  selected: false,
                  onPressed: widget.enabled
                      ? () => widget.onTransfer('restore')
                      : null,
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(6, 0, 8, 6),
            decoration: BoxDecoration(
              color: const Color(0xff161616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DragToMoveArea(
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
                    ),
                    SizedBox(
                      width: 220,
                      child: DesktopTextField(
                        onChanged: (v) => setState(() => query = v),
                        placeholder: 'Search documents',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    DesktopButton.icon(
                      onPressed: widget.enabled
                          ? () => widget.onTransfer('import')
                          : null,
                      icon: const Icon(
                        CupertinoIcons.arrow_down_to_line,
                        size: 16,
                      ),
                      label: const Text('Import'),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (btnContext) => NewPillButton(
                        enabled: widget.enabled,
                        onPressed: widget.enabled
                            ? () => _openNewMenu(btnContext)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    DesktopPopupButton<String>(
                      value: filter,

                      items: ['All', ...documentKinds]
                          .map(
                            (v) => DesktopMenuItem(
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
                    DesktopIconButton(
                      tooltip: grid ? 'List view' : 'Grid view',
                      onPressed: () => setState(() => grid = !grid),
                      icon: Icon(
                        grid
                            ? CupertinoIcons.list_bullet
                            : CupertinoIcons.square_grid_2x2,
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
                                CupertinoIcons.book,
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
                              Builder(
                                builder: (btnContext) => DesktopButton(
                                  onPressed: widget.enabled
                                      ? () => _openNewMenu(btnContext)
                                      : null,
                                  primary: true,
                                  child: const Text('Create a document'),
                                ),
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
                                        child: DesktopIconButton(
                                          tooltip: 'Favorite ${n.title}',
                                          onPressed: () => widget.onFavorite(n),
                                          icon: Icon(
                                            n.favorite
                                                ? CupertinoIcons.star_fill
                                                : CupertinoIcons.star,
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
                                (n) => DesktopListTile(
                                  leading: Icon(kindIcon(n.kind)),
                                  title: Text(n.title),
                                  subtitle: Text('${n.kind} · ${n.paper}'),
                                  trailing: DesktopIconButton(
                                    tooltip: 'Favorite ${n.title}',
                                    icon: Icon(
                                      n.favorite
                                          ? CupertinoIcons.star_fill
                                          : CupertinoIcons.star,
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

  Widget _buildRailItem({
    required String tooltip,
    required IconData icon,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? const Color(0xff2e2e2e) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.8,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 19,
              color: selected
                  ? Colors.white
                  : (enabled ? Colors.white60 : Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateDocumentDialog extends StatefulWidget {
  const CreateDocumentDialog({super.key, this.existing, this.initialKind});
  final Notebook? existing;
  final String? initialKind;
  @override
  State<CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<CreateDocumentDialog> {
  late final TextEditingController name;
  late Notebook draft;
  @override
  void initState() {
    super.initState();
    final chosenKind = widget.initialKind ?? 'Notebook';
    draft = widget.existing?.copy() ??
        Notebook(
          id: newId(),
          title: '',
          kind: chosenKind,
          paper: chosenKind == 'Whiteboard' ? 'Dotted' : 'Lines',
          landscape: chosenKind == 'Whiteboard',
        );
    name = TextEditingController(text: draft.title);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DesktopDialog(
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
                DesktopIconButton(
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.xmark),
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
                    (kind) => DesktopToolButton(
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
                      DesktopTextField(
                        key: const Key('document-name'),
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        placeholder: 'Name — Untitled document',
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
                                            CupertinoIcons.check_mark,
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
                DesktopPopupButton<String>(
                  value: draft.tone,
                  items: ['White', 'Gray', 'Dark']
                      .map(
                        (v) =>
                            DesktopMenuItem(value: v, child: Text('$v paper')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => draft.tone = v!),
                ),
                DesktopPopupButton<bool>(
                  value: draft.landscape,
                  items: const [
                    DesktopMenuItem(value: false, child: Text('Portrait')),
                    DesktopMenuItem(value: true, child: Text('Landscape')),
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
                DesktopButton.icon(
                  primary: true,
                  onPressed: () {
                    draft.title = name.text.trim().isEmpty
                        ? 'Untitled ${draft.kind.toLowerCase()}'
                        : name.text.trim();
                    Navigator.pop(context, draft);
                  },
                  icon: const Icon(CupertinoIcons.check_mark, size: 18),
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

/// Pill button styled with macOS active blue matching the ChatGPT reference.
class NewPillButton extends StatelessWidget {
  const NewPillButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xff007aff),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff007aff).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.plus,
                  size: 14,
                  color: Colors.white,
                ),
                SizedBox(width: 5),
                Text(
                  'New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays the anchored popover menu with options:
/// Notebook, Whiteboard (NEW), Text Doc (NEW), Import, Quick Record,
/// QuickNote, Study Set, Image, Take Photo, Folder, and Import from Cloud Storage.
Future<void> showNewDocumentMenu(
  BuildContext context, {
  required Rect targetRect,
  required void Function(String kind) onCreateKind,
  required VoidCallback onImport,
  required void Function(String message) onFeatureNotice,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel',
    barrierColor: Colors.black26,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _NewDocumentMenuDialog(
        targetRect: targetRect,
        onCreateKind: onCreateKind,
        onImport: onImport,
        onFeatureNotice: onFeatureNotice,
      );
    },
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuad,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

class _NewDocumentMenuDialog extends StatelessWidget {
  const _NewDocumentMenuDialog({
    required this.targetRect,
    required this.onCreateKind,
    required this.onImport,
    required this.onFeatureNotice,
  });

  final Rect targetRect;
  final void Function(String kind) onCreateKind;
  final VoidCallback onImport;
  final void Function(String message) onFeatureNotice;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 308.0;
    const arrowWidth = 18.0;
    const arrowHeight = 9.0;

    final buttonCenterX = targetRect.left + (targetRect.width / 2);
    final cardLeft = (buttonCenterX - (cardWidth / 2))
        .clamp(12.0, screenSize.width - cardWidth - 12.0);
    final arrowLeft = (buttonCenterX - cardLeft - (arrowWidth / 2))
        .clamp(16.0, cardWidth - 16.0 - arrowWidth);

    final cardTop = targetRect.bottom + 8.0;

    return Stack(
      children: [
        Positioned.fill(
          child: Tooltip(
            message: 'Cancel',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Positioned(
          left: cardLeft,
          top: cardTop,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: arrowLeft),
                  child: CustomPaint(
                    size: const Size(arrowWidth, arrowHeight),
                    painter: _PopoverArrowPainter(
                      color: const Color(0xff1c1c1e),
                      borderColor: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xff1c1c1e),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 28,
                        spreadRadius: 4,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _NewTopTile(
                              title: 'Notebook',
                              icon: CupertinoIcons.book,
                              onTap: () {
                                Navigator.of(context).pop();
                                onCreateKind('Notebook');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NewTopTile(
                              title: 'Whiteboard',
                              icon: CupertinoIcons.rectangle_grid_2x2,
                              badge: 'NEW',
                              onTap: () {
                                Navigator.of(context).pop();
                                onCreateKind('Whiteboard');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NewTopTile(
                              title: 'Text Doc',
                              icon: CupertinoIcons.doc_text,
                              badge: 'NEW',
                              onTap: () {
                                Navigator.of(context).pop();
                                onCreateKind('Text document');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _NewMidTile(
                              title: 'Import',
                              icon: CupertinoIcons.arrow_down_to_line,
                              onTap: () {
                                Navigator.of(context).pop();
                                onImport();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NewMidTile(
                              title: 'Quick Record',
                              icon: CupertinoIcons.mic_fill,
                              hasSparkle: true,
                              onTap: () {
                                Navigator.of(context).pop();
                                onFeatureNotice(
                                  'Quick Record is coming in a future update',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff2c2c2e),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                            width: 0.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NewListTile(
                              title: 'QuickNote',
                              icon: CupertinoIcons.pencil,
                              onTap: () {
                                Navigator.of(context).pop();
                                onCreateKind('Quick note');
                              },
                            ),
                            const Divider(
                              height: 1,
                              indent: 46,
                              endIndent: 0,
                              color: Color(0xff38383a),
                            ),
                            _NewListTile(
                              title: 'Study Set',
                              icon: CupertinoIcons.rectangle_stack,
                              onTap: () {
                                Navigator.of(context).pop();
                                onFeatureNotice(
                                  'Study Set is coming in a future update',
                                );
                              },
                            ),
                            const Divider(
                              height: 1,
                              indent: 46,
                              endIndent: 0,
                              color: Color(0xff38383a),
                            ),
                            _NewListTile(
                              title: 'Image',
                              icon: CupertinoIcons.photo,
                              onTap: () {
                                Navigator.of(context).pop();
                                onFeatureNotice(
                                  'Image import is coming in a future update',
                                );
                              },
                            ),
                            const Divider(
                              height: 1,
                              indent: 46,
                              endIndent: 0,
                              color: Color(0xff38383a),
                            ),
                            _NewListTile(
                              title: 'Take Photo',
                              icon: CupertinoIcons.camera,
                              onTap: () {
                                Navigator.of(context).pop();
                                onFeatureNotice(
                                  'Take Photo is coming in a future update',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _NewStandaloneButton(
                        title: 'Folder',
                        icon: CupertinoIcons.folder,
                        onTap: () {
                          Navigator.of(context).pop();
                          onFeatureNotice(
                            'Folder organization is coming in a future update',
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _NewStandaloneButton(
                        title: 'Import from Cloud Storage',
                        icon: CupertinoIcons.plus_circle,
                        trailing: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xff3f4015),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            CupertinoIcons.lock_fill,
                            size: 11,
                            color: Color(0xffdcd66b),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          onFeatureNotice(
                            'Cloud storage is locked · Novi is 100% offline & local-first',
                          );
                        },
                      ),
                    ],
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

class _PopoverArrowPainter extends CustomPainter {
  const _PopoverArrowPainter({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height + 1)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1)
      ..close();
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final strokePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewTopTile extends StatefulWidget {
  const _NewTopTile({
    required this.title,
    required this.icon,
    this.badge,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  @override
  State<_NewTopTile> createState() => _NewTopTileState();
}

class _NewTopTileState extends State<_NewTopTile> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 82,
          decoration: BoxDecoration(
            color: hovering
                ? const Color(0xff36363a)
                : const Color(0xff2c2c2e),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: hovering ? 0.12 : 0.06),
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 24, color: Colors.white),
                    const SizedBox(height: 7),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.badge != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff3f4015),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.badge!,
                      style: const TextStyle(
                        color: Color(0xffdcd66b),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewMidTile extends StatefulWidget {
  const _NewMidTile({
    required this.title,
    required this.icon,
    this.hasSparkle = false,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool hasSparkle;
  final VoidCallback onTap;

  @override
  State<_NewMidTile> createState() => _NewMidTileState();
}

class _NewMidTileState extends State<_NewMidTile> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 72,
          decoration: BoxDecoration(
            color: hovering
                ? const Color(0xff36363a)
                : const Color(0xff2c2c2e),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: hovering ? 0.12 : 0.06),
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.hasSparkle)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 21, color: Colors.white),
                    const SizedBox(width: 3),
                    const Icon(
                      CupertinoIcons.sparkles,
                      size: 11,
                      color: Color(0xffe8e878),
                    ),
                  ],
                )
              else
                Icon(widget.icon, size: 21, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewListTile extends StatefulWidget {
  const _NewListTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_NewListTile> createState() => _NewListTileState();
}

class _NewListTileState extends State<_NewListTile> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 44,
          color: hovering ? const Color(0xff36363a) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(widget.icon, size: 19, color: Colors.white),
              const SizedBox(width: 13),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewStandaloneButton extends StatefulWidget {
  const _NewStandaloneButton({
    required this.title,
    required this.icon,
    this.trailing,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  State<_NewStandaloneButton> createState() => _NewStandaloneButtonState();
}

class _NewStandaloneButtonState extends State<_NewStandaloneButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 46,
          decoration: BoxDecoration(
            color: hovering
                ? const Color(0xff36363a)
                : const Color(0xff2c2c2e),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: hovering ? 0.12 : 0.06),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(widget.icon, size: 19, color: Colors.white),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

