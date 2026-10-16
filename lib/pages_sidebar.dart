import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'desktop_ui.dart';
import 'library_ui.dart' show DocumentCover, PaperPainter;
import 'notebook.dart';
import 'workspace_tools.dart';

enum PagesSidebarTab { thumbnails, outline, bookmarks }

class PagesSidebar extends StatefulWidget {
  const PagesSidebar({
    super.key,
    required this.note,
    required this.session,
    required this.onClose,
    required this.onSelectPage,
    required this.onAddPage,
    required this.currentPageIndex,
    this.onDeletePage,
    this.onDuplicatePage,
    this.onToggleBookmark,
  });

  final Notebook note;
  final EditorSession session;
  final VoidCallback onClose;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onAddPage;
  final int currentPageIndex;
  final ValueChanged<int>? onDeletePage;
  final ValueChanged<int>? onDuplicatePage;
  final ValueChanged<int>? onToggleBookmark;

  @override
  State<PagesSidebar> createState() => _PagesSidebarState();
}

class _PagesSidebarState extends State<PagesSidebar> {
  PagesSidebarTab _activeTab = PagesSidebarTab.thumbnails;
  String _filter = 'All Pages';

  @override
  Widget build(BuildContext context) {
    final hasCover = widget.note.kind == 'Notebook';
    final paperCount = widget.note.pages.length;
    final totalSheets = (hasCover ? 1 : 0) + paperCount;

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xff181818),
        border: Border(
          right: BorderSide(color: Color(0xff2c2c2c), width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: ··· Pages ✕
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xff262626), width: 0.8),
              ),
            ),
            child: Row(
              children: [
                DesktopPopupMenuButton<String>(
                  tooltip: 'Page options',
                  onSelected: (val) {
                    if (val == 'add') {
                      widget.onAddPage();
                    } else if (val == 'bookmark') {
                      widget.onToggleBookmark?.call(widget.currentPageIndex);
                    }
                  },
                  itemBuilder: (context) => [
                    const DesktopMenuItem(
                      value: 'add',
                      child: Text('Add new page'),
                    ),
                    DesktopMenuItem(
                      value: 'bookmark',
                      child: Text(
                        _isSheetBookmarked(widget.currentPageIndex)
                            ? 'Remove bookmark'
                            : 'Bookmark current page',
                      ),
                    ),
                  ],
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Pages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                DesktopIconButton(
                  key: const Key('close-pages-sidebar'),
                  tooltip: 'Close pages',
                  icon: const Icon(
                    CupertinoIcons.xmark,
                    size: 14,
                    color: Colors.white70,
                  ),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Tabs: [Thumbnails] [Outline] [Bookmarks]
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xff121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  _buildTabButton(
                    tab: PagesSidebarTab.thumbnails,
                    icon: CupertinoIcons.square_grid_2x2,
                    tooltip: 'Thumbnails',
                  ),
                  _buildTabButton(
                    tab: PagesSidebarTab.outline,
                    icon: CupertinoIcons.list_bullet,
                    tooltip: 'Outline',
                  ),
                  _buildTabButton(
                    tab: PagesSidebarTab.bookmarks,
                    icon: CupertinoIcons.bookmark_fill,
                    tooltip: 'Bookmarks',
                  ),
                ],
              ),
            ),
          ),

          // Filter row: All Pages ⌵
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                DesktopPopupButton<String>(
                  value: _filter,
                  items: const [
                    DesktopMenuItem(value: 'All Pages', child: Text('All Pages')),
                    DesktopMenuItem(
                      value: 'Bookmarked',
                      child: Text('Bookmarked'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _filter = val);
                    }
                  },
                ),
                const Spacer(),
                Text(
                  '$totalSheets ${totalSheets == 1 ? "page" : "pages"}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 12, thickness: 0.8, color: Color(0xff262626)),

          // Body: Content based on active tab and filter
          Expanded(
            child: _buildBody(hasCover, paperCount, totalSheets),
          ),
        ],
      ),
    );
  }

  bool _isSheetBookmarked(int sheetIndex) {
    final hasCover = widget.note.kind == 'Notebook';
    if (hasCover) {
      if (sheetIndex == 0) return widget.note.coverBookmarked;
      final paperIdx = sheetIndex - 1;
      if (paperIdx >= 0 && paperIdx < widget.note.pages.length) {
        return widget.note.pages[paperIdx].isBookmarked;
      }
    } else {
      if (sheetIndex >= 0 && sheetIndex < widget.note.pages.length) {
        return widget.note.pages[sheetIndex].isBookmarked;
      }
    }
    return false;
  }

  Widget _buildTabButton({
    required PagesSidebarTab tab,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _activeTab == tab;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _activeTab = tab),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xff2a2a2a) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool hasCover, int paperCount, int totalSheets) {
    if (_activeTab == PagesSidebarTab.outline) {
      return _buildOutlineList(hasCover, paperCount);
    }

    final isBookmarksOnly =
        _activeTab == PagesSidebarTab.bookmarks || _filter == 'Bookmarked';

    final items = <int>[];
    for (int i = 0; i < totalSheets; i++) {
      if (isBookmarksOnly && !_isSheetBookmarked(i)) {
        continue;
      }
      items.add(i);
    }

    if (isBookmarksOnly && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.bookmark,
                size: 32,
                color: Colors.white24,
              ),
              const SizedBox(height: 12),
              const Text(
                'No Bookmarks',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the ribbon on any page thumbnail to bookmark it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: items.length + (isBookmarksOnly ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == items.length) {
          // The Add page dashed box
          return _buildAddPageCard();
        }
        final sheetIndex = items[index];
        return _buildPageCard(sheetIndex, hasCover);
      },
    );
  }

  Widget _buildAddPageCard() {
    return Tooltip(
      message: 'Add new page',
      child: InkWell(
        key: const Key('sidebar-add-page-button'),
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onAddPage,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: const Color(0xff007aff).withValues(alpha: 0.6),
            strokeWidth: 1.5,
            dashLength: 5,
            gapLength: 4,
            borderRadius: 8,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.plus,
                size: 26,
                color: Color(0xff007aff),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageCard(int sheetIndex, bool hasCover) {
    final isCover = hasCover && sheetIndex == 0;
    final paperIndex = hasCover ? sheetIndex - 1 : sheetIndex;
    final isCurrent = widget.currentPageIndex == sheetIndex;
    final isBookmarked = _isSheetBookmarked(sheetIndex);
    final pageNumber = sheetIndex + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            key: ValueKey('sidebar-page-thumbnail-$sheetIndex'),
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.onSelectPage(sheetIndex),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff121212),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xff007aff)
                      : Colors.white.withValues(alpha: 0.12),
                  width: isCurrent ? 2.0 : 1.0,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xff007aff).withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: isCover
                        ? _buildCoverThumbnail()
                        : _buildPaperThumbnail(paperIndex),
                  ),
                  // Bookmark ribbon button at top-right
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Tooltip(
                      message: isBookmarked ? 'Remove bookmark' : 'Bookmark page',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => widget.onToggleBookmark?.call(sheetIndex),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isBookmarked
                                ? CupertinoIcons.bookmark_fill
                                : CupertinoIcons.bookmark,
                            size: 13,
                            color: isBookmarked
                                ? const Color(0xff007aff)
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Label row: Page number and dropdown chevron
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$pageNumber',
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            DesktopPopupMenuButton<String>(
              tooltip: 'Page actions',
              onSelected: (val) {
                if (val == 'select') {
                  widget.onSelectPage(sheetIndex);
                } else if (val == 'bookmark') {
                  widget.onToggleBookmark?.call(sheetIndex);
                } else if (val == 'duplicate') {
                  widget.onDuplicatePage?.call(sheetIndex);
                } else if (val == 'delete') {
                  widget.onDeletePage?.call(sheetIndex);
                }
              },
              itemBuilder: (context) => [
                const DesktopMenuItem(
                  value: 'select',
                  child: Text('Go to page'),
                ),
                DesktopMenuItem(
                  value: 'bookmark',
                  child: Text(
                    isBookmarked ? 'Remove bookmark' : 'Bookmark page',
                  ),
                ),
                if (!isCover) ...[
                  const DesktopMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate page'),
                  ),
                  if (widget.note.pages.length > 1)
                    const DesktopMenuItem(
                      value: 'delete',
                      child: Text('Delete page'),
                    ),
                ],
              ],
              icon: CupertinoIcons.chevron_down,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoverThumbnail() {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: widget.note.landscape ? 980 : 760,
        height: widget.note.landscape ? 760 : 980,
        child: DocumentCover(widget.note),
      ),
    );
  }

  Widget _buildPaperThumbnail(int paperIndex) {
    if (paperIndex < 0 || paperIndex >= widget.note.pages.length) {
      return const SizedBox.shrink();
    }
    final page = widget.note.pages[paperIndex];
    final pageWidth = widget.note.landscape ? 980.0 : 760.0;
    final pageHeight = widget.note.landscape ? 760.0 : 980.0;

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PaperPainter(
                  widget.note.paper,
                  widget.note.tone,
                ),
              ),
            ),
            if (page.text.trim().isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                top: 24,
                child: Text(
                  page.text,
                  maxLines: 20,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.note.fontSize,
                    fontWeight: widget.note.boldText
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: widget.note.tone == 'Dark'
                        ? Colors.white70
                        : Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineList(bool hasCover, int paperCount) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      itemCount: (hasCover ? 1 : 0) + paperCount,
      itemBuilder: (context, index) {
        final isCover = hasCover && index == 0;
        final isCurrent = widget.currentPageIndex == index;
        final isBookmarked = _isSheetBookmarked(index);
        final title = isCover
            ? (widget.note.title.isNotEmpty ? widget.note.title : 'Cover')
            : 'Page ${index + 1}';
        final snippet = isCover
            ? 'Cover Page'
            : (hasCover
                ? (index - 1 < widget.note.pages.length &&
                        widget.note.pages[index - 1].text.trim().isNotEmpty
                    ? widget.note.pages[index - 1].text.trim().split('\n').first
                    : 'Blank page')
                : (index < widget.note.pages.length &&
                        widget.note.pages[index].text.trim().isNotEmpty
                    ? widget.note.pages[index].text.trim().split('\n').first
                    : 'Blank page'));

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isCurrent ? const Color(0xff222222) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isCurrent
                ? Border.all(color: const Color(0xff007aff).withValues(alpha: 0.5))
                : null,
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: Icon(
              isCover ? CupertinoIcons.book : CupertinoIcons.doc_text,
              size: 16,
              color: isCurrent ? const Color(0xff007aff) : Colors.white54,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.87),
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              snippet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            trailing: isBookmarked
                ? const Icon(
                    CupertinoIcons.bookmark_fill,
                    size: 12,
                    color: Color(0xff007aff),
                  )
                : null,
            onTap: () => widget.onSelectPage(index),
          ),
        );
      },
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashLength = 5.0,
    this.gapLength = 3.0,
    this.borderRadius = 6.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashLength, metric.length - distance);
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength ||
      oldDelegate.borderRadius != borderRadius;
}
