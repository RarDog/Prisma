import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:prisma_app/app/motion.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/features/post/presentation/widgets/post_media_viewer.dart';

class PostMultiPageStrip extends StatefulWidget {
  const PostMultiPageStrip({
    required this.pages,
    required this.currentIndex,
    required this.onPageSelected,
    this.onDownloadAll,
    super.key,
  });

  final List<Post> pages;
  final int currentIndex;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onDownloadAll;

  @override
  State<PostMultiPageStrip> createState() => _PostMultiPageStripState();
}

class _PostMultiPageStripState extends State<PostMultiPageStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant PostMultiPageStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrentIndex();
    }
  }

  void _scrollToCurrentIndex() {
    if (!_scrollController.hasClients) return;
    const itemExtent = 66.0; // 58 width + 8 spacing
    final targetOffset = (widget.currentIndex * itemExtent) - 40.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.length <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.40),
          width: 1.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 350;
          final isTiny = constraints.maxWidth < 300;
          final downloadLabel = isRu
              ? (isTiny ? 'Все' : (isNarrow ? 'Скачать все' : 'Скачать все (${widget.pages.length})'))
              : (isTiny ? 'All' : (isNarrow ? 'Download all' : 'Download all (${widget.pages.length})'));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isRu ? 'Страницы' : 'Pages',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${widget.currentIndex + 1}/${widget.pages.length})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: isRu ? 'Предыдущая' : 'Previous',
                    onPressed: widget.currentIndex > 0
                        ? () => widget.onPageSelected(widget.currentIndex - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: isRu ? 'Следующая' : 'Next',
                    onPressed: widget.currentIndex < widget.pages.length - 1
                        ? () => widget.onPageSelected(widget.currentIndex + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  ),
                  if (widget.onDownloadAll != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: isRu
                          ? 'Скачать все страницы (${widget.pages.length})'
                          : 'Download all pages (${widget.pages.length})',
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: widget.onDownloadAll,
                        icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                        label: Text(downloadLabel),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.pages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final page = widget.pages[index];
                final isSelected = index == widget.currentIndex;
                final thumbUrl = page.previewUrl.isNotEmpty
                    ? page.previewUrl
                    : (page.sampleUrl.isNotEmpty ? page.sampleUrl : page.fileUrl);

                return InkWell(
                  onTap: () => widget.onPageSelected(index),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, 140),
                    width: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : Colors.black.withValues(alpha: 0.10)),
                        width: isSelected ? 2.2 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: thumbUrl,
                          httpHeaders: getMediaUrlHeaders(
                            providerId: page.providerId,
                            url: thumbUrl,
                          ),
                          fit: BoxFit.cover,
                          memCacheWidth: 140,
                          memCacheHeight: 180,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.white10 : Colors.black12,
                            child: const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: isDark ? Colors.white10 : Colors.black12,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 16),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
            ],
          );
        },
      ),
    );
  }
}
