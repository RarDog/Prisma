import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/sources/manga/mangadex_provider.dart';
import '../domain/manga_library_service.dart';
import '../domain/manga_library_providers.dart';
import 'manga_details_screen.dart';
import 'widgets/manga_catalog_view.dart';
import 'widgets/manga_library_view.dart';
import 'widgets/manga_screen_app_bar.dart';

export 'widgets/manga_screen_app_bar.dart';

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
  String _libraryFilter =
      'all'; // 'all', 'reading', 'plan_to_read', 'completed', 'history'

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

      final newCount =
          await libService.checkForUpdates((providerId, mangaId) async {
        final prov = await providerManager.getProviderInstance(providerId);
        final MangaChapterProvider? mangaProv = prov is MangaChapterProvider
            ? (prov as MangaChapterProvider)
            : null;
        final NovelChapterProvider? novelProv = prov is NovelChapterProvider
            ? (prov as NovelChapterProvider)
            : null;
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
                  ? (isRu
                      ? 'Найдено новых глав: $newCount'
                      : 'Found $newCount new chapters')
                  : (isRu
                      ? 'Все главы актуальны'
                      : 'All chapters are up to date'),
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
      unawaited(_loadManga(refresh: true));
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
      final provider =
          await providerManager.getProviderInstance(_selectedProviderId);

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
      final provider =
          await providerManager.getProviderInstance(_selectedProviderId);
      final instance = provider;
      final suggestionProvider = instance is TagSuggestionProvider
          ? instance as TagSuggestionProvider
          : null;
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

  Future<void> _openManga(Post post) async {
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      _savedScrollOffset = currentOffset;
      unawaited(
          ref.read(settingsControllerProvider.notifier).saveMangaCatalogState(
                scrollOffset: currentOffset,
              ));
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
      unawaited(_loadManga(refresh: true));
    } else if (mounted &&
        _scrollController.hasClients &&
        _savedScrollOffset > 0) {
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
    unawaited(HapticFeedback.lightImpact());
    if (entry.newChaptersCount > 0) {
      unawaited(ref
          .read(mangaLibraryServiceProvider)
          .resetNewChapters(entry.mangaId));
    }
    Post? post;
    try {
      final providerManager = ref.read(providerManagerProvider);
      final provider =
          await providerManager.getProviderInstance(entry.providerId);
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.auto_stories_rounded,
                      color: Color(0xFFFF6740)),
                  title: Text(isRu ? 'Читаю' : 'Reading'),
                  selected: entry.status == 'reading',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(mangaLibraryServiceProvider)
                        .setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'reading',
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_added_rounded,
                      color: Color(0xFF3B82F6)),
                  title: Text(isRu ? 'В планах' : 'Plan to read'),
                  selected: entry.status == 'plan_to_read',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(mangaLibraryServiceProvider)
                        .setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'plan_to_read',
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF10B981)),
                  title: Text(isRu ? 'Прочитано' : 'Completed'),
                  selected: entry.status == 'completed',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(mangaLibraryServiceProvider)
                        .setLibraryStatus(
                          mangaId: entry.mangaId,
                          providerId: entry.providerId,
                          title: entry.title,
                          coverUrl: entry.coverUrl,
                          status: 'completed',
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined,
                      color: Color(0xFFEF4444)),
                  title: Text(isRu ? 'Брошено' : 'Dropped'),
                  selected: entry.status == 'dropped',
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(mangaLibraryServiceProvider)
                        .setLibraryStatus(
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
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444)),
                  title: Text(
                    isRu ? 'Удалить из библиотеки' : 'Remove from library',
                    style: const TextStyle(color: Color(0xFFEF4444)),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(mangaLibraryServiceProvider)
                        .removeLibraryEntry(entry.mangaId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isRu
                              ? 'Удалено из библиотеки'
                              : 'Removed from library'),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: MangaScreenAppBar(
        selectedTab: _selectedTab,
        onTabChanged: (tab) => setState(() => _selectedTab = tab),
        selectedRating: _selectedRating,
        onToggleRating: _toggleRating,
        onRefreshCatalog: () => _loadManga(refresh: true),
      ),
      body: _selectedTab == MangaTab.catalog
          ? MangaCatalogView(
              scrollController: _scrollController,
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: (val) {
                _debounceTimer?.cancel();
                setState(() {
                  _activeQuery = val;
                  _suggestions = [];
                });
                _loadManga(refresh: true);
              },
              onClearSearch: () {
                _debounceTimer?.cancel();
                _searchController.clear();
                setState(() {
                  _activeQuery = '';
                  _suggestions = [];
                });
                _loadManga(refresh: true);
              },
              activeQuery: _activeQuery,
              suggestions: _suggestions,
              onSuggestionSelected: (suggestion) {
                _debounceTimer?.cancel();
                _searchController.text = suggestion.name;
                setState(() {
                  _activeQuery = suggestion.name;
                  _suggestions = [];
                });
                _loadManga(refresh: true);
              },
              mangaProviders: _mangaProviders,
              selectedProviderId: _selectedProviderId,
              onProviderSelected: _onProviderSelected,
              selectedTopPeriod: _selectedTopPeriod,
              onTopPeriodSelected: _onTopPeriodSelected,
              errorMessage: _errorMessage,
              onRetry: () => _loadManga(refresh: true),
              mangaList: _mangaList,
              loading: _loading,
              onOpenManga: _openManga,
            )
          : MangaLibraryView(
              libraryFilter: _libraryFilter,
              onFilterSelected: (keyName) =>
                  setState(() => _libraryFilter = keyName),
              checkingUpdates: _checkingUpdates,
              onCheckUpdates: _checkLibraryUpdates,
              onOpenEntry: _openLibraryEntry,
              onShowEntryOptions: _showLibraryEntryOptions,
            ),
    );
  }
}
