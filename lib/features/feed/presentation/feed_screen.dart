import 'dart:async';
import 'dart:math';

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
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'package:gel_rule_app/shared/widgets/keyboard_shortcut_utils.dart';
import 'package:gel_rule_app/shared/widgets/post_masonry_grid.dart';
import 'package:gel_rule_app/shared/widgets/provider_health_banner.dart';
import 'package:gel_rule_app/features/favorites/presentation/favorites_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'feed_controller.dart';
import 'widgets/feed_batch_action_bar.dart';
import 'widgets/feed_intents.dart';
import 'widgets/feed_post_action_coordinator.dart';
import 'widgets/feed_search_presets_bar.dart';
import 'widgets/feed_title.dart';
import 'widgets/feed_toolbar.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final Set<String> _selectedKeys = {};
  bool _selectionMode = false;
  final _showScrollToTop = ValueNotifier<bool>(false);
  final _toolbarVisible = ValueNotifier<bool>(true);
  double _lastScrollOffset = 0;
  double _scrollDeltaAccumulator = 0;
  String? _appliedInitialQuery;
  Timer? _scrollSaveDebounce;
  double _lastKnownScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if (_scrollController.position.extentAfter < 800) {
        ref.read(feedControllerProvider.notifier).loadNextPage();
      }
      _lastKnownScrollOffset = offset;
      final shouldShow = _scrollController.hasClients && offset > 1200;
      if (shouldShow != _showScrollToTop.value) {
        _showScrollToTop.value = shouldShow;
      }

      final autoHide =
          ref.read(appSettingsProvider).value?.autoHideFeedToolbar ?? true;

      if (autoHide) {
        // Smooth responsive scroll without triggering full-screen setState():
        // When near top (<= 60px), always keep toolbar fully expanded.
        if (offset <= 60) {
          _scrollDeltaAccumulator = 0;
          if (!_toolbarVisible.value) _toolbarVisible.value = true;
        } else {
          final delta = offset - _lastScrollOffset;
          if ((delta > 0 && _scrollDeltaAccumulator < 0) ||
              (delta < 0 && _scrollDeltaAccumulator > 0)) {
            _scrollDeltaAccumulator = 0;
          }
          _scrollDeltaAccumulator += delta;

          // Downward scroll: requires 55px of deliberate downward movement to collapse
          if (_scrollDeltaAccumulator > 55) {
            if (_toolbarVisible.value) _toolbarVisible.value = false;
          }
          // Upward scroll: requires 30px of deliberate upward movement to reveal
          else if (_scrollDeltaAccumulator < -30) {
            if (!_toolbarVisible.value) _toolbarVisible.value = true;
          }
        }
      }
      _lastScrollOffset = offset;

      _scrollSaveDebounce?.cancel();
      _scrollSaveDebounce = Timer(const Duration(milliseconds: 600), () {
        ref
            .read(feedControllerProvider.notifier)
            .saveSession(scrollOffset: _scrollController.offset);
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings =
          ref.read(appSettingsProvider).value ?? AppSettings.defaults;
      if (settings.lastFeedScrollOffset > 0 && _scrollController.hasClients) {
        _lastKnownScrollOffset = settings.lastFeedScrollOffset;
        _scrollController.jumpTo(
          settings.lastFeedScrollOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextQuery = widget.initialQuery;
    if (nextQuery != null && nextQuery != oldWidget.initialQuery) {
      _appliedInitialQuery = nextQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applySearchQuery(nextQuery);
      });
    } else if (nextQuery == null && oldWidget.initialQuery != null) {
      _appliedInitialQuery = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applySearchQuery('');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollSaveDebounce?.cancel();
    _scrollController.dispose();
    _showScrollToTop.dispose();
    _toolbarVisible.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_scrollController.hasClients) {
      _lastKnownScrollOffset = _scrollController.offset;
      ref
          .read(feedControllerProvider.notifier)
          .saveSession(scrollOffset: _lastKnownScrollOffset);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _lastKnownScrollOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      if ((_scrollController.offset - target).abs() > 24) {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final strings = ref.watch(appStringsProvider);
    final feed = ref.watch(feedControllerProvider);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;

    final initialQuery = widget.initialQuery?.trim();
    final currentTags = feed.value?.selectedTags.join(' ');
    if (initialQuery != null &&
        initialQuery.isNotEmpty &&
        _appliedInitialQuery != initialQuery &&
        currentTags != initialQuery) {
      _appliedInitialQuery = initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applySearchQuery(initialQuery);
      });
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyR): const FeedRandomPostIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
            const FeedRefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.f5): const FeedRefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyV): const FeedToggleSelectionIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const FeedClearSelectionIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): const FeedClearSelectionIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
            const FeedSelectVisibleIntent(),
      },
      child: Actions(
        actions: {
          FeedRefreshIntent: NonTextInputAction<FeedRefreshIntent>(
            onInvoke: (_) {
              ref.read(feedControllerProvider.notifier).refresh();
              return null;
            },
          ),
          FeedRandomPostIntent: NonTextInputAction<FeedRandomPostIntent>(
            onInvoke: (_) {
              final posts = feed.value?.posts;
              if (posts != null && posts.isNotEmpty) {
                _openRandom(posts);
              }
              return null;
            },
          ),
          FeedToggleSelectionIntent: NonTextInputAction<FeedToggleSelectionIntent>(
            onInvoke: (_) {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selectedKeys.clear();
              });
              return null;
            },
          ),
          FeedClearSelectionIntent: NonTextInputAction<FeedClearSelectionIntent>(
            onInvoke: (_) {
              _clearSelection();
              return null;
            },
          ),
          FeedSelectVisibleIntent: NonTextInputAction<FeedSelectVisibleIntent>(
            onInvoke: (_) {
              final state = feed.value;
              if (state != null) {
                setState(() {
                  _selectionMode = true;
                  _selectedKeys
                    ..clear()
                    ..addAll(state.posts.map((post) => post.cacheKey));
                });
              }
              return null;
            },
          ),
        },
        child: AdaptiveScaffold(
          title: 'Feed',
          titleWidget: FeedTitle(
            toolbarVisible: _toolbarVisible,
            onToggle: () {
              HapticFeedback.lightImpact();
              _toolbarVisible.value = !_toolbarVisible.value;
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _selectionMode
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
              ),
              tooltip: _selectionMode
                  ? (isRu ? 'Выйти из выбора (Esc)' : 'Exit selection (Esc)')
                  : (isRu ? 'Выбрать посты (V)' : 'Select posts (V)'),
              onPressed: () {
                setState(() {
                  _selectionMode = !_selectionMode;
                  if (!_selectionMode) _selectedKeys.clear();
                });
              },
            ),
            if (feed.value != null && feed.value!.selectedTags.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.bookmark_add_rounded),
                tooltip: isRu ? 'Сохранить пресет' : 'Save preset',
                onPressed: () => saveCurrentSearchPreset(
                    context, ref, feed.value!.selectedTags, settings),
              ),
            IconButton(
              icon: Icon(_gridModeIcon(settings.gridMode)),
              tooltip: isRu ? 'Вид сетки' : 'Grid view',
              onPressed: () => _cycleGridMode(settings),
            ),
          ],
          floatingActionButton: ValueListenableBuilder<bool>(
            valueListenable: _showScrollToTop,
            builder: (context, show, _) {
              if (!show) return const SizedBox.shrink();
              return FloatingActionButton.small(
                tooltip: isRu ? 'Наверх' : 'Scroll to top',
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: const Icon(Icons.arrow_upward_rounded),
              );
            },
          ),
          body: feed.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () =>
                  ref.read(feedControllerProvider.notifier).loadInitial(),
            ),
            data: (state) => Column(
              children: [
                // --- Offline sources notice ---
                const ProviderHealthBanner(),
                ValueListenableBuilder<bool>(
                  valueListenable: _toolbarVisible,
                  builder: (context, visible, child) {
                    return AnimatedCrossFade(
                      firstChild: child!,
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: visible
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 160),
                      sizeCurve: Curves.fastOutSlowIn,
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -180) {
                        HapticFeedback.lightImpact();
                        _toolbarVisible.value = false;
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.searchPresets.isNotEmpty)
                        FeedSearchPresetsBar(
                          presets: settings.searchPresets,
                          currentTags: state.selectedTags,
                          onApply: (preset) {
                            final decoded = decodeSearchPreset(preset);
                            _submitSearch(decoded['tags'] ?? '');
                          },
                          onDelete: (preset) async {
                            final updated = settings.searchPresets
                                .where((p) => p != preset)
                                .toList();
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .saveSettings(
                                    settings.copyWith(searchPresets: updated));
                          },
                        ),
                      FeedToolbar(
                        selectedTags: state.selectedTags,
                        selectedProviderIds: state.selectedProviderIds,
                        topPeriodFilter: state.topPeriodFilter,
                        tagSuggestions: state.tagSuggestions,
                        providers: state.providers,
                        rating: state.ratingFilter,
                        providerStatusMessage: state.providerStatusMessage,
                        onSearchChanged: (query) => ref
                            .read(feedControllerProvider.notifier)
                            .updateTagSuggestions(query),
                        onSuggestionTap: _submitSearch,
                        onTopPeriodChanged: (period) => ref
                            .read(feedControllerProvider.notifier)
                            .setTopPeriod(period),
                        onSearch: _submitSearch,
                        onRefresh: () =>
                            ref.read(feedControllerProvider.notifier).refresh(),
                        onClearFilters: _clearFilters,
                        onRandom: () => _openRandom(state.posts),
                        selectionMode: _selectionMode,
                        onToggleSelectionMode: () {
                          setState(() {
                            _selectionMode = !_selectionMode;
                            if (!_selectionMode) _selectedKeys.clear();
                          });
                        },
                        onQuickProviderToggle: (providerId) {
                          if (providerId == '__all__') {
                            ref
                                .read(feedControllerProvider.notifier)
                                .setProviders([]);
                            return;
                          }
                          final selected =
                              state.selectedProviderIds.contains(providerId)
                                  ? state.selectedProviderIds
                                      .where((id) => id != providerId)
                                      .toList()
                                  : [...state.selectedProviderIds, providerId];
                          ref
                              .read(feedControllerProvider.notifier)
                              .setProviders(selected);
                        },
                        onProviderFilter: () async {
                          final selected = await showProviderFilterSheet(
                            context,
                            providers: state.providers,
                            selectedIds: state.selectedProviderIds,
                          );
                          if (selected != null) {
                            await ref
                                .read(feedControllerProvider.notifier)
                                .setProviders(selected);
                          }
                        },
                        onRatingFilter: () async {
                          final result = await showRatingFilterSheet(
                              context, state.ratingFilter);
                          if (result != null) {
                            await ref
                                .read(feedControllerProvider.notifier)
                                .setRating(result.rating);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
                Expanded(
                  child: state.posts.isEmpty && !state.isLoadingMore
                      ? (state.error != null
                          ? ErrorView(
                              message: state.error!,
                              onRetry: () => ref
                                  .read(feedControllerProvider.notifier)
                                  .loadInitial(),
                            )
                          : EmptyView(
                              title: strings.noPostsYet,
                              message: strings.tryAnotherTag,
                            ))
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(feedControllerProvider.notifier)
                              .refresh(),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final favoriteKeys =
                                  ref.watch(favoriteKeysProvider).value ??
                                      <String>{};
                              final viewedKeys =
                                  ref.watch(viewedKeysProvider).value ??
                                      <String>{};
                              return PostMasonryGrid(
                                key: const PageStorageKey('feed_masonry_grid'),
                                controller: _scrollController,
                                posts: state.posts,
                                columns: Responsive.columnsFor(
                                  context,
                                  mobileColumns: settings.mobileColumns,
                                  desktopColumns: settings.desktopColumns,
                                ),
                                blurExplicit: settings.blurExplicitContent,
                                showBadges: settings.showPostBadges,
                                badgeConfig: settings.cardBadgeConfig,
                                nsfwEnabled: settings.nsfwEnabled,
                                mediaQualityMode: MediaQualityMode.fromName(
                                    settings.mediaQualityMode),
                                loading: state.isLoadingMore,
                                favoriteKeys: favoriteKeys,
                                viewedKeys: viewedKeys,
                                selectionMode: _selectionMode,
                                selectedKeys: _selectedKeys,
                                gridMode: settings.gridMode,
                                onOpen: (post) => AppNavigator.openPost(
                                  context,
                                  post: post,
                                  postsList: state.posts,
                                  fromFeed: true,
                                ),
                                onPreview: (post) =>
                                    _showPreview(context, post),
                                onToggleSelected: (post) =>
                                    _toggleSelected(post),
                                onFavorite: (post) =>
                                    FeedPostActionCoordinator.toggleFavorite(
                                        ref, post, favoriteKeys),
                                onAddToCollection: (post) =>
                                    FeedPostActionCoordinator.addToCollection(
                                        context, ref, post),
                                onHide: (post) =>
                                    FeedPostActionCoordinator.hidePost(
                                        context, ref, post),
                              );
                            },
                          ),
                        ),
                ),
                if (_selectionMode && _selectedKeys.isNotEmpty)
                  FeedBatchActionBar(
                    count: _selectedKeys.length,
                    onFavorite: () =>
                        FeedPostActionCoordinator.favoriteSelected(
                      ref,
                      _selectedPosts(state.posts),
                    ),
                    onCollection: () =>
                        FeedPostActionCoordinator.addSelectedToCollection(
                      context,
                      ref,
                      _selectedPosts(state.posts),
                      onDone: _clearSelection,
                    ),
                    onClear: _clearSelection,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (widget.initialQuery != null) {
        context.go('/');
      } else {
        _applySearchQuery('');
      }
      return;
    }
    final location = '/?q=${Uri.encodeQueryComponent(trimmed)}';
    if (widget.initialQuery?.trim() == trimmed) {
      _applySearchQuery(trimmed);
      return;
    }
    context.go(location);
  }

  void _openRandom(List<Post> posts) {
    if (posts.isEmpty) return;
    final post = posts[Random().nextInt(posts.length)];
    AppNavigator.openPost(
      context,
      post: post,
      postsList: posts,
      fromFeed: true,
    );
  }

  Future<void> _applySearchQuery(String query) async {
    final currentTags =
        ref.read(feedControllerProvider).value?.selectedTags.join(' ') ?? '';
    if (currentTags != query) {
      await ref.read(feedControllerProvider.notifier).search(query);
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _clearFilters() async {
    _appliedInitialQuery = null;
    await ref.read(feedControllerProvider.notifier).clearFilters();
    if (mounted && widget.initialQuery != null) {
      context.go('/');
    }
  }

  void _toggleSelected(Post post) {
    setState(() {
      _selectionMode = true;
      if (!_selectedKeys.add(post.cacheKey)) {
        _selectedKeys.remove(post.cacheKey);
      }
      if (_selectedKeys.isEmpty) _selectionMode = false;
    });
  }

  void _clearSelection() {
    if (!_selectionMode && _selectedKeys.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedKeys.clear();
    });
  }

  List<Post> _selectedPosts(List<Post> posts) {
    return posts
        .where((post) => _selectedKeys.contains(post.cacheKey))
        .toList();
  }

  Future<void> _showPreview(BuildContext context, Post post) {
    final imageUrl = MediaUrlSelector.preview(post).firstOrNull;
    final child = imageUrl == null
        ? const Center(child: Icon(Icons.broken_image_rounded, size: 48))
        : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain);
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Padding(padding: const EdgeInsets.all(8), child: child),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
          child: Padding(padding: const EdgeInsets.all(8), child: child),
        ),
      ),
    );
  }

  // ── Grid mode helpers ────────────────────────────────────────────
  IconData _gridModeIcon(String mode) {
    return switch (mode) {
      'grid' => Icons.grid_4x4_rounded,
      'list' => Icons.view_list_rounded,
      _ => Icons.dashboard_rounded,
    };
  }

  Future<void> _cycleGridMode(AppSettings settings) async {
    const modes = ['masonry', 'grid', 'list'];
    final idx = modes.indexOf(settings.gridMode);
    final next = modes[(idx + 1) % modes.length];
    await ref
        .read(settingsControllerProvider.notifier)
        .saveSettings(settings.copyWith(gridMode: next));
  }

}
