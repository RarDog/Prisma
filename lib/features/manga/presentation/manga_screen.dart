import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import '../domain/manga_library_service.dart';
import '../domain/manga_library_providers.dart';
import 'manga_details_screen.dart';

enum MangaTab {
  catalog,
  library,
}

class MangaScreen extends ConsumerStatefulWidget {
  const MangaScreen({super.key});

  @override
  ConsumerState<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends ConsumerState<MangaScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  MangaTab _selectedTab = MangaTab.catalog;
  String _libraryFilter = 'all'; // 'all', 'reading', 'plan_to_read', 'completed', 'history'

  List<Post> _mangaList = [];
  List<ContentProvider> _mangaProviders = [];
  String _selectedProviderId = 'mangadex';
  String _selectedRating = 'All';
  TopPeriodFilter _selectedTopPeriod = TopPeriodFilter.none;

  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String _activeQuery = '';
  String? _errorMessage;

  Timer? _debounceTimer;
  Timer? _saveScrollDebounce;
  double _savedScrollOffset = 0.0;
  List<TagSuggestion> _suggestions = [];
  bool _checkingUpdates = false;

  Future<void> _checkLibraryUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    try {
      final libService = ref.read(mangaLibraryServiceProvider);
      final providerManager = ref.read(providerManagerProvider);

      final newCount = await libService.checkForUpdates((providerId, mangaId) async {
        final prov = await providerManager.getProviderInstance(providerId);
        final MangaChapterProvider? mangaProv =
            prov is MangaChapterProvider ? (prov as MangaChapterProvider) : null;
        final NovelChapterProvider? novelProv =
            prov is NovelChapterProvider ? (prov as NovelChapterProvider) : null;
        if (mangaProv != null) {
          final chs = await mangaProv.fetchChapters(mangaId);
          return chs is List ? chs.length : 0;
        } else if (novelProv != null) {
          final chs = await novelProv.fetchChapters(mangaId);
          return chs is List ? chs.length : 0;
        }
        return 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newCount > 0
                  ? (isRu ? 'Найдено новых глав: $newCount' : 'Found $newCount new chapters')
                  : (isRu ? 'Все главы актуальны' : 'All chapters are up to date'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка проверки: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdates = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final settings =
        ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
    _selectedRating = settings.mangaSelectedRating;
    _selectedProviderId = settings.mangaSelectedProviderId;
    _savedScrollOffset = settings.mangaScrollOffset;
    _initProvidersAndLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveScrollDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_selectedTab != MangaTab.catalog) return;
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      _saveScrollDebounce?.cancel();
      _saveScrollDebounce = Timer(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients && _selectedTab == MangaTab.catalog) {
          ref.read(settingsControllerProvider.notifier).saveMangaCatalogState(
                scrollOffset: currentOffset,
              );
        }
      });
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_loading && _hasMore && _errorMessage == null) {
        _loadManga();
      }
    }
  }

  Future<void> _initProvidersAndLoad() async {
    final providerManager = ref.read(providerManagerProvider);
    final mangaResult = await providerManager.activeMangaProviders();
    List<ContentProvider> mangaProviders =
        mangaResult is Success<List<ContentProvider>>
            ? mangaResult.data
            : <ContentProvider>[];

    if (mangaProviders.isEmpty) {
      final providersResult = await providerManager.activeProviders();
      final activeProviders = providersResult is Success<List<ContentProvider>>
          ? providersResult.data
          : <ContentProvider>[];

      mangaProviders = activeProviders.where((p) {
        return p.id == 'mangadex' ||
            p.id == 'mangalib' ||
            p.id == 'ranobelib' ||
            p is MangaDexProvider;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _mangaProviders = mangaProviders;
        if (!_mangaProviders.any((p) => p.id == _selectedProviderId) &&
            _mangaProviders.isNotEmpty) {
          _selectedProviderId = _mangaProviders.first.id;
        }
      });
      _loadManga(refresh: true);
    }
  }

  Future<void> _loadManga({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (refresh) _errorMessage = null;
    });

    if (refresh) {
      _page = 0;
      _hasMore = true;
    }

    try {
      final providerManager = ref.read(providerManagerProvider);
      final provider = await providerManager.getProviderInstance(_selectedProviderId);

      if (provider == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = 'Provider $_selectedProviderId not found';
          });
        }
        return;
      }

      final queryTags = _activeQuery.trim().isNotEmpty
          ? _activeQuery.trim().split(RegExp(r'\s+'))
          : <String>[];

      final results = await provider.searchPosts(
        tags: queryTags,
        page: _page,
        limit: 24,
        rating: _selectedRating == 'All' ? null : _selectedRating.toLowerCase(),
        topPeriod: _selectedTopPeriod,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _mangaList = results;
          } else {
            _mangaList.addAll(results);
          }
          _page++;
          _hasMore = results.isNotEmpty;
          _loading = false;
          _errorMessage = null;
        });

        if (_savedScrollOffset > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (maxScroll > 0) {
                final target = _savedScrollOffset.clamp(0.0, maxScroll);
                _scrollController.jumpTo(target);
                if (maxScroll >= _savedScrollOffset || !_hasMore) {
                  _savedScrollOffset = 0.0;
                } else if (_page < 6 && _hasMore) {
                  // Fetch additional pages if saved position was deeper
                  _loadManga();
                }
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onProviderSelected(String providerId) {
    if (_selectedProviderId == providerId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedProviderId = providerId;
      _errorMessage = null;
      _savedScrollOffset = 0.0;
    });
    ref.read(settingsControllerProvider.notifier).saveMangaCatalogState(
          providerId: providerId,
          scrollOffset: 0.0,
        );
    _loadManga(refresh: true);
  }

  void _onTopPeriodSelected(TopPeriodFilter period) {
    if (_selectedTopPeriod == period) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTopPeriod = period);
    _loadManga(refresh: true);
  }

  void _toggleRating() {
    HapticFeedback.selectionClick();
    const ratings = ['All', 'Safe', 'Suggestive', 'Erotica', 'Pornographic'];
    final idx = ratings.indexOf(_selectedRating);
    final nextIdx = (idx + 1) % ratings.length;
    final nextRating = ratings[nextIdx];
    setState(() {
      _selectedRating = nextRating;
      _savedScrollOffset = 0.0;
    });
    ref.read(settingsControllerProvider.notifier).saveMangaCatalogState(
          rating: nextRating,
          scrollOffset: 0.0,
        );
    _loadManga(refresh: true);
  }

  Color _ratingColor(String rating, ThemeData theme) {
    return switch (rating.toLowerCase()) {
      'safe' => const Color(0xFF10B981),
      'suggestive' => const Color(0xFFF59E0B),
      'erotica' => const Color(0xFFEF4444),
      'pornographic' => const Color(0xFFDC2626),
      _ => theme.colorScheme.primary,
    };
  }

  IconData _ratingIcon(String rating) {
    return switch (rating.toLowerCase()) {
      'safe' => Icons.shield_rounded,
      'suggestive' => Icons.visibility_rounded,
      'erotica' => Icons.explicit_rounded,
      'pornographic' => Icons.eighteen_up_rating_rounded,
      _ => Icons.tune_rounded,
    };
  }

  IconData _periodIcon(TopPeriodFilter period) {
    return switch (period) {
      TopPeriodFilter.none => Icons.auto_awesome_rounded,
      TopPeriodFilter.allTime => Icons.workspace_premium_rounded,
      TopPeriodFilter.year => Icons.calendar_today_rounded,
      TopPeriodFilter.month => Icons.calendar_month_rounded,
      TopPeriodFilter.week => Icons.date_range_rounded,
      TopPeriodFilter.day => Icons.today_rounded,
    };
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      if (mounted && _suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final providerManager = ref.read(providerManagerProvider);
      final provider = await providerManager.getProviderInstance(_selectedProviderId);
      final instance = provider;
      final suggestionProvider =
          instance is TagSuggestionProvider ? instance as TagSuggestionProvider : null;
      if (suggestionProvider != null && mounted) {
        try {
          final res = await suggestionProvider.suggestTags(query, limit: 12);
          if (mounted && _searchController.text.trim() == query) {
            setState(() {
              _suggestions = res;
            });
          }
        } catch (_) {}
      }
    });
  }

  IconData _suggestionIcon(TagCategory category) {
    return switch (category) {
      TagCategory.artist => Icons.person_rounded,
      TagCategory.copyright => Icons.auto_stories_rounded,
      TagCategory.character => Icons.palette_rounded,
      TagCategory.meta => Icons.style_rounded,
      TagCategory.species => Icons.warning_amber_rounded,
      TagCategory.general || TagCategory.unknown => Icons.tag_rounded,
    };
  }

  Color _suggestionColor(TagCategory category, ThemeData theme) {
    return switch (category) {
      TagCategory.artist => const Color(0xFFFF5252),
      TagCategory.copyright => const Color(0xFFBA68C8),
      TagCategory.character => const Color(0xFF66BB6A),
      TagCategory.meta => const Color(0xFFF59E0B),
      TagCategory.species => const Color(0xFFEC4899),
      TagCategory.general || TagCategory.unknown => theme.colorScheme.primary,
    };
  }

  Future<void> _openManga(Post post) async {
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      _savedScrollOffset = currentOffset;
      ref.read(settingsControllerProvider.notifier).saveMangaCatalogState(
            scrollOffset: currentOffset,
          );
    }

    final returnedTag = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MangaDetailsScreen(post: post),
      ),
    );

    if (returnedTag != null && returnedTag.isNotEmpty && mounted) {
      _debounceTimer?.cancel();
      _searchController.text = returnedTag;
      setState(() {
        _activeQuery = returnedTag;
        _suggestions = [];
        _selectedTab = MangaTab.catalog;
        _savedScrollOffset = 0.0;
      });
      _loadManga(refresh: true);
    } else if (mounted && _scrollController.hasClients && _savedScrollOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          if (maxScroll > 0) {
            _scrollController.jumpTo(_savedScrollOffset.clamp(0.0, maxScroll));
          }
        }
      });
    }
  }

  Future<void> _openLibraryEntry(MangaLibraryEntry entry) async {
    HapticFeedback.lightImpact();
    if (entry.newChaptersCount > 0) {
      ref.read(mangaLibraryServiceProvider).resetNewChapters(entry.mangaId);
    }
    Post? post;
    try {
      final providerManager = ref.read(providerManagerProvider);
      final provider = await providerManager.getProviderInstance(entry.providerId);
      if (provider != null) {
        post = await provider.getPost(entry.mangaId);
      }
    } catch (_) {}

    final providerDisplayName = switch (entry.providerId) {
      'mangadex' => 'MangaDex',
      'mangalib' => 'MangaLib',
      'ranobelib' => 'RanobeLib',
      _ => entry.providerId,
    };

    post ??= Post(
      id: entry.mangaId,
      providerId: entry.providerId,
      providerName: providerDisplayName,
      previewUrl: entry.coverUrl,
      sampleUrl: entry.coverUrl,
      fileUrl: entry.coverUrl,
      tags: [entry.title],
      rating: 'g',
      width: 700,
      height: 1000,
      source: entry.providerId == 'mangadex'
          ? 'https://mangadex.org/title/${entry.mangaId}'
          : (entry.providerId == 'mangalib'
              ? 'https://mangalib.me/ru/${entry.mangaId}'
              : 'https://ranobelib.me/ru/${entry.mangaId}'),
      createdAt: entry.addedAt,
      fileType: 'jpg',
      score: 0,
      tagGroups: {
        'copyright': [entry.title],
        'is_comic': ['true'],
        'media_type': [entry.providerId == 'ranobelib' ? 'novel' : 'manga'],
      },
    );

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MangaDetailsScreen(post: post!),
        ),
      );
    }
  }

  void _showLibraryEntryOptions(MangaLibraryEntry entry) {
    HapticFeedback.mediumImpact();
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.auto_stories_rounded, color: Color(0xFFFF6740)),
                  title: Text(isRu ? 'Читаю' : 'Reading'),
                  selected: entry.status == 'reading',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(mangaLibraryServiceProvider).setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'reading',
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_added_rounded, color: Color(0xFF3B82F6)),
                  title: Text(isRu ? 'В планах' : 'Plan to read'),
                  selected: entry.status == 'plan_to_read',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(mangaLibraryServiceProvider).setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'plan_to_read',
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
                  title: Text(isRu ? 'Прочитано' : 'Completed'),
                  selected: entry.status == 'completed',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(mangaLibraryServiceProvider).setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'completed',
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                  title: Text(isRu ? 'Брошено' : 'Dropped'),
                  selected: entry.status == 'dropped',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(mangaLibraryServiceProvider).setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'dropped',
                        );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  title: Text(
                    isRu ? 'Удалить из библиотеки' : 'Remove from library',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(mangaLibraryServiceProvider).removeLibraryEntry(entry.mangaId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isRu ? 'Удалено из библиотеки' : 'Removed from library'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AppBar(
              backgroundColor: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab Switcher (Каталог / Библиотека)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tabButton(
                          title: isRu ? 'Каталог' : 'Catalog',
                          icon: Icons.explore_rounded,
                          isSelected: _selectedTab == MangaTab.catalog,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = MangaTab.catalog);
                          },
                        ),
                        _tabButton(
                          title: isRu ? 'Библиотека' : 'Library',
                          icon: Icons.bookmarks_rounded,
                          isSelected: _selectedTab == MangaTab.library,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = MangaTab.library);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (_selectedTab == MangaTab.catalog) ...[
                  // Compact rating toggle button
                  Center(
                    child: InkWell(
                      onTap: _toggleRating,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _ratingColor(_selectedRating, theme).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedRating == 'All'
                                ? (isDark ? Colors.white24 : Colors.black12)
                                : _ratingColor(_selectedRating, theme).withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _ratingIcon(_selectedRating),
                              size: 13,
                              color: _ratingColor(_selectedRating, theme),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedRating,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _selectedRating == 'All'
                                    ? theme.colorScheme.onSurfaceVariant
                                    : _ratingColor(_selectedRating, theme),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: isRu ? 'Обновить' : 'Refresh',
                    onPressed: () => _loadManga(refresh: true),
                  ),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: _selectedTab == MangaTab.catalog
          ? _buildCatalogView(context, theme, isDark, isRu)
          : _buildLibraryView(context, theme, isDark, isRu),
    );
  }

  Widget _tabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6740) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogView(BuildContext context, ThemeData theme, bool isDark, bool isRu) {
    return CustomScrollView(
      key: const PageStorageKey<String>('manga_catalog_scroll_view'),
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 68,
              16,
              6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (val) {
                    _debounceTimer?.cancel();
                    setState(() {
                      _activeQuery = val;
                      _suggestions = [];
                    });
                    _loadManga(refresh: true);
                  },
                  decoration: InputDecoration(
                    hintText: isRu
                        ? 'Поиск манги, автора или тега...'
                        : 'Search manga, artist or tag...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty || _activeQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              setState(() {
                                _activeQuery = '';
                                _suggestions = [];
                              });
                              _loadManga(refresh: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          avatar: Icon(
                            _suggestionIcon(suggestion.category),
                            size: 15,
                            color: _suggestionColor(suggestion.category, theme),
                          ),
                          label: Text(
                            suggestion.name.startsWith('author:')
                                ? suggestion.name.substring(7)
                                : suggestion.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.black87,
                            ),
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: _suggestionColor(suggestion.category, theme)
                                .withValues(alpha: 0.35),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _debounceTimer?.cancel();
                            _searchController.text = suggestion.name;
                            setState(() {
                              _activeQuery = suggestion.name;
                              _suggestions = [];
                            });
                            _loadManga(refresh: true);
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                if (_mangaProviders.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mangaProviders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final provider = _mangaProviders[index];
                        final isSelected = provider.id == _selectedProviderId;
                        final Color brandColor = switch (provider.id) {
                          'mangadex' => const Color(0xFFFF6740),
                          'mangalib' => const Color(0xFF2563EB),
                          'ranobelib' => const Color(0xFF10B981),
                          _ => theme.colorScheme.primary,
                        };

                        final IconData icon = switch (provider.id) {
                          'mangadex' => Icons.auto_stories_rounded,
                          'mangalib' => Icons.menu_book_rounded,
                          'ranobelib' => Icons.article_rounded,
                          _ => Icons.hub_rounded,
                        };

                        return InkWell(
                          onTap: () => _onProviderSelected(provider.id),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandColor.withValues(alpha: 0.18)
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? brandColor : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 16, color: isSelected ? brandColor : theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  provider.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? brandColor : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                // Top periods filter chips
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final period in TopPeriodFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            avatar: Icon(
                              _periodIcon(period),
                              size: 14,
                              color: _selectedTopPeriod == period
                                  ? (isDark ? Colors.black87 : Colors.white)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            label: Text(
                              switch (period) {
                                TopPeriodFilter.none => isRu ? 'Свежее' : 'Recent',
                                TopPeriodFilter.allTime => isRu ? 'Топ за все время' : 'All-time Top',
                                TopPeriodFilter.year => isRu ? 'Топ за год' : 'Year Top',
                                TopPeriodFilter.month => isRu ? 'Топ за месяц' : 'Month Top',
                                TopPeriodFilter.week => isRu ? 'Топ за неделю' : 'Week Top',
                                TopPeriodFilter.day => isRu ? 'Топ за день' : 'Day Top',
                              },
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            selected: _selectedTopPeriod == period,
                            onSelected: (_) => _onTopPeriodSelected(period),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_errorMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _loadManga(refresh: true),
                      child: Text(isRu ? 'Повторить' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_mangaList.isEmpty && !_loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      isRu ? 'Ничего не найдено' : 'No manga found',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = _mangaList[index];
                  return _MangaCard(
                    post: post,
                    onTap: () => _openManga(post),
                  );
                },
                childCount: _mangaList.length,
              ),
            ),
          ),

        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6740))),
            ),
          ),

        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
        ),
      ],
    );
  }

  Widget _buildLibraryView(BuildContext context, ThemeData theme, bool isDark, bool isRu) {
    final AsyncValue<List<MangaLibraryEntry>> entriesAsync = _libraryFilter == 'history'
        ? ref.watch(mangaReadingHistoryProvider)
        : ref.watch(mangaLibraryEntriesProvider(_libraryFilter == 'all' ? null : _libraryFilter));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 68,
              16,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter pills & sync button
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _libraryFilterChip(
                              keyName: 'all',
                              label: isRu ? 'Все сохранённые' : 'All Saved',
                              icon: Icons.bookmarks_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'reading',
                              label: isRu ? 'Читаю' : 'Reading',
                              icon: Icons.auto_stories_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'plan_to_read',
                              label: isRu ? 'В планах' : 'Plan to read',
                              icon: Icons.bookmark_added_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'completed',
                              label: isRu ? 'Прочитано' : 'Completed',
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'history',
                              label: isRu ? '⏱ История чтения' : '⏱ History',
                              icon: Icons.history_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _checkingUpdates ? null : _checkLibraryUpdates,
                      tooltip: isRu ? 'Проверить обновления глав' : 'Check for new chapters',
                      icon: _checkingUpdates
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        entriesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6740))),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Ошибка загрузки библиотеки: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          _libraryFilter == 'history' ? Icons.history_toggle_off_rounded : Icons.bookmark_border_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _libraryFilter == 'history'
                              ? (isRu ? 'История чтения пуста' : 'Reading history is empty')
                              : (isRu ? 'В библиотеке пока пусто' : 'Your library is empty'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _libraryFilter == 'history'
                              ? (isRu ? 'Начните читать мангу в каталоге, и она появится здесь!' : 'Read any manga to see it here!')
                              : (isRu ? 'Нажмите кнопку закладки на странице манги, чтобы добавить её сюда.' : 'Bookmark manga from details screen to save it here.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    return _MangaLibraryCard(
                      entry: entry,
                      onTap: () => _openLibraryEntry(entry),
                      onLongPress: () => _showLibraryEntryOptions(entry),
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            );
          },
        ),

        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
        ),
      ],
    );
  }

  Widget _libraryFilterChip({
    required String keyName,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _libraryFilter == keyName;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 15,
          color: isSelected ? Colors.white : Colors.white70,
        ),
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFF6740),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _libraryFilter = keyName);
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _MangaLibraryCard extends StatelessWidget {
  const _MangaLibraryCard({
    required this.entry,
    required this.onTap,
    this.onLongPress,
  });

  final MangaLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  Color _statusColor(String status) {
    return switch (status) {
      'reading' => const Color(0xFFFF6740),
      'plan_to_read' => const Color(0xFF3B82F6),
      'completed' => const Color(0xFF10B981),
      'dropped' => const Color(0xFFEF4444),
      _ => const Color(0xFFFF6740),
    };
  }

  String _statusLabel(String status, bool isRu) {
    return switch (status) {
      'reading' => isRu ? 'Читаю' : 'Reading',
      'plan_to_read' => isRu ? 'В планах' : 'Plan',
      'completed' => isRu ? 'Прочитано' : 'Done',
      'dropped' => isRu ? 'Брошено' : 'Dropped',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final prog = entry.progress;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  entry.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: entry.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.white10),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.white10,
                            child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                          ),
                        )
                      : Container(
                          color: Colors.white10,
                          child: const Icon(Icons.auto_stories_rounded, color: Colors.white38),
                        ),

                  // Status badge at top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(entry.status).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(entry.status, isRu),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // New chapters badge at top left
                  if (entry.newChaptersCount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.new_releases_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '+${entry.newChaptersCount} ${isRu ? 'новых' : 'new'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Reading progress bar at bottom of cover
                  if (prog != null && prog.totalPages > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: ((prog.pageIndex + 1) / prog.totalPages).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.black45,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6740)),
                      ),
                    ),
                ],
              ),
            ),

            // Title & Progress details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  if (prog != null)
                    Text(
                      '${isRu ? 'Гл.' : 'Ch.'} ${prog.chapterNumber} • ${isRu ? 'стр.' : 'p.'} ${prog.pageIndex + 1}/${prog.totalPages}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6740),
                      ),
                    )
                  else
                    Text(
                      switch (entry.providerId) {
                        'mangadex' => 'MangaDex',
                        'mangalib' => 'MangaLib',
                        'ranobelib' => 'RanobeLib',
                        _ => entry.providerId,
                      },
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaCard extends StatelessWidget {
  const _MangaCard({
    required this.post,
    required this.onTap,
  });

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headers = getPostMediaHeaders(post);

    final title = post.title ?? post.tags.take(3).join(', ');
    final artist = post.tagGroups['artist']?.firstOrNull ??
        post.tagGroups['author']?.firstOrNull;
    final pageCount = post.tagGroups['page_count']?.firstOrNull ??
        (post.childrenIds.isNotEmpty ? '${post.childrenIds.length}' : null);
    final language = post.tagGroups['language']?.firstOrNull;
    final rating = post.tagGroups['content_rating']?.firstOrNull;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl,
                    httpHeaders: headers,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6740)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      child: const Icon(Icons.broken_image_rounded, size: 32),
                    ),
                  ),

                  // Top badges: Pages & Language / Rating
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (pageCount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.70),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_rounded, color: Colors.white, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  '${pageCount}P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rating.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        if (language != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFED2553).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              language.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Title & Author info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (artist != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
