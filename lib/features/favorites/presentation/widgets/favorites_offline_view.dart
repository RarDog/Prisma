import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/shared/widgets/confirm_dialog.dart';
import '../../models/favorite_enums.dart';
import 'favorites_liquid_card.dart';
import 'favorites_posts_grid.dart';

class FavoritesOfflineView extends ConsumerStatefulWidget {
  const FavoritesOfflineView({
    super.key,
    required this.offlinePosts,
    required this.allPosts,
    required this.downloaded,
    required this.diskSizeBytes,
    required this.activeTasks,
    required this.settings,
    required this.isRu,
    required this.filterPosts,
  });

  final List<Post> offlinePosts;
  final List<Post> allPosts;
  final Map<String, DownloadedMedia> downloaded;
  final int diskSizeBytes;
  final List<DownloadTask> activeTasks;
  final AppSettings settings;
  final bool isRu;
  final List<Post> Function(List<Post> posts) filterPosts;

  @override
  ConsumerState<FavoritesOfflineView> createState() =>
      _FavoritesOfflineViewState();
}

class _FavoritesOfflineViewState extends ConsumerState<FavoritesOfflineView> {
  OfflineSortOption _offlineSort = OfflineSortOption.dateAddedDesc;

  Future<void> _confirmClearOfflineMedia({
    required List<Post> offlinePosts,
    required int diskSizeBytes,
    required bool isRu,
  }) async {
    final sizeFormatted = DownloadedMediaService.formatBytes(diskSizeBytes);
    final confirm = await showConfirmDialog(
      context,
      title: isRu ? 'Очистить офлайн-файлы?' : 'Clear offline files?',
      message: isRu
          ? 'Удалить сохраненные файлы ($sizeFormatted) с устройства?\nПосты останутся в избранном, но для их просмотра потребуется интернет.'
          : 'Remove downloaded files ($sizeFormatted) from device storage?\nPosts will remain in favorites, but require internet connection to view.',
      confirmText: isRu ? 'Очистить файлы' : 'Clear files',
      cancelText: isRu ? 'Отмена' : 'Cancel',
    );

    if (confirm && mounted) {
      final downloadedService = ref.read(downloadedMediaServiceProvider);
      for (final post in offlinePosts) {
        await downloadedService.deleteLocalFile(post.cacheKey);
      }
      ref.invalidate(downloadedMediaByKeysProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRu ? 'Офлайн-файлы очищены' : 'Offline files cleared',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildOfflineSyncHeader({
    required int downloadedCount,
    required int totalCount,
    required int pendingCount,
    required int diskSizeBytes,
    required List<DownloadTask> activeTasks,
    required List<Post> pendingPosts,
    required List<Post> offlinePosts,
    required bool isRu,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return FavoritesLiquidCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      glowColor: scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 7,
                      offset: const Offset(0, 2.5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.offline_pin_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$downloadedCount ${isRu ? 'из' : 'of'} $totalCount ${isRu ? 'офлайн' : 'saved'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.sd_storage_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DownloadedMediaService.formatBytes(diskSizeBytes)} ${isRu ? 'на устройстве' : 'on disk'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (offlinePosts.isNotEmpty) ...[
                IconButton(
                  tooltip:
                      isRu ? 'Очистить офлайн-файлы' : 'Clear offline files',
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: scheme.error.withValues(alpha: 0.85),
                  ),
                  onPressed: () => _confirmClearOfflineMedia(
                    offlinePosts: offlinePosts,
                    diskSizeBytes: diskSizeBytes,
                    isRu: isRu,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (pendingCount > 0)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary,
                        scheme.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        unawaited(HapticFeedback.mediumImpact());
                        final dm = ref.read(downloadManagerServiceProvider);
                        for (final p in pendingPosts) {
                          await dm.start(p);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isRu
                                  ? 'В очередь загрузки добавлено: $pendingCount'
                                  : 'Queued $pendingCount downloads',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.download_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isRu
                                  ? 'Скачать всё ($pendingCount)'
                                  : 'Download ($pendingCount)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRu ? 'Всё готово' : 'Synced',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (activeTasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${isRu ? 'Загрузка...' : 'Downloading...'} (${activeTasks.length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                ),
                Flexible(
                  child: Text(
                    activeTasks.first.fileName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '${isRu ? 'Сортировка' : 'Sort'}:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 8),
                SortCapsule(
                  label: isRu ? 'По дате' : 'Date',
                  icon: Icons.access_time_rounded,
                  isSelected: _offlineSort == OfflineSortOption.dateAddedDesc,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _offlineSort = OfflineSortOption.dateAddedDesc,
                    );
                  },
                ),
                const SizedBox(width: 6),
                SortCapsule(
                  label: isRu ? 'По размеру' : 'Size',
                  icon: Icons.pie_chart_outline_rounded,
                  isSelected: _offlineSort == OfflineSortOption.sizeDesc,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _offlineSort = OfflineSortOption.sizeDesc,
                    );
                  },
                ),
                const SizedBox(width: 6),
                SortCapsule(
                  label: isRu ? 'По автору' : 'Artist',
                  icon: Icons.person_rounded,
                  isSelected: _offlineSort == OfflineSortOption.artist,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _offlineSort = OfflineSortOption.artist,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offlinePosts = widget.offlinePosts;
    final allPosts = widget.allPosts;
    final downloaded = widget.downloaded;
    final diskSizeBytes = widget.diskSizeBytes;
    final activeTasks = widget.activeTasks;
    final settings = widget.settings;
    final isRu = widget.isRu;

    final pendingPosts =
        allPosts.where((p) => !downloaded.containsKey(p.cacheKey)).toList();

    final sorted = List<Post>.from(offlinePosts);
    if (_offlineSort == OfflineSortOption.sizeDesc) {
      final fileSizes = <String, int>{};
      for (final post in offlinePosts) {
        final m = downloaded[post.cacheKey];
        if (m != null) {
          fileSizes[post.cacheKey] = DownloadedMediaService.getFileSizeSync(m);
        }
      }
      sorted.sort((a, b) {
        final sA = fileSizes[a.cacheKey] ?? 0;
        final sB = fileSizes[b.cacheKey] ?? 0;
        return sB.compareTo(sA);
      });
    } else if (_offlineSort == OfflineSortOption.artist) {
      sorted.sort((a, b) {
        final artA = (a.tagGroups['artist'] ?? const []).firstOrNull ?? '';
        final artB = (b.tagGroups['artist'] ?? const []).firstOrNull ?? '';
        return artA.toLowerCase().compareTo(artB.toLowerCase());
      });
    } else {
      sorted.sort((a, b) {
        final dA = downloaded[a.cacheKey]?.downloadedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dB = downloaded[b.cacheKey]?.downloadedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dB.compareTo(dA);
      });
    }

    final filtered = widget.filterPosts(sorted);

    return Column(
      children: [
        _buildOfflineSyncHeader(
          downloadedCount: offlinePosts.length,
          totalCount: allPosts.length,
          pendingCount: pendingPosts.length,
          diskSizeBytes: diskSizeBytes,
          activeTasks: activeTasks,
          pendingPosts: pendingPosts,
          offlinePosts: offlinePosts,
          isRu: isRu,
        ),
        Expanded(
          child: offlinePosts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isRu ? 'Нет офлайн постов' : 'No offline posts',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRu
                              ? 'Нажмите «Скачать всё», чтобы загрузить избранные посты на устройство'
                              : 'Tap "Download all" above to save favorites for offline viewing',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Text(isRu
                          ? 'Ничего не найдено по фильтрам'
                          : 'No matching offline posts'),
                    )
                  : FavoritesPostsGrid(
                      posts: filtered,
                      settings: settings,
                      downloadedKeys: downloaded.keys.toSet(),
                    ),
        ),
      ],
    );
  }
}

class SortCapsule extends StatelessWidget {
  const SortCapsule({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? scheme.primary
            : (isDark
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.50)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55)),
        border: Border.all(
          color: isSelected
              ? scheme.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06)),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
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
