import 'paper_layout.dart';

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
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

const vibrantCoverColors = [
  0xff8e283b, // Merlot
  0xffd95c43, // Terracotta
  0xffc8822d, // Amber Ochre
  0xff2a5c3f, // Forest Pine
  0xff1c656d, // Deep Teal
  0xff255492, // Classic Cobalt
  0xff483d8b, // Indigo
  0xff6a3b68, // Plum
  0xff9b5d73, // Rose
  0xff634832, // Saddle Brown
  0xff4a5d3f, // Sage Olive
  0xff162032, // Midnight
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
  'Yellow' => const Color(0xfff5f0db),
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
  PaperPainter(this.pattern, this.tone, {this.guides = false});
  final bool guides;
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
    final spacing = PaperLayout(pattern).spacing;
    if (pattern == 'Blank' && !guides) {
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
      pattern != oldDelegate.pattern ||
      tone != oldDelegate.tone ||
      guides != oldDelegate.guides;
}

class DocumentCover extends StatelessWidget {
  const DocumentCover(this.note, {super.key});
  final Notebook note;
  @override
  Widget build(BuildContext context) {
    final hasImage = note.coverImage != null && note.coverImage!.isNotEmpty;
    Uint8List? imageBytes;
    if (hasImage) {
      try {
        imageBytes = base64Decode(note.coverImage!);
      } catch (_) {}
    }
    final foreground = hasImage
        ? Colors.white
        : (Color(note.cover).computeLuminance() > 0.45
              ? Colors.black87
              : Colors.white);
    return Container(
      decoration: BoxDecoration(
        color: Color(note.cover),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageBytes != null)
            Positioned.fill(
              child: Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Color(note.cover)),
              ),
            ),
          if (imageBytes != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
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
                    shadows: hasImage
                        ? const [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  note.kind.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.75),
                    fontSize: 9,
                    letterSpacing: 1.4,
                    shadows: hasImage
                        ? const [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ]
                        : null,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      favorites ? 'Favorites' : 'Documents',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.notes.length}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: DragToMoveArea(child: SizedBox(height: 32)),
                    ),
                    DesktopButton.icon(
                      onPressed: widget.enabled
                          ? () => widget.onTransfer('import')
                          : null,
                      icon: const Icon(
                        CupertinoIcons.arrow_down_to_line,
                        size: 15,
                      ),
                      label: const Text('Import'),
                    ),
                    const SizedBox(width: 10),
                    DesktopIconButton(
                      tooltip: grid ? 'List view' : 'Grid view',
                      onPressed: () => setState(() => grid = !grid),
                      icon: Icon(
                        grid
                            ? CupertinoIcons.list_bullet
                            : CupertinoIcons.square_grid_2x2,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    SizedBox(
                      width: 220,
                      child: DesktopTextField(
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 6, right: 2),
                          child: Icon(
                            CupertinoIcons.search,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                        onChanged: (v) => setState(() => query = v),
                        placeholder: 'Search documents',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xff262626), height: 1),
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
                                                (n.coverImage != null &&
                                                    n.coverImage!.isNotEmpty)
                                                ? Colors.white70
                                                : (Color(
                                                            n.cover,
                                                          ).computeLuminance() >
                                                          0.45
                                                      ? Colors.black87
                                                      : Colors.white70),
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
  String selectedTab = 'paper';
  bool hasCover = true;

  @override
  void initState() {
    super.initState();
    const chosenKind = 'Notebook';
    draft =
        widget.existing?.copy() ??
        Notebook(
          id: newId(),
          title: '',
          kind: chosenKind,
          paper: chosenKind == 'Whiteboard' ? 'Squared' : 'Lines',
          landscape: chosenKind == 'Whiteboard',
          tone: 'White',
        );
    name = TextEditingController(text: draft.title);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.existing == null && draft.kind != 'Notebook') return;
    draft.title = name.text.trim().isEmpty
        ? 'Untitled ${draft.kind.toLowerCase()}'
        : name.text.trim();
    Navigator.pop(context, draft);
  }

  String _paperDisplayName(String pattern) => switch (pattern) {
    'Squared' => 'Squared Paper',
    'Dotted' => 'Dotted Paper',
    'Ruled' => 'Ruled Narrow',
    'Wide ruled' => 'Ruled Wide',
    _ => 'Blank',
  };

  String _coverName(int color) => switch (color) {
    0xff303030 => 'Charcoal',
    0xff484848 => 'Graphite',
    0xff656565 => 'Slate',
    0xff909090 => 'Silver',
    0xffbcbcbc => 'Bright',
    0xffe0e0e0 => 'Alabaster',
    0xff8e283b => 'Merlot',
    0xffd95c43 => 'Terracotta',
    0xffc8822d => 'Amber',
    0xff2a5c3f => 'Forest',
    0xff1c656d => 'Teal',
    0xff255492 => 'Cobalt',
    0xff483d8b => 'Indigo',
    0xff6a3b68 => 'Plum',
    0xff9b5d73 => 'Rose',
    0xff634832 => 'Espresso',
    0xff4a5d3f => 'Sage',
    0xff162032 => 'Midnight',
    _ =>
      '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}',
  };

  Future<void> _pickCoverImage() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      String base64Str;
      try {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 800);
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        frame.image.dispose();
        if (byteData != null) {
          base64Str = base64Encode(byteData.buffer.asUint8List());
        } else {
          base64Str = base64Encode(bytes);
        }
      } catch (_) {
        base64Str = base64Encode(bytes);
      }

      setState(() {
        draft.coverImage = base64Str;
        selectedTab = 'cover';
      });
    } catch (e) {
      debugPrint('Error picking cover image: $e');
    }
  }

  void _removeCoverImage() {
    setState(() {
      draft.coverImage = null;
    });
  }

  Future<void> _showCustomColorPicker() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (ctx) => CustomColorPickerDialog(initialColor: draft.cover),
    );
    if (selected != null) {
      setState(() {
        draft.cover = selected.toARGB32();
        draft.coverImage = null;
        selectedTab = 'cover';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleLabel = widget.existing == null
        ? 'New Notebook'
        : 'Document Style';
    final actionLabel = widget.existing == null ? 'Create' : 'Save style';

    return DesktopDialog(
      child: Container(
        width: 760,
        decoration: BoxDecoration(
          color: const Color(0xff18181a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 36,
              spreadRadius: 6,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DesktopIconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 16),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        titleLabel,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xff007aff),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff007aff)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildPreviewCard(
                        label: 'COVER',
                        isSelected: selectedTab == 'cover',
                        onTap: () => setState(() => selectedTab = 'cover'),
                        bottomLabel: draft.coverImage != null
                            ? 'Custom Image'
                            : _coverName(draft.cover),
                        child: Container(
                          width: 108,
                          height: 136,
                          decoration: BoxDecoration(
                            color: Color(draft.cover),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              if (draft.coverImage != null &&
                                  draft.coverImage!.isNotEmpty)
                                Positioned.fill(
                                  child: Image.memory(
                                    base64Decode(draft.coverImage!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        Container(color: Color(draft.cover)),
                                  ),
                                ),
                              if (draft.coverImage != null &&
                                  draft.coverImage!.isNotEmpty)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.2),
                                          Colors.black.withValues(alpha: 0.7),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 9,
                                  color: Colors.black.withValues(alpha: 0.2),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  24,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      kindIcon(draft.kind),
                                      size: 18,
                                      color: draft.coverImage != null
                                          ? Colors.white
                                          : (Color(draft.cover)
                                                        .computeLuminance() >
                                                    0.45
                                                ? Colors.black87
                                                : Colors.white),
                                    ),
                                    const Spacer(),
                                    Text(
                                      name.text.trim().isEmpty
                                          ? 'Untitled'
                                          : name.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: draft.coverImage != null
                                            ? Colors.white
                                            : (Color(draft.cover)
                                                          .computeLuminance() >
                                                      0.45
                                                  ? Colors.black87
                                                  : Colors.white),
                                        shadows: draft.coverImage != null
                                            ? const [
                                                Shadow(
                                                  color: Colors.black87,
                                                  offset: Offset(0, 1),
                                                  blurRadius: 3,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _buildPreviewCard(
                        label: 'PAPER',
                        isSelected: selectedTab == 'paper',
                        onTap: () => setState(() => selectedTab = 'paper'),
                        bottomLabel: _paperDisplayName(draft.paper),
                        child: Container(
                          width: 108,
                          height: 136,
                          decoration: BoxDecoration(
                            color: paperColor(draft.tone),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CustomPaint(
                            painter: PaperPainter(draft.paper, draft.tone),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff222226),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Name',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: DesktopTextField(
                                      key: const Key('document-name'),
                                      controller: name,
                                      onChanged: (_) => setState(() {}),
                                      placeholder: 'Untitled Notebook',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                color: Color(0xff2f2f33),
                                height: 14,
                              ),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Format',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: DesktopPopupButton<String>(
                                        value: draft.kind,
                                        items:
                                            (widget.existing == null
                                                    ? ['Notebook']
                                                    : [draft.kind])
                                                .map(
                                                  (v) => DesktopMenuItem(
                                                    value: v,
                                                    child: Text(
                                                      v,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (v) => setState(() {
                                          draft.kind = v!;
                                          if (v == 'Whiteboard') {
                                            draft.landscape = true;
                                            draft.paper = 'Squared';
                                          }
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                color: Color(0xff2f2f33),
                                height: 14,
                              ),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Cover',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch.adaptive(
                                    value: hasCover,
                                    activeTrackColor: const Color(0xff007aff),
                                    onChanged: (v) =>
                                        setState(() => hasCover = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'PAPER TEMPLATES',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff222226),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Size',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: DesktopPopupButton<bool>(
                                        value: draft.landscape,
                                        items: const [
                                          DesktopMenuItem(
                                            value: false,
                                            child: Text(
                                              'Standard, Portrait',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DesktopMenuItem(
                                            value: true,
                                            child: Text(
                                              'Standard, Landscape',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) => setState(
                                          () => draft.landscape = v!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(
                                color: Color(0xff2f2f33),
                                height: 14,
                              ),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Color',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: DesktopPopupButton<String>(
                                        value: draft.tone,
                                        items: const [
                                          DesktopMenuItem(
                                            value: 'Yellow',
                                            child: Text(
                                              'Yellow paper',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DesktopMenuItem(
                                            value: 'White',
                                            child: Text(
                                              'White paper',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DesktopMenuItem(
                                            value: 'Dark',
                                            child: Text(
                                              'Dark paper',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => draft.tone = v!),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xff28282c), height: 1),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Text(
                    'Paper Templates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xff007aff),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Essentials',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              _buildPaperTemplatesRow(),
              const SizedBox(height: 24),
              const Divider(color: Color(0xff28282c), height: 1),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Cover Styles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: draft.coverImage != null
                            ? const Color(0xff007aff).withValues(alpha: 0.18)
                            : const Color(0xff222226),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: draft.coverImage != null
                              ? const Color(0xff007aff)
                              : Colors.white.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: 13,
                            color: draft.coverImage != null
                                ? const Color(0xff007aff)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            draft.coverImage != null
                                ? 'Cover Image Active'
                                : 'Upload Image...',
                            style: TextStyle(
                              color: draft.coverImage != null
                                  ? const Color(0xff007aff)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Essentials',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              _buildCoverStylesRow(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Color Palettes',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff007aff).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ANY COLOR',
                      style: TextStyle(
                        color: Color(0xff007aff),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const Key('custom-color-button'),
                    onTap: _showCustomColorPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff222226),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.eyedropper,
                            size: 13,
                            color: Color(0xff007aff),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Custom Hex / Picker...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildColorPaletteRow(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Cover Image',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff34c759).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'IMAGE UPLOAD',
                      style: TextStyle(
                        color: Color(0xff34c759),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildImageCoverSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
    required String bottomLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xff242426) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                child,
                const SizedBox(height: 8),
                Text(
                  bottomLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2.5,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xff007aff)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperTemplatesRow() {
    final templates = ['Blank', 'Dotted', 'Squared', 'Ruled', 'Wide ruled'];
    return Row(
      children: templates.map((pattern) {
        final isSelected = draft.paper == pattern;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => draft.paper = pattern),
              child: Column(
                children: [
                  Container(
                    height: 125,
                    decoration: BoxDecoration(
                      color: paperColor(draft.tone),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xff007aff)
                            : Colors.white.withValues(alpha: 0.12),
                        width: isSelected ? 2 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(1, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: PaperPainter(pattern, draft.tone),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xff007aff),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.checkmark,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTemplateName(pattern),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildToneDot('Yellow', const Color(0xfff5f0db)),
                      const SizedBox(width: 5),
                      _buildToneDot(
                        'White',
                        Colors.white,
                        tooltip: 'White paper',
                      ),
                      const SizedBox(width: 5),
                      _buildToneDot(
                        'Dark',
                        const Color(0xff222222),
                        tooltip: 'Dark paper',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateName(String pattern) {
    if (pattern == 'Blank') {
      return const Text(
        'Blank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pattern,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        Text(
          pattern.contains('ruled') || pattern == 'Ruled' ? 'Paper' : 'Paper',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildToneDot(String tone, Color color, {String? tooltip}) {
    final isSelected = draft.tone == tone;
    Widget dot = GestureDetector(
      onTap: () => setState(() => draft.tone = tone),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xff007aff) : Colors.white24,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: dot);
    }
    return dot;
  }

  Widget _buildCoverStylesRow() {
    return Row(
      children: coverColors.asMap().entries.map((entry) {
        final index = entry.key;
        final color = entry.value;
        final isSelected = draft.cover == color && draft.coverImage == null;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: 'Cover ${index + 1}',
              child: GestureDetector(
                onTap: () => setState(() {
                  draft.cover = color;
                  draft.coverImage = null;
                }),
                child: Column(
                  children: [
                    Container(
                      height: 125,
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xff007aff)
                              : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 2 : 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(1, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 8,
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xff007aff),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.checkmark,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _coverName(color),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPaletteRow() {
    final colors = vibrantCoverColors.take(6).toList();
    final isCustomSelected =
        draft.coverImage == null &&
        !coverColors.contains(draft.cover) &&
        !vibrantCoverColors.contains(draft.cover);
    return Column(
      children: [
        Row(
          children: colors.map((color) {
            final isSelected = draft.cover == color && draft.coverImage == null;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tooltip(
                  message: _coverName(color),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      draft.cover = color;
                      draft.coverImage = null;
                    }),
                    child: Column(
                      children: [
                        Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: Color(color),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xff007aff)
                                  : Colors.white.withValues(alpha: 0.12),
                              width: isSelected ? 2 : 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(1, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 8,
                                  color: Colors.black.withValues(alpha: 0.2),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xff007aff),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.checkmark,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _coverName(color),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ...vibrantCoverColors.skip(6).take(5).map((color) {
              final isSelected =
                  draft.cover == color && draft.coverImage == null;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: _coverName(color),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        draft.cover = color;
                        draft.coverImage = null;
                      }),
                      child: Column(
                        children: [
                          Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: Color(color),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xff007aff)
                                    : Colors.white.withValues(alpha: 0.12),
                                width: isSelected ? 2 : 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(1, 3),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withValues(alpha: 0.4),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 8,
                                    color: Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 8,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: Color(0xff007aff),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.checkmark,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _coverName(color),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tooltip(
                  message: 'Pick any custom color',
                  child: GestureDetector(
                    onTap: _showCustomColorPicker,
                    child: Column(
                      children: [
                        Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: isCustomSelected
                                ? Color(draft.cover)
                                : const Color(0xff222226),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCustomSelected
                                  ? const Color(0xff007aff)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: isCustomSelected ? 2 : 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(1, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              if (!isCustomSelected)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const SweepGradient(
                                            colors: [
                                              Colors.red,
                                              Colors.amber,
                                              Colors.green,
                                              Colors.teal,
                                              Colors.blue,
                                              Colors.purple,
                                              Colors.red,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            CupertinoIcons.plus,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Custom',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withValues(alpha: 0.4),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 8,
                                    color: Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xff007aff),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.checkmark,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isCustomSelected
                              ? _coverName(draft.cover)
                              : 'Custom...',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCoverSection() {
    if (draft.coverImage != null && draft.coverImage!.isNotEmpty) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(draft.coverImage!);
      } catch (_) {}

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xff1f1f23),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xff007aff).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff007aff).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Container(color: Colors.grey),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 15,
                        color: Color(0xff007aff),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Custom Cover Image Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your uploaded image is active for this notebook and saved locally.',
                    style: TextStyle(color: Colors.grey, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DesktopButton(
              onPressed: _pickCoverImage,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_2_circlepath, size: 13),
                  SizedBox(width: 5),
                  Text('Change Image', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DesktopIconButton(
              tooltip: 'Remove photo (Use color instead)',
              onPressed: _removeCoverImage,
              icon: const Icon(
                CupertinoIcons.trash,
                size: 16,
                color: Color(0xffff5252),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickCoverImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xff1d1d21),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xff007aff).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.photo_on_rectangle,
                color: Color(0xff007aff),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload custom cover photo or artwork',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Select any PNG, JPG, or WEBP image to embed directly in this notebook.',
                    style: TextStyle(color: Colors.grey, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xff007aff),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff007aff).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.plus, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Choose Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomColorPickerDialog extends StatefulWidget {
  const CustomColorPickerDialog({super.key, required this.initialColor});
  final int initialColor;

  @override
  State<CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  late Color currentColor;
  late final TextEditingController hexController;
  late int red;
  late int green;
  late int blue;

  static const List<Color> curatedSpectrum = [
    // Reds & Corals
    Color(0xffe63946),
    Color(0xffd90429),
    Color(0xffef233c),
    Color(0xfff72585),
    Color(0xffe07a5f),
    Color(0xfff3722c),
    // Oranges & Yellows
    Color(0xfff8961e),
    Color(0xfff9844a),
    Color(0xfff9c74f),
    Color(0xfff2cc8f),
    Color(0xffd4a373),
    Color(0xffbc6c25),
    // Greens & Teals
    Color(0xff90be6d),
    Color(0xff52b788),
    Color(0xff43aa8b),
    Color(0xff2d6a4f),
    Color(0xff1b4332),
    Color(0xff0077b6),
    // Blues & Cyans
    Color(0xff48cae4),
    Color(0xff0096c7),
    Color(0xff023e8a),
    Color(0xff1d3557),
    Color(0xff184e77),
    Color(0xff1e6091),
    // Purples & Violets
    Color(0xff7209b7),
    Color(0xff560bad),
    Color(0xff480ca8),
    Color(0xff3f37c9),
    Color(0xff7b2cbf),
    Color(0xff9d4edd),
    // Pinks, Earth & Neutrals
    Color(0xffb5179e),
    Color(0xff8338ec),
    Color(0xff3d405b),
    Color(0xff6d597a),
    Color(0xff4a3528),
    Color(0xff2b2d42),
  ];

  @override
  void initState() {
    super.initState();
    currentColor = Color(widget.initialColor);
    red = (currentColor.r * 255).round().clamp(0, 255);
    green = (currentColor.g * 255).round().clamp(0, 255);
    blue = (currentColor.b * 255).round().clamp(0, 255);
    hexController = TextEditingController(text: _colorToHex(currentColor));
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    return '${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  void _updateFromRgb(int r, int g, int b) {
    setState(() {
      red = r;
      green = g;
      blue = b;
      currentColor = Color.fromARGB(255, red, green, blue);
      hexController.text = _colorToHex(currentColor);
    });
  }

  void _onHexChanged(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) {
        setState(() {
          currentColor = Color(0xff000000 | val);
          red = (currentColor.r * 255).round().clamp(0, 255);
          green = (currentColor.g * 255).round().clamp(0, 255);
          blue = (currentColor.b * 255).round().clamp(0, 255);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lum = currentColor.computeLuminance();
    final isDark = lum < 0.45;
    return DesktopDialog(
      child: Container(
        width: 460,
        decoration: BoxDecoration(
          color: const Color(0xff18181a),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DesktopIconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 16),
                  ),
                  const Expanded(
                    child: Text(
                      'Custom Cover Color',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, currentColor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff007aff),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff222226),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isDark
                              ? CupertinoIcons.moon_fill
                              : CupertinoIcons.sun_max_fill,
                          size: 16,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HEX COLOR CODE',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                '#',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: DesktopTextField(
                                  key: const Key('custom-hex-field'),
                                  controller: hexController,
                                  onChanged: _onHexChanged,
                                  placeholder: '3A86FF',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SPECTRUM PALETTE',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: curatedSpectrum.map((color) {
                  final isSelected =
                      currentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentColor = color;
                        red = (color.r * 255).round().clamp(0, 255);
                        green = (color.g * 255).round().clamp(0, 255);
                        blue = (color.b * 255).round().clamp(0, 255);
                        hexController.text = _colorToHex(color);
                      });
                    },
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          width: isSelected ? 2 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(
                              CupertinoIcons.checkmark,
                              size: 14,
                              color: color.computeLuminance() > 0.45
                                  ? Colors.black87
                                  : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'RGB ADJUSTMENT',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              _buildRgbSlider('Red', red, const Color(0xffef4444), (v) {
                _updateFromRgb(v.round(), green, blue);
              }),
              _buildRgbSlider('Green', green, const Color(0xff22c55e), (v) {
                _updateFromRgb(red, v.round(), blue);
              }),
              _buildRgbSlider('Blue', blue, const Color(0xff3b82f6), (v) {
                _updateFromRgb(red, green, v.round());
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRgbSlider(
    String label,
    int value,
    Color accent,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: DesktopSlider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
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
                Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
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
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutQuad),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
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
    final cardLeft = (buttonCenterX - (cardWidth / 2)).clamp(
      12.0,
      screenSize.width - cardWidth - 12.0,
    );
    final arrowLeft = (buttonCenterX - cardLeft - (arrowWidth / 2)).clamp(
      16.0,
      cardWidth - 16.0 - arrowWidth,
    );

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
                              badge: 'Later',
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
                              badge: 'Later',
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
                            color: Color(0xffaaaaaa),
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
  const _PopoverArrowPainter({required this.color, required this.borderColor});

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
    return _creationTile(
      MouseRegion(
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
                        color: const Color(0xff353535),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          color: Color(0xffaaaaaa),
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
      ),
      widget.title == 'Notebook',
      widget.title,
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
    return _creationTile(
      MouseRegion(
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
      ),
      widget.title == 'Import',
      widget.title,
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
    return _creationTile(
      MouseRegion(
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
      ),
      false,
      widget.title,
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
    return _creationTile(
      MouseRegion(
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
      ),
      false,
      widget.title,
    );
  }
}

Widget _creationTile(Widget child, bool enabled, String title) => Tooltip(
  message: enabled ? title : '$title — Coming later',
  child: Semantics(
    enabled: enabled,
    button: true,
    label: enabled ? title : '$title — Coming later',
    child: Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(ignoring: !enabled, child: child),
    ),
  ),
);
