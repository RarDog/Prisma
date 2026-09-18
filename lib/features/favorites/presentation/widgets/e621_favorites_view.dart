import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_navigator.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/post_masonry_grid.dart';
import 'package:gel_rule_app/features/providers/presentation/providers_controller.dart';
import 'package:gel_rule_app/features/providers/presentation/widgets/e621_auth_dialog.dart';
import 'package:gel_rule_app/features/favorites/presentation/favorites_controller.dart';

enum E621SubTab { favorites, popular }

class E621FavoritesView extends ConsumerStatefulWidget {
  const E621FavoritesView({
    required this.settings,
    required this.isRu,
    super.key,
  });

  final AppSettings settings;
  final bool isRu;

  @override
  ConsumerState<E621FavoritesView> createState() => _E621FavoritesViewState();
}

class _E621FavoritesViewState extends ConsumerState<E621FavoritesView> {
  final List<Post> _posts = [];
  final ScrollController _scrollController = ScrollController();
  E621SubTab _subTab = E621SubTab.favorites;
  String _popularScale = 'day';
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  String? _currentLogin;
  bool _isImporting = false;
  int _importedCount = 0;
  bool _isSyncingBlacklist = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoading &&
        _hasMore) {
      _loadNextPage();
    }
  }

  Future<E621Provider?> _getE621Provider() async {
    final instance = await ref
        .read(providerManagerProvider)
        .getProviderInstance('e621');
    return instance is E621Provider ? instance : null;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _posts.clear();
      _page = 1;
      _hasMore = true;
    });

    try {
      final provider = await _getE621Provider();
      if (provider == null) {
        setState(() {
          _isLoading = false;
          _error = widget.isRu
              ? 'Источник e621 не найден'
              : 'e621 provider not found';
        });
        return;
      }

      final login = provider.login?.trim();
      setState(() => _currentLogin = login);

      if (_subTab == E621SubTab.popular) {
        final items = await provider.getPopularPosts(scale: _popularScale);
        if (mounted) {
          setState(() {
            _posts.addAll(items);
            _isLoading = false;
            _hasMore = false;
          });
        }
        return;
      }

      if (login == null || login.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final items = await provider.getFavorites(page: 1, limit: 50);
      if (mounted) {
        setState(() {
          _posts.addAll(items);
          _isLoading = false;
          _hasMore = items.length >= 50;
          _page = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = widget.isRu ? 'Ошибка загрузки: $e' : 'Loading error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore || _subTab == E621SubTab.popular) return;
    setState(() => _isLoading = true);

    try {
      final provider = await _getE621Provider();
      if (provider == null) {
        setState(() => _isLoading = false);
        return;
      }

      final items = await provider.getFavorites(page: _page, limit: 50);
      if (mounted) {
        setState(() {
          final existingIds = _posts.map((p) => p.id).toSet();
          final newItems =
              items.where((p) => !existingIds.contains(p.id)).toList();
          _posts.addAll(newItems);
          _isLoading = false;
          _hasMore = items.length >= 50;
          _page++;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importAllToLocal() async {
    if (_isImporting) return;
    setState(() {
      _isImporting = true;
      _importedCount = 0;
    });
    HapticFeedback.mediumImpact();

    try {
      final provider = await _getE621Provider();
      if (provider == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final favService = ref.read(favoriteServiceProvider);
      int imported = 0;
      int page = 1;
      const pageSize = 75;
      final seenIds = <String>{};
      final allNewPosts = <Post>[];

      while (true) {
        final pagePosts =
            await provider.getFavorites(page: page, limit: pageSize);
        if (pagePosts.isEmpty) break;

        final batchToAdd = <Post>[];
        for (final post in pagePosts) {
          if (seenIds.add(post.id)) {
            batchToAdd.add(post);
            allNewPosts.add(post);
          }
        }

        if (batchToAdd.isNotEmpty) {
          await favService.addFavorites(batchToAdd);
          imported += batchToAdd.length;
        }

        if (mounted) {
          setState(() {
            _importedCount = imported;
          });
        }

        if (pagePosts.length < pageSize) {
          break;
        }

        page++;
        if (page > 100) {
          break;
        }
      }

      if (mounted) {
        setState(() {
          final existingIds = _posts.map((p) => p.id).toSet();
          final additional = allNewPosts
              .where((p) => !existingIds.contains(p.id))
              .toList();
          _posts.addAll(additional);
          _hasMore = false;
        });
      }

      ref.invalidate(favoriteKeysProvider);
      ref.invalidate(favoritesControllerProvider);

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isRu
                  ? 'Импортировано $imported постов в локальное избранное!'
                  : 'Imported $imported posts to local favorites!',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isRu ? 'Ошибка импорта: $e' : 'Import error: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _syncBlacklist() async {
    if (_isSyncingBlacklist) return;
    setState(() => _isSyncingBlacklist = true);
    HapticFeedback.mediumImpact();

    try {
      final provider = await _getE621Provider();
      if (provider == null) {
        setState(() => _isSyncingBlacklist = false);
        return;
      }
      final tags = await provider.fetchAccountBlacklist();
      if (!mounted) return;
      if (tags.isEmpty) {
        setState(() => _isSyncingBlacklist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isRu
                  ? 'В аккаунте e621 нет заблокированных тегов'
                  : 'No blacklisted tags on e621 account',
            ),
          ),
        );
        return;
      }

      final res = await ref.read(settingsServiceProvider).importBlacklistFromE621(tags);
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        setState(() => _isSyncingBlacklist = false);
        res.fold(
          onSuccess: (count) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  count > 0
                      ? (widget.isRu
                          ? 'Синхронизировано $count новых тегов/правил из e621!'
                          : 'Imported $count new rules/tags from e621!')
                      : (widget.isRu
                          ? 'Черный список актуален (нет новых тегов)'
                          : 'Blacklist already up to date'),
                ),
              ),
            );
          },
          onError: (f) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${widget.isRu ? 'Ошибка: ' : 'Error: '}${f.message}')),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingBlacklist = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.isRu ? 'Ошибка синхронизации: ' : 'Sync error: '}$e')),
        );
      }
    }
  }

  Widget _buildLoginPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0055AA), Color(0xFF0088FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0055AA).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.hub_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.isRu ? 'Аккаунт e621 не указан' : 'e621 account not set',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                widget.isRu
                    ? 'Чтобы смотреть избранное и синхронизировать черный список, укажите логин и API-ключ в настройках источника e621.'
                    : 'To browse favorites and sync blacklist, provide your e621 login and API key.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () async {
                final configs =
                    ref.read(providersControllerProvider).value ?? [];
                final e621Config = configs.firstWhere(
                  (p) => p.apiType.toLowerCase() == 'e621',
                  orElse: () => configs.first,
                );
                await E621AuthDialog.show(
                  context,
                  config: e621Config,
                  onSaved: (updated) {
                    ref
                        .read(providersControllerProvider.notifier)
                        .save(updated);
                    _loadInitial();
                  },
                );
              },
              icon: const Icon(Icons.vpn_key_rounded, size: 18),
              label: Text(
                widget.isRu
                    ? 'Войти / Настроить API-ключ e621'
                    : 'Set e621 API Key',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0055AA),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final downloaded = ref.watch(
          downloadedMediaByKeysProvider(
            _posts.map((post) => post.cacheKey).toList(growable: false),
          ),
        ).value ??
        const <String, DownloadedMedia>{};

    final favoriteKeys = ref.watch(favoriteKeysProvider).value ?? <String>{};

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: Column(
        children: [
          // Sub-Tab Switcher: Favorites vs Popular
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<E621SubTab>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: E621SubTab.favorites,
                    icon: const Icon(Icons.favorite_rounded, size: 16),
                    label: Text(
                      widget.isRu ? 'Избранное' : 'Favorites',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ButtonSegment(
                    value: E621SubTab.popular,
                    icon: const Icon(Icons.local_fire_department_rounded, size: 16),
                    label: Text(
                      widget.isRu ? 'Популярное' : 'Popular',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                selected: {_subTab},
                onSelectionChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _subTab = value.first);
                  _loadInitial();
                },
              ),
            ),
          ),

          // Scale Selector for Popular
          if (_subTab == E621SubTab.popular)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(widget.isRu ? 'День' : 'Day'),
                    selected: _popularScale == 'day',
                    onSelected: (selected) {
                      if (selected && _popularScale != 'day') {
                        HapticFeedback.selectionClick();
                        setState(() => _popularScale = 'day');
                        _loadInitial();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(widget.isRu ? 'Неделя' : 'Week'),
                    selected: _popularScale == 'week',
                    onSelected: (selected) {
                      if (selected && _popularScale != 'week') {
                        HapticFeedback.selectionClick();
                        setState(() => _popularScale = 'week');
                        _loadInitial();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(widget.isRu ? 'Месяц' : 'Month'),
                    selected: _popularScale == 'month',
                    onSelected: (selected) {
                      if (selected && _popularScale != 'month') {
                        HapticFeedback.selectionClick();
                        setState(() => _popularScale = 'month');
                        _loadInitial();
                      }
                    },
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: widget.isRu ? 'Обновить' : 'Refresh',
                    onPressed: _isLoading ? null : _loadInitial,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),
            ),

          // Favorites Header Banner (only when on Favorites tab and logged in)
          if (_subTab == E621SubTab.favorites &&
              _currentLogin != null &&
              _currentLogin!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131A26).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF0055AA).withValues(alpha: 0.35)
                            : const Color(0xFF0055AA).withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0055AA), Color(0xFF0077EE)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.hub_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isRu ? 'Избранное: @$_currentLogin' : 'Favorites: @$_currentLogin',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _isImporting
                                    ? (widget.isRu
                                        ? 'Импорт: $_importedCount постов...'
                                        : 'Importing: $_importedCount posts...')
                                    : (widget.isRu
                                        ? '${_posts.length} постов загружено'
                                        : '${_posts.length} posts loaded'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: widget.isRu
                              ? 'Синхронизировать черный список'
                              : 'Sync Blacklist from e621',
                          onPressed: _isSyncingBlacklist ? null : _syncBlacklist,
                          icon: _isSyncingBlacklist
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                        ),
                        const SizedBox(width: 4),
                        if (_posts.isNotEmpty || _isImporting) ...[
                          IconButton.filledTonal(
                            tooltip: widget.isRu
                                ? (_isImporting
                                    ? 'Импортируется... ($_importedCount)'
                                    : 'Импортировать все в локальное избранное')
                                : (_isImporting
                                    ? 'Importing... ($_importedCount)'
                                    : 'Import all to local favorites'),
                            onPressed: _isImporting ? null : _importAllToLocal,
                            icon: _isImporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.download_rounded, size: 18),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton.filledTonal(
                          tooltip: widget.isRu ? 'Обновить' : 'Refresh',
                          onPressed: _isLoading ? null : _loadInitial,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Content
          Expanded(
            child: _subTab == E621SubTab.favorites &&
                    (_currentLogin == null || _currentLogin!.isEmpty)
                ? _buildLoginPrompt(theme)
                : _isLoading && _posts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _posts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 40, color: Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                Text(_error!),
                                const SizedBox(height: 12),
                                FilledButton.tonal(
                                  onPressed: _loadInitial,
                                  child:
                                      Text(widget.isRu ? 'Повторить' : 'Retry'),
                                ),
                              ],
                            ),
                          )
                        : _posts.isEmpty
                            ? Center(
                                child: EmptyView(
                                  title: _subTab == E621SubTab.popular
                                      ? (widget.isRu
                                          ? 'Нет популярных постов'
                                          : 'No popular posts')
                                      : (widget.isRu
                                          ? 'У пользователя нет избранных постов'
                                          : 'No favorite posts for this user'),
                                ),
                              )
                            : ListView(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                children: [
                                  PostMasonryGrid(
                                    posts: _posts,
                                    columns: Responsive.columnsFor(
                                      context,
                                      mobileColumns:
                                          widget.settings.mobileColumns,
                                      desktopColumns:
                                          widget.settings.desktopColumns,
                                    ),
                                    blurExplicit:
                                        widget.settings.blurExplicitContent,
                                    showBadges: widget.settings.showPostBadges,
                                    nsfwEnabled: widget.settings.nsfwEnabled,
                                    mediaQualityMode: MediaQualityMode.fromName(
                                      widget.settings.mediaQualityMode,
                                    ),
                                    favoriteKeys: favoriteKeys,
                                    downloadedKeys: downloaded.keys.toSet(),
                                    onOpen: (post) => AppNavigator.openPost(
                                      context,
                                      post: post,
                                      postsList: _posts,
                                    ),
                                    onFavorite: (post) async {
                                      final isFav =
                                          favoriteKeys.contains(post.cacheKey);
                                      final favService =
                                          ref.read(favoriteServiceProvider);
                                      if (isFav) {
                                        await favService.removeFavorite(
                                            post.id, post.providerId);
                                      } else {
                                        await favService.addFavorite(post);
                                      }
                                      ref.invalidate(favoriteKeysProvider);
                                      ref.invalidate(
                                          favoritesControllerProvider);
                                    },
                                  ),
                                  if (_isLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                ],
                              ),
          ),
        ],
      ),
    );
  }
}
