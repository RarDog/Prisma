import 'package:flutter/material.dart';

import 'artists_page_picker_sheet.dart';

/// Modern interactive bottom pagination bar for the artist catalog:
/// - Swipeable horizontal page numbers strip with momentum.
/// - Active page pill with glow and auto-centering.
/// - Prev/next step buttons.
/// - Direct dialpad button to open the full 3D wheel & slider page picker sheet.
class ArtistsPageBar extends StatefulWidget {
  const ArtistsPageBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.canGoBack,
    required this.canGoForward,
    required this.isRu,
    required this.onPageSelected,
  });

  final int page;
  final int? totalPages;
  final bool canGoBack;
  final bool canGoForward;
  final bool isRu;
  final ValueChanged<int> onPageSelected;

  @override
  State<ArtistsPageBar> createState() => _ArtistsPageBarState();
}

class _ArtistsPageBarState extends State<ArtistsPageBar> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemWidth = 44.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActivePage());
  }

  @override
  void didUpdateWidget(covariant ArtistsPageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToActivePage());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActivePage() {
    if (!_scrollController.hasClients) return;
    final targetOffset =
        ((widget.page - 1) * _itemWidth) - (120 - (_itemWidth / 2));
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _openPagePicker() {
    ArtistsPagePickerSheet.show(
      context,
      currentPage: widget.page,
      totalPages: widget.totalPages,
      isRu: widget.isRu,
      onPageSelected: widget.onPageSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isRu = widget.isRu;

    final maxPages =
        (widget.totalPages ?? (widget.page + 20)).clamp(1, 99999);

    return Center(
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Previous button
            IconButton(
              tooltip: isRu ? 'Предыдущая страница' : 'Previous page',
              iconSize: 20,
              onPressed: widget.canGoBack
                  ? () => widget.onPageSelected(widget.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),

            // Swipeable page numbers strip
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: maxPages,
                itemBuilder: (context, index) {
                  final p = index + 1;
                  final isActive = p == widget.page;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 8,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: isActive
                          ? _openPagePicker
                          : () => widget.onPageSelected(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive
                              ? scheme.primary
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: scheme.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Next button
            IconButton(
              tooltip: isRu ? 'Следующая страница' : 'Next page',
              iconSize: 20,
              onPressed: widget.canGoForward
                  ? () => widget.onPageSelected(widget.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),

            // Vertical divider
            Container(
              height: 20,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
            ),

            // Full dial/wheel picker button
            IconButton(
              tooltip: isRu ? 'Выбрать страницу' : 'Jump to page',
              iconSize: 20,
              color: scheme.primary,
              onPressed: _openPagePicker,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
