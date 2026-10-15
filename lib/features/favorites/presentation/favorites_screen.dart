import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_navigator.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/confirm_dialog.dart';
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'package:gel_rule_app/shared/widgets/post_masonry_grid.dart';
import 'favorites_controller.dart';
import 'widgets/e621_favorites_view.dart';

enum FavoriteMediaType { all, video, image }

enum OfflineSortOption { dateAddedDesc, sizeDesc, artist }

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _tabIndex = 0;
  String? _selectedArtist;
  FavoriteMediaType _mediaFilter = FavoriteMediaType.all;
  String? _selectedProvider;
  OfflineSortOption _offlineSort = OfflineSortOption.dateAddedDesc;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isVideoPost(Post post) {
    final type = post.fileType.toLowerCase();
    final url = post.fileUrl.toLowerCase();
    return type == 'mp4' ||
        type == 'webm' ||
        url.endsWith('.mp4') ||
        url.endsWith('.webm');
  }

  List<Post> _applyFilters(List<Post> posts) {
    var result = posts;
    if (_mediaFilter == FavoriteMediaType.video) {
      result = result.where(_isVideoPost).toList();
    } else if (_mediaFilter == FavoriteMediaType.image) {
      result = result.where((p) => !_isVideoPost(p)).toList();
    }

    if (_selectedProvider != null && _selectedProvider!.isNotEmpty) {
      result =
          result.where((p) => p.providerName == _selectedProvider).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((post) {
        return post.tags.any((t) => t.toLowerCase().contains(query)) ||
            post.providerName.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesControllerProvider);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';
    final allPosts = state.value?.posts ?? const <Post>[];
    final downloaded = ref
            .watch(downloadedMediaByKeysProvider(
              allPosts.map((post) => post.cacheKey).toList(growable: false),
            ))
            .value ??
        const <String, DownloadedMedia>{};

    final offlinePosts = allPosts
        .where((post) => downloaded.containsKey(post.cacheKey))
        .toList();
    final artistGroups = favoriteArtistAlbums(allPosts);
    final diskSizeBytes = _tabIndex == 1
        ? (ref.watch(offlineDiskSizeProvider(downloaded.values)).value ?? 0)
        : 0;
    final tasks = _tabIndex == 1
        ? (ref.watch(downloadTasksProvider).value ?? const <DownloadTask>[])
        : const <DownloadTask>[];
    final activeTasks = tasks
        .where((t) =>
            t.status == DownloadTaskStatus.running ||
            t.status == DownloadTaskStatus.queued)
        .toList();

    final targetPostsForFilters = _tabIndex == 1 ? offlinePosts : allPosts;
    final videoCount = targetPostsForFilters.where(_isVideoPost).length;
    final imageCount = targetPostsForFilters.length - videoCount;
    final availableProviders = targetPostsForFilters
        .map((p) => p.providerName.isNotEmpty ? p.providerName : p.providerId)
        .toSet()
        .toList()
      ..sort();

    return AdaptiveScaffold(
      title: isRu ? 'Избранное' : 'Favorites',
      actions: [
        IconButton(
          tooltip: _isSearching
              ? (isRu ? 'Закрыть поиск' : 'Close search')
              : (isRu ? 'Поиск в избранном' : 'Search favorites'),
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        IconButton(
          tooltip: isRu ? 'Очистить всё избранное' : 'Clear all favorites',
          icon: const Icon(Icons.delete_sweep_rounded),
          onPressed: allPosts.isEmpty
              ? null
              : () async {
                  final confirm = await showConfirmDialog(
                    context,
                    title: isRu ? 'Очистить избранное' : 'Clear favorites',
                    message: isRu
                        ? 'Вы действительно хотите удалить все посты (${allPosts.length}) из избранного?'
                        : 'Are you sure you want to remove all ${allPosts.length} posts from favorites?',
                    confirmText: isRu ? 'Очистить' : 'Clear',
                    cancelText: isRu ? 'Отмена' : 'Cancel',
                  );
                  if (confirm && context.mounted) {
                    await ref
                        .read(favoritesControllerProvider.notifier)
                        .clearAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isRu ? 'Избранное очищено' : 'Favorites cleared',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
        ),
      ],
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (data) {
          if (data.posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isRu ? 'В избранном пока пусто' : 'No favorites yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRu
                          ? 'Нажимайте ❤️ на постах в ленте, чтобы сохранить их'
                          : 'Tap ❤️ on posts in the feed to save them here',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/feed'),
                      icon: const Icon(Icons.explore_rounded),
                      label: Text(isRu ? 'Перейти в ленту' : 'Explore Feed'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Search input bar if active
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : Colors.white.withValues(alpha: 0.85),
                            width: 1.1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: isRu
                                ? 'Поиск по тегам и авторам...'
                                : 'Search by tags and artists...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                    ),
                  ),
                ),

              // Navigation Tabs with Liquid Glass container
              _FavoritesGlassTabBar(
                selectedIndex: _tabIndex,
                allCount: allPosts.length,
                offlineCount: offlinePosts.length,
                artistsCount: artistGroups.length,
                isRu: isRu,
                onTabSelected: (index) {
                  setState(() {
                    _tabIndex = index;
                    _selectedArtist = null;
                  });
                },
              ),

              // Media Type & Source Filter Bar (for Tab 0 and Tab 1)
              if (_tabIndex != 2 && _tabIndex != 3)
                _FavoritesFilterBar(
                  currentFilter: _mediaFilter,
                  onFilterChanged: (filter) =>
                      setState(() => _mediaFilter = filter),
                  videoCount: videoCount,
                  imageCount: imageCount,
                  selectedProvider: _selectedProvider,
                  availableProviders: availableProviders,
                  onProviderChanged: (prov) =>
                      setState(() => _selectedProvider = prov),
                  isRu: isRu,
                ),

              const SizedBox(height: 4),

              // Main Content
              Expanded(
                child: switch (_tabIndex) {
                  1 => _buildOfflineView(
                      offlinePosts: offlinePosts,
                      allPosts: allPosts,
                      downloaded: downloaded,
                      diskSizeBytes: diskSizeBytes,
                      activeTasks: activeTasks,
                      settings: settings,
                      isRu: isRu,
                    ),
                  2 => _buildArtistsView(
                      allPosts,
                      settings,
                      downloaded.keys.toSet(),
                      isRu,
                    ),
                  3 => E621FavoritesView(
                      settings: settings,
                      isRu: isRu,
                    ),
                  _ => _buildAllView(
                      allPosts,
                      settings,
                      downloaded.keys.toSet(),
                      isRu,
                    ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllView(
    List<Post> posts,
    AppSettings settings,
    Set<String> downloadedKeys,
    bool isRu,
  ) {
    final filtered = _applyFilters(posts);
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              isRu ? 'Ничего не найдено' : 'No matching posts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _mediaFilter = FavoriteMediaType.all;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              child: Text(isRu ? 'Сбросить фильтры' : 'Reset filters'),
            ),
          ],
        ),
      );
    }
    return _postsGrid(filtered, settings, downloadedKeys);
  }

  Widget _buildOfflineView({
    required List<Post> offlinePosts,
    required List<Post> allPosts,
    required Map<String, DownloadedMedia> downloaded,
    required int diskSizeBytes,
    required List<DownloadTask> activeTasks,
    required AppSettings settings,
    required bool isRu,
  }) {
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

    final filtered = _applyFilters(sorted);

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
                  : _postsGrid(filtered, settings, downloaded.keys.toSet()),
        ),
      ],
    );
  }

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

    return _FavoritesLiquidCard(
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
                _SortCapsule(
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
                _SortCapsule(
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
                _SortCapsule(
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

  Widget _buildArtistsView(
    List<Post> posts,
    AppSettings settings,
    Set<String> downloadedKeys,
    bool isRu,
  ) {
    final groups = favoriteArtistAlbums(posts);
    final selected = _selectedArtist;

    if (selected != null) {
      final artistPosts = groups[selected] ?? const [];
      final filtered = _applyFilters(artistPosts);

      return Column(
        children: [
          // Artist Header Banner (Liquid Glass)
          _FavoritesLiquidCard(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedArtist = null);
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: isRu ? 'Все авторы' : 'All artists',
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      selected.isNotEmpty ? selected[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${artistPosts.length} ${isRu ? 'работ' : 'posts'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(
                        '/search?q=${Uri.encodeComponent('artist:$selected')}');
                  },
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text(isRu ? 'В сети' : 'Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(isRu ? 'Ничего не найдено' : 'No posts found'),
                  )
                : _postsGrid(filtered, settings, downloadedKeys),
          ),
        ],
      );
    }

    final query = _searchQuery.toLowerCase();
    final entries = groups.entries.where((e) {
      if (query.isEmpty) return true;
      return e.key.toLowerCase().contains(query);
    }).toList();

    if (entries.isEmpty) {
      return Center(
        child: Text(isRu ? 'Авторы не найдены' : 'No artists found'),
      );
    }

    return ListView.separated(
      // ignore: deprecated_member_use
      cacheExtent: 140.0,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      // Extended bottom padding so the last artist cards scroll comfortably above the floating dock
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 140 + MediaQuery.paddingOf(context).bottom),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final artistPosts = entry.value;
        final previewUrls = artistPosts
            .map((p) => MediaUrlSelector.preview(p).firstOrNull)
            .whereType<String>()
            .take(3)
            .toList();

        return RepaintBoundary(
          child: _ArtistCard(
            artistName: entry.key,
            postsCount: artistPosts.length,
            previewUrls: previewUrls,
            isRu: isRu,
            onTap: () => setState(() => _selectedArtist = entry.key),
          ),
        );
      },
    );
  }

  Widget _postsGrid(
    List<Post> posts,
    AppSettings settings,
    Set<String> downloadedKeys,
  ) {
    if (posts.isEmpty) return const EmptyView(title: 'Nothing here yet');
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PostMasonryGrid(
      posts: posts,
      padding: EdgeInsets.fromLTRB(
        Responsive.isMobile(context) ? 8 : 16,
        Responsive.isMobile(context) ? 8 : 16,
        Responsive.isMobile(context) ? 8 : 16,
        150.0 + bottomInset,
      ),
      columns: Responsive.columnsFor(
        context,
        mobileColumns: settings.mobileColumns,
        desktopColumns: settings.desktopColumns,
      ),
      blurExplicit: settings.blurExplicitContent,
      showBadges: settings.showPostBadges,
      nsfwEnabled: settings.nsfwEnabled,
      mediaQualityMode: MediaQualityMode.fromName(settings.mediaQualityMode),
      favoriteKeys: posts.map((post) => post.cacheKey).toSet(),
      downloadedKeys: downloadedKeys,
      onOpen: (post) => AppNavigator.openPost(
        context,
        post: post,
        postsList: posts,
      ),
      onFavorite: (post) =>
          ref.read(favoritesControllerProvider.notifier).remove(post),
    );
  }
}

class _FavoritesLiquidCard extends StatelessWidget {
  const _FavoritesLiquidCard({
    required this.child,
    this.padding,
    this.glowColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = glowColor ?? theme.colorScheme.primary;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : accent.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.05 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.60),
                        theme.colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.38),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.88),
                        Colors.white.withValues(alpha: 0.72),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artistName,
    required this.postsCount,
    required this.previewUrls,
    required this.isRu,
    required this.onTap,
  });

  final String artistName;
  final int postsCount;
  final List<String> previewUrls;
  final bool isRu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : scheme.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            scheme.surfaceContainerHigh.withValues(alpha: 0.58),
                            scheme.surfaceContainerLow.withValues(alpha: 0.36),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.88),
                            Colors.white.withValues(alpha: 0.72),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    // Artist Squircle Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2.5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          artistName.isNotEmpty
                              ? artistName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Artist Name & Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artistName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$postsCount ${isRu ? 'работ' : 'posts'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Thumbnails preview
                    if (previewUrls.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          for (final url in previewUrls)
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : scheme.outlineVariant
                                              .withValues(alpha: 0.25),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    memCacheWidth: 128,
                                    memCacheHeight: 128,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: scheme.surfaceContainerHighest,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: scheme.surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, List<Post>> favoriteArtistAlbums(List<Post> posts) {
  final groups = <String, List<Post>>{};
  for (final post in posts) {
    final artists = post.tagGroups['artist'] ??
        post.tags.where((tag) => tag.startsWith('artist:')).toList();
    final names = artists.isEmpty
        ? const ['Unknown artist']
        : artists.map((tag) => tag.replaceFirst('artist:', '')).toList();
    for (final name in names) {
      groups.putIfAbsent(name, () => []).add(post);
    }
  }
  return Map.fromEntries(
    groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
  );
}

class _FavoritesGlassTabBar extends StatelessWidget {
  const _FavoritesGlassTabBar({
    required this.selectedIndex,
    required this.allCount,
    required this.offlineCount,
    required this.artistsCount,
    required this.isRu,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final int allCount;
  final int offlineCount;
  final int artistsCount;
  final bool isRu;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.22 : 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? theme.colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.50)
                    : Colors.white.withValues(alpha: 0.76),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FavoritesTabPill(
                      index: 0,
                      icon: Icons.favorite_rounded,
                      label: '${isRu ? 'Все' : 'All'} ($allCount)',
                      isSelected: selectedIndex == 0,
                      onTap: () => onTabSelected(0),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: _FavoritesTabPill(
                      index: 1,
                      icon: Icons.offline_pin_rounded,
                      label: '${isRu ? 'Офлайн' : 'Offline'} ($offlineCount)',
                      isSelected: selectedIndex == 1,
                      onTap: () => onTabSelected(1),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: _FavoritesTabPill(
                      index: 2,
                      icon: Icons.groups_rounded,
                      label: '${isRu ? 'Авторы' : 'Artists'} ($artistsCount)',
                      isSelected: selectedIndex == 2,
                      onTap: () => onTabSelected(2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: _FavoritesTabPill(
                      index: 3,
                      icon: Icons.hub_rounded,
                      iconColor: const Color(0xFF0077EE),
                      label: 'e621',
                      isSelected: selectedIndex == 3,
                      onTap: () => onTabSelected(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesTabPill extends StatelessWidget {
  const _FavoritesTabPill({
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.88),
                ],
              )
            : null,
        color: isSelected ? null : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.32),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : (iconColor ?? scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : scheme.onSurfaceVariant,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _FavoritesFilterBar extends StatelessWidget {
  const _FavoritesFilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
    required this.videoCount,
    required this.imageCount,
    required this.selectedProvider,
    required this.availableProviders,
    required this.onProviderChanged,
    required this.isRu,
  });

  final FavoriteMediaType currentFilter;
  final ValueChanged<FavoriteMediaType> onFilterChanged;
  final int videoCount;
  final int imageCount;
  final String? selectedProvider;
  final List<String> availableProviders;
  final ValueChanged<String?> onProviderChanged;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterCapsule(
              label: isRu ? 'Все' : 'All',
              isSelected: currentFilter == FavoriteMediaType.all,
              onTap: () => onFilterChanged(FavoriteMediaType.all),
            ),
            const SizedBox(width: 8),
            _FilterCapsule(
              icon: Icons.videocam_rounded,
              label: isRu ? 'Видео' : 'Videos',
              count: videoCount,
              isSelected: currentFilter == FavoriteMediaType.video,
              onTap: () => onFilterChanged(FavoriteMediaType.video),
            ),
            const SizedBox(width: 8),
            _FilterCapsule(
              icon: Icons.image_rounded,
              label: isRu ? 'Фото' : 'Images',
              count: imageCount,
              isSelected: currentFilter == FavoriteMediaType.image,
              onTap: () => onFilterChanged(FavoriteMediaType.image),
            ),
            if (availableProviders.length > 1) ...[
              const SizedBox(width: 8),
              _ProviderFilterMenu(
                selectedProvider: selectedProvider,
                availableProviders: availableProviders,
                onProviderChanged: onProviderChanged,
                isRu: isRu,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterCapsule extends StatelessWidget {
  const _FilterCapsule({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

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
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Colors.white : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderFilterMenu extends StatelessWidget {
  const _ProviderFilterMenu({
    required this.selectedProvider,
    required this.availableProviders,
    required this.onProviderChanged,
    required this.isRu,
  });

  final String? selectedProvider;
  final List<String> availableProviders;
  final ValueChanged<String?> onProviderChanged;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasFilter = selectedProvider != null;

    return PopupMenuButton<String?>(
      initialValue: selectedProvider,
      tooltip: isRu ? 'Фильтр по источнику' : 'Filter by source',
      onSelected: (val) {
        HapticFeedback.selectionClick();
        onProviderChanged(val);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(
                Icons.clear_all_rounded,
                size: 18,
                color: !hasFilter ? scheme.primary : null,
              ),
              const SizedBox(width: 8),
              Text(
                isRu ? 'Все источники' : 'All sources',
                style: TextStyle(
                  fontWeight: !hasFilter ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...availableProviders.map(
          (prov) => PopupMenuItem<String?>(
            value: prov,
            child: Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  size: 18,
                  color: selectedProvider == prov ? scheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(
                  prov,
                  style: TextStyle(
                    fontWeight: selectedProvider == prov
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: hasFilter
              ? scheme.secondaryContainer
              : (isDark
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.50)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.55)),
          border: Border.all(
            color: hasFilter
                ? scheme.secondary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06)),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.tune_rounded : Icons.filter_list_rounded,
              size: 14,
              color: hasFilter
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              hasFilter ? selectedProvider! : (isRu ? 'Источник' : 'Source'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasFilter ? FontWeight.bold : FontWeight.w600,
                color: hasFilter
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onProviderChanged(null);
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ] else ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortCapsule extends StatelessWidget {
  const _SortCapsule({
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
