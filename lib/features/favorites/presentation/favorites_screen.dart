import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/confirm_dialog.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import '../models/favorite_enums.dart';
import 'favorites_controller.dart';
import 'widgets/e621_favorites_view.dart';
import 'widgets/favorites_artists_view.dart';
import 'widgets/favorites_filter_bar.dart';
import 'widgets/favorites_glass_tab_bar.dart';
import 'widgets/favorites_offline_view.dart';
import 'widgets/favorites_posts_grid.dart';

export '../models/favorite_enums.dart';
export 'widgets/favorites_artists_view.dart' show favoriteArtistAlbums;

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
    return FavoritesPostsGrid(
      posts: filtered,
      settings: settings,
      downloadedKeys: downloadedKeys,
    );
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
    // Watched on every tab: a completed download must rebuild the screen
    // (and refetch the downloaded map) even if the user is not on the
    // offline tab when it finishes.
    ref.watch(downloadTasksProvider);
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
              FavoritesGlassTabBar(
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
                FavoritesFilterBar(
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
                  1 => FavoritesOfflineView(
                      offlinePosts: offlinePosts,
                      allPosts: allPosts,
                      downloaded: downloaded,
                      diskSizeBytes: diskSizeBytes,
                      activeTasks: activeTasks,
                      settings: settings,
                      isRu: isRu,
                      filterPosts: _applyFilters,
                    ),
                  2 => FavoritesArtistsView(
                      posts: allPosts,
                      settings: settings,
                      downloadedKeys: downloaded.keys.toSet(),
                      isRu: isRu,
                      searchQuery: _searchQuery,
                      filterPosts: _applyFilters,
                      selectedArtist: _selectedArtist,
                      onArtistSelected: (art) =>
                          setState(() => _selectedArtist = art),
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
}
