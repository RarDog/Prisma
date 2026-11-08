import 'package:flutter/material.dart';

/// Floating pill overlay showing current page and total page count with chevrons
/// for multi-page posts.
class MultiPagePillOverlay extends StatelessWidget {
  const MultiPagePillOverlay({
    required this.pageIndex,
    required this.pageCount,
    required this.onPageChanged,
    super.key,
  });

  final int pageIndex;
  final int pageCount;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    return Positioned(
      bottom: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: pageIndex > 0 ? () => onPageChanged?.call(pageIndex - 1) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: pageIndex > 0 ? Colors.white : Colors.white38,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${pageIndex + 1} / $pageCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: pageIndex < pageCount - 1
                  ? () => onPageChanged?.call(pageIndex + 1)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: pageIndex < pageCount - 1
                      ? Colors.white
                      : Colors.white38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
