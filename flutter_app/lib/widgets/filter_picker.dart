import 'package:flutter/material.dart';

import '../models/video_filter.dart';
import '../theme/brand.dart';

/// Horizontal scroll of filter chips. Used in the Go Live setup screen (light
/// surface) and the in-broadcast bottom sheet (dark surface — pass onDark).
class FilterPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<VideoFilter> onSelected;
  final bool onDark;

  const FilterPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedBg = onDark ? Colors.white12 : QBrand.cardAlt;
    final unselectedBorder = onDark ? Colors.white24 : QBrand.hairline;
    final unselectedText = onDark ? Colors.white70 : QBrand.fg;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: VideoFilter.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = VideoFilter.all[i];
          final selected = filter.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? QBrand.primary : unselectedBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? QBrand.primary : unselectedBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filter.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    filter.name,
                    style: TextStyle(
                      color: selected ? Colors.white : unselectedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small overlay chip for the live broadcast view. Tap → opens a bottom sheet
/// with the same FilterPicker so the host can change filters mid-stream.
class FilterToggleButton extends StatelessWidget {
  final String currentFilterId;
  final ValueChanged<VideoFilter> onFilterChange;

  const FilterToggleButton({
    super.key,
    required this.currentFilterId,
    required this.onFilterChange,
  });

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14060C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilterPicker(
                selectedId: currentFilterId,
                onDark: true,
                onSelected: (f) {
                  onFilterChange(f);
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = VideoFilter.byId(currentFilterId);
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(filter.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              filter.name,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
