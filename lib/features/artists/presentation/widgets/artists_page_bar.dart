import 'package:flutter/material.dart';

import 'artists_page_picker_sheet.dart';

/// Modern interactive bottom pagination bar for the artist catalog:
/// - Liquid frosted capsule with smooth edge fade gradients.
/// - Swipeable horizontal page numbers strip with momentum.
/// - Active page pill with glow and auto-centering.
/// - Prev/next step buttons.
/// - Direct dialpad button with current page pill to open the 3D wheel & slider.
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
  static const double _itemWidth = 40.0;

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
        ((widget.page - 1) * _itemWidth) - (90 - (_itemWidth / 2));
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 280),
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
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF16161A).withValues(alpha: 0.90)
              : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 16,
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
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: widget.canGoBack
                      ? () => widget.onPageSelected(widget.page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),

                // Swipeable page numbers strip with soft horizontal fade mask
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 185),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.10, 0.90, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
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
                              horizontal: 2.5,
                              vertical: 7,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: isActive
                                  ? _openPagePicker
                                  : () => widget.onPageSelected(p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 35,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? LinearGradient(
                                          colors: [
                                            scheme.primary,
                                            scheme.primary
                                                .withValues(alpha: 0.85),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: isActive
                                      ? null
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.black.withValues(alpha: 0.03)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: scheme.primary
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  '$p',
                                  style: TextStyle(
                                    fontSize: 12.5,
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
                  ),
                ),

                // Next button
                IconButton(
                  tooltip: isRu ? 'Следующая страница' : 'Next page',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: widget.canGoForward
                      ? () => widget.onPageSelected(widget.page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),

                // Divider
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.10),
                ),

                // Open picker sheet button
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openPagePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.page}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}
