import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/camera_colors.dart';
import '../../models/media_archive_item.dart';
import '../../painters/checkerboard_and_lift_painter.dart';

/// Filterable 3-column archive grid with dedicated Sticker Shelf quick actions (Copy / Share).
class MediaArchiveGridView extends StatelessWidget {
  final List<ZameraMediaItem> allItems;
  final ZameraArchiveFilter activeFilter;
  final String? selectedItemId;
  final ValueChanged<ZameraArchiveFilter> onFilterSelected;
  final ValueChanged<ZameraMediaItem> onSelectItem;
  final ValueChanged<ZameraMediaItem> onQuickCopySticker;
  final ValueChanged<ZameraMediaItem> onQuickShareSticker;

  const MediaArchiveGridView({
    super.key,
    required this.allItems,
    required this.activeFilter,
    this.selectedItemId,
    required this.onFilterSelected,
    required this.onSelectItem,
    required this.onQuickCopySticker,
    required this.onQuickShareSticker,
  });

  static String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return '00:00';
    final sec = ms ~/ 1000;
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = activeFilter == ZameraArchiveFilter.all
        ? allItems
        : allItems.where(activeFilter.matches).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: ZameraArchiveFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final f = ZameraArchiveFilter.values[idx];
              final selected = f == activeFilter;
              final count = f == ZameraArchiveFilter.all
                  ? allItems.length
                  : allItems.where(f.matches).length;
              return ChoiceChip(
                key: ValueKey('archive_filter_${f.name}'),
                avatar: Icon(
                  f.icon,
                  size: 15,
                  color: selected ? Colors.black : Colors.white70,
                ),
                label: Text(
                  '${f.labelTr} ($count)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.black : Colors.white70,
                  ),
                ),
                selected: selected,
                selectedColor: kIosYellow,
                backgroundColor: const Color(0xFF151924),
                onSelected: (_) => onFilterSelected(f),
              );
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeFilter.icon,
                        size: 40,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${activeFilter.labelTr} kategorisinde kayıt yok.',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  key: const ValueKey('archive_grid_view'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    final isCurrent = item.id == selectedItemId;
                    return _ArchiveGridTile(
                      item: item,
                      isCurrent: isCurrent,
                      durationText: _formatDuration(item.durationMs),
                      onTap: () => onSelectItem(item),
                      onQuickCopySticker: () => onQuickCopySticker(item),
                      onQuickShareSticker: () => onQuickShareSticker(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ArchiveGridTile extends StatelessWidget {
  final ZameraMediaItem item;
  final bool isCurrent;
  final String durationText;
  final VoidCallback onTap;
  final VoidCallback onQuickCopySticker;
  final VoidCallback onQuickShareSticker;

  const _ArchiveGridTile({
    required this.item,
    required this.isCurrent,
    required this.durationText,
    required this.onTap,
    required this.onQuickCopySticker,
    required this.onQuickShareSticker,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(item.primaryPath);
    final hasFile = item.primaryPath.isNotEmpty && file.existsSync();

    return GestureDetector(
      key: ValueKey('archive_tile_${item.id}'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? kIosYellow : Colors.white12,
            width: isCurrent ? 2.0 : 0.9,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.kind == ZameraMediaKind.sticker)
              const CustomPaint(
                painter: TransparencyCheckerboardPainter(tileSize: 10),
              )
            else
              const ColoredBox(color: Color(0xFF10131C)),

            if (item.kind == ZameraMediaKind.video)
              Container(
                color: const Color(0xFF141925),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: kIosYellow,
                      size: 30,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      durationText,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (hasFile)
              Padding(
                padding: item.kind == ZameraMediaKind.sticker
                    ? const EdgeInsets.all(6)
                    : EdgeInsets.zero,
                child: Image.file(
                  file,
                  fit: item.kind == ZameraMediaKind.sticker
                      ? BoxFit.contain
                      : BoxFit.cover,
                ),
              )
            else
              Icon(
                item.kind == ZameraMediaKind.sticker
                    ? Icons.content_cut_rounded
                    : Icons.photo_outlined,
                color: Colors.white30,
                size: 28,
              ),

            // Top-left format badge
            Positioned(
              left: 5,
              top: 5,
              child: Wrap(
                spacing: 4,
                children: [
                  if (item.hasRaw)
                    const _TileChip(text: 'RAW', color: kIosYellow),
                  if (item.isPortrait)
                    const _TileChip(text: 'PORTRE', color: kZameraCyan),
                  if (item.kind == ZameraMediaKind.sticker)
                    const _TileChip(text: 'PNG', color: kIosYellow),
                ],
              ),
            ),

            if (item.isFavorite)
              const Positioned(
                right: 5,
                top: 5,
                child: Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF453A),
                  size: 16,
                ),
              ),

            // 1-Tap Sticker Quick Actions
            if (item.kind == ZameraMediaKind.sticker)
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: _StickerMicroAction(
                        key: ValueKey('sticker_shelf_copy_${item.id}'),
                        icon: Icons.content_copy_rounded,
                        label: 'Kopyala',
                        onTap: onQuickCopySticker,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _StickerMicroAction(
                      key: ValueKey('sticker_shelf_share_${item.id}'),
                      icon: Icons.ios_share_rounded,
                      onTap: onQuickShareSticker,
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

class _TileChip extends StatelessWidget {
  final String text;
  final Color color;

  const _TileChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StickerMicroAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _StickerMicroAction({
    super.key,
    required this.icon,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white24, width: 0.7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: kIosYellow),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(
                label!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
