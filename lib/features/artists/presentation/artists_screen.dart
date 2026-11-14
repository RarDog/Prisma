import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'package:gel_rule_app/shared/widgets/provider_health_banner.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';
import 'widgets/artist_service_utils.dart';
import 'widgets/artists_catalog_view.dart';
import 'widgets/artists_favorites_empty.dart';
import 'widgets/artists_favorites_view.dart';
import 'widgets/artists_header.dart';
import 'widgets/artists_page_bar.dart';
import 'widgets/artists_page_picker_sheet.dart';
import 'widgets/pawchive/pawchive_accounts_sheet.dart';

export 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';
export 'widgets/artist_card.dart';
export 'widgets/artist_service_utils.dart';
export 'widgets/artists_filter_sheet.dart';
export 'widgets/artists_header.dart';
export 'widgets/artists_liquid_card.dart';
export 'widgets/pawchive/pawchive_accounts_sheet.dart';

/// Marker from `FapelloProvider`'s `ProviderUnavailableException`, used to
/// replace the raw error with an explanation of the block.
const _cloudflareChallengeHint = 'Cloudflare challenge';

final artistProviderConfigsProvider =
    FutureProvider<List<ContentProviderConfig>>((ref) async {
  final result = await ref
      .watch(providerManagerProvider)
      .loadArtistConfigs(enabledOnly: true);
  if (result is! Success<List<ContentProviderConfig>>) return const [];
  return result.data
      .where((c) {
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
          return c.id != 'fapello' && c.apiType != 'fapello';
        }
        return true;
      })
      .toList();
});

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _selectedServices = <String>{};
  ArtistsTab _currentTab = ArtistsTab.all;
  ArtistSortOrder _sortOrder = ArtistSortOrder.popularityDesc;
  String? _providerId;
  var _page = 1;
  int? _totalArtistsCount;
  int? _totalPages;
  var _loading = false;
  var _hasMore = true;
  var _initialLoaded = false;
  Object? _error;
  static const _pageSize = 30;
  final List<ArtistProfile> _loadedArtists = <ArtistProfile>[];
  List<ArtistProfile> _artists = const [];

  void _openPagePicker() {
    ArtistsPagePickerSheet.show(
      context,
      currentPage: _page,
      totalPages: _totalPages,
      isRu: Localizations.maybeLocaleOf(context)?.languageCode == 'ru',
      onPageSelected: (p) => _loadPage(page: p),
    );
  }

  Future<void> _toggleFavoriteArtist(
    AppSettings settings,
    ArtistProfile artist,
  ) async {
    final current = List<String>.from(settings.favoriteArtists);
    final item = FavoriteArtistItem(
      id: artist.id,
      service: artist.service,
      providerId: artist.providerId,
      name: artist.displayName,
      avatarUrl: artist.avatarUrl,
      bannerUrl: artist.bannerUrl,
      postCount: artist.postCount,
      updatedAt: artist.updatedAt,
    );
    final key = item.key;
    final index = current.indexWhere((e) {
      try {
        final parsed =
            FavoriteArtistItem.fromJson(jsonDecode(e) as Map<String, dynamic>);
        return parsed.key == key;
      } catch (_) {
        return false;
      }
    });
    final isAdding = index < 0;
    if (!isAdding) {
      current.removeAt(index);
    } else {
      current.insert(0, jsonEncode(item.toJson()));
    }
    await ref.read(settingsControllerProvider.notifier).saveSettings(
          settings.copyWith(favoriteArtists: current),
        );

    // Sync with active Pawchive account if available
    if (artist.service.isNotEmpty && artist.id.isNotEmpty) {
      final activeAcc = settings.activePawchiveAccount;
      if (activeAcc != null) {
        unawaited(ref.read(pawchiveSyncServiceProvider).toggleRemoteFavorite(
              account: activeAcc,
              service: artist.service,
              artistId: artist.id,
              isFavorite: isAdding,
            ));
      }
    }
  }

  bool _isEnrichingFavorites = false;
  Future<void> _enrichFavorites(List<FavoriteArtistItem> favorites) async {
    if (_isEnrichingFavorites || favorites.isEmpty || !mounted) return;
    _isEnrichingFavorites = true;
    try {
      final manager = ref.read(providerManagerProvider);
      final providers = await manager.activeArtistProviders();
      if (providers is! Success<List<ArtistProvider>>) return;
      ArtistProvider? provider;
      for (final item in providers.data) {
        if ((item as ContentProvider).id == _providerId) {
          provider = item;
          break;
        }
      }
      if (provider == null) return;

      bool changed = false;
      final updatedList = <FavoriteArtistItem>[];
      for (final fav in favorites) {
        final profile = await provider.getArtistProfile(fav.service, fav.id);
        if (profile != null &&
            (profile.postCount != fav.postCount ||
                profile.updatedAt != fav.updatedAt ||
                (fav.avatarUrl == null && profile.avatarUrl != null))) {
          updatedList.add(fav.copyWith(
            postCount: profile.postCount,
            updatedAt: profile.updatedAt,
            avatarUrl: profile.avatarUrl ?? fav.avatarUrl,
          ));
          changed = true;
        } else {
          updatedList.add(fav);
        }
      }

      if (changed && mounted) {
        final currentSettings =
            ref.read(appSettingsProvider).value ?? AppSettings.defaults;
        final updatedJson =
            updatedList.map((e) => jsonEncode(e.toJson())).toList();
        await ref.read(settingsControllerProvider.notifier).saveSettings(
              currentSettings.copyWith(favoriteArtists: updatedJson),
            );
      }
    } catch (_) {
      // Ignore enrichment errors (e.g. offline)
    } finally {
      _isEnrichingFavorites = false;
    }
  }

  void _triggerFavoritesEnrichment() {
    final settings = ref.read(appSettingsProvider).value;
    if (settings == null || settings.favoriteArtists.isEmpty) return;
    final favItems = settings.favoriteArtists
        .map((e) {
          try {
            return FavoriteArtistItem.fromJson(
                jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoriteArtistItem>()
        .toList();
    if (favItems.isNotEmpty) {
      unawaited(_enrichFavorites(favItems));
    }
  }

  final _headerVisible = ValueNotifier<bool>(true);
  double _lastScrollOffset = 0;
  double _scrollDeltaAccumulator = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_currentTab == ArtistsTab.favorites) {
        setState(() {});
      }
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scroll.offset;
    final autoHide =
        ref.read(appSettingsProvider).value?.autoHideFeedToolbar ?? true;

    if (autoHide) {
      if (offset <= 60) {
        _scrollDeltaAccumulator = 0;
        if (!_headerVisible.value) _headerVisible.value = true;
      } else {
        final delta = offset - _lastScrollOffset;
        if ((delta > 0 && _scrollDeltaAccumulator < 0) ||
            (delta < 0 && _scrollDeltaAccumulator > 0)) {
          _scrollDeltaAccumulator = 0;
        }
        _scrollDeltaAccumulator += delta;

        if (_scrollDeltaAccumulator > 55) {
          if (_headerVisible.value) _headerVisible.value = false;
        } else if (_scrollDeltaAccumulator < -30) {
          if (!_headerVisible.value) _headerVisible.value = true;
        }
      }
    }
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _headerVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configs = ref.watch(artistProviderConfigsProvider);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final favoriteItems = settings.favoriteArtists
        .map((e) {
          try {
            return FavoriteArtistItem.fromJson(
                jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoriteArtistItem>()
        .toList();
    final favoriteKeys = favoriteItems.map((e) => e.key).toSet();

    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return AdaptiveScaffold(
      title: isRu ? 'Авторы' : 'Artists',
      titleWidget: _ArtistsTitle(
        headerVisible: _headerVisible,
        onToggle: () {
          HapticFeedback.lightImpact();
          _headerVisible.value = !_headerVisible.value;
        },
      ),
      resizeToAvoidBottomInset: false,
      actions: [
        IconButton(
          tooltip: isRu ? 'Синхронизация Pawchive' : 'Pawchive sync',
          icon: Badge(
            isLabelVisible: settings.parsedPawchiveAccounts.isNotEmpty,
            backgroundColor: Colors.green,
            smallSize: 8,
            child: const Icon(Icons.cloud_sync_rounded),
          ),
          onPressed: () => PawchiveAccountsSheet.show(context),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _refresh(configs.valueOrNull ?? const []),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: configs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              title: 'No artist providers',
              message:
                  'Enable an artist provider (such as Pawchive) in Providers.',
            );
          }
          _providerId ??= items.first.id;
          if (!_initialLoaded && !_loading && _error == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _refresh(items));
          }
          final displayedArtists = _artists;

          final loadedLookup = <String, ArtistProfile>{
            for (final a in _loadedArtists)
              '${a.service.toLowerCase()}:${a.id.toLowerCase()}': a,
          };
          final enrichedFavorites = favoriteItems.map((fav) {
            final key = '${fav.service.toLowerCase()}:${fav.id.toLowerCase()}';
            final matched = loadedLookup[key];
            if (matched != null &&
                (fav.postCount == null || fav.updatedAt == null)) {
              return fav.copyWith(
                postCount: fav.postCount ?? matched.postCount,
                updatedAt: fav.updatedAt ?? matched.updatedAt,
                avatarUrl: fav.avatarUrl ?? matched.avatarUrl,
              );
            }
            return fav;
          }).toList();

          final searchQuery = _search.text.trim().toLowerCase();
          final displayedFavorites = enrichedFavorites.where((fav) {
            final s = fav.service.toLowerCase();
            if (_selectedServices.isNotEmpty &&
                !_selectedServices.contains(s)) {
              return false;
            }
            if (searchQuery.isNotEmpty &&
                !fav.name.toLowerCase().contains(searchQuery)) {
              return false;
            }
            return true;
          }).toList();

          switch (_sortOrder) {
            case ArtistSortOrder.recentPosts:
              displayedFavorites.sort((a, b) {
                final dateA = a.updatedAt;
                final dateB = b.updatedAt;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });
              break;
            case ArtistSortOrder.oldestPosts:
              displayedFavorites.sort((a, b) {
                final dateA = a.updatedAt;
                final dateB = b.updatedAt;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateA.compareTo(dateB);
              });
              break;
            case ArtistSortOrder.postsDesc:
              displayedFavorites.sort((a, b) {
                final countA = a.postCount;
                final countB = b.postCount;
                if (countA == null && countB == null) return 0;
                if (countA == null) return 1;
                if (countB == null) return -1;
                return countB.compareTo(countA);
              });
              break;
            case ArtistSortOrder.postsAsc:
              displayedFavorites.sort((a, b) {
                final countA = a.postCount;
                final countB = b.postCount;
                if (countA == null && countB == null) return 0;
                if (countA == null) return 1;
                if (countB == null) return -1;
                return countA.compareTo(countB);
              });
              break;
            case ArtistSortOrder.nameAsc:
              displayedFavorites.sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              break;
            case ArtistSortOrder.popularityDesc:
            case ArtistSortOrder.topFollowers:
            case ArtistSortOrder.trending:
            case ArtistSortOrder.dailyRanking:
              displayedFavorites.sort((a, b) {
                final countA = a.postCount ?? -1;
                final countB = b.postCount ?? -1;
                return countB.compareTo(countA);
              });
              break;
          }

          return Column(
            children: [
              const ProviderHealthBanner(),
              ValueListenableBuilder<bool>(
                valueListenable: _headerVisible,
                builder: (context, visible, child) {
                  return AnimatedCrossFade(
                    firstChild: child!,
                    secondChild: const SizedBox.shrink(),
                    crossFadeState: visible
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeInOutCubic,
                  );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < -180) {
                      HapticFeedback.lightImpact();
                      _headerVisible.value = false;
                    }
                  },
                  child: ArtistsHeader(
                    currentTab: _currentTab,
                    onTabChanged: (tab) {
                      setState(() => _currentTab = tab);
                      if (tab == ArtistsTab.favorites) {
                        _triggerFavoritesEnrichment();
                      }
                    },
                    favoritesCount: favoriteItems.length,
                    searchController: _search,
                    providers: items,
                    selectedProviderId: _providerId,
                    selectedServices: _selectedServices,
                    selectedSort: _sortOrder,
                    currentPage: _page,
                    totalPages: _totalPages,
                    onOpenPagePicker: _openPagePicker,
                    isRu: isRu,
                    onProviderChanged: (value) {
                      setState(() {
                        _providerId = value;
                        _selectedServices.clear();
                        final supported =
                            ArtistSortOrder.supportedFor(_providerId);
                        if (!supported.contains(_sortOrder)) {
                          _sortOrder = ArtistSortOrder.popularityDesc;
                        }
                      });
                      _refresh(items);
                    },
                    onSortChanged: (sort) {
                      setState(() => _sortOrder = sort);
                      if (_currentTab == ArtistsTab.all) {
                        _refresh(items);
                      }
                    },
                    onToggleService: (service) {
                      setState(() {
                        if (_selectedServices.contains(service)) {
                          _selectedServices.remove(service);
                        } else {
                          _selectedServices.add(service);
                        }
                      });
                      if (_currentTab == ArtistsTab.all) {
                        _refresh(items);
                      }
                    },
                    onClearServices: () {
                      setState(() => _selectedServices.clear());
                      if (_currentTab == ArtistsTab.all) {
                        _refresh(items);
                      }
                    },
                    onSearch: () {
                      if (_currentTab == ArtistsTab.all) {
                        _refresh(items);
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: _currentTab == ArtistsTab.favorites
                    ? (displayedFavorites.isEmpty
                        ? ArtistsFavoritesEmpty(
                            hasAnyFavorites: favoriteItems.isEmpty,
                            hasActiveFilters: _selectedServices.isNotEmpty ||
                                _search.text.isNotEmpty,
                            isRu: isRu,
                            onBrowseCatalog: () =>
                                setState(() => _currentTab = ArtistsTab.all),
                            onResetFilters: () {
                              setState(() {
                                _selectedServices.clear();
                                _search.clear();
                              });
                            },
                          )
                        : ArtistsFavoritesView(
                            favorites: displayedFavorites,
                            scrollController: _scroll,
                            onRemove: (fav) =>
                                _removeFavoriteItem(settings, fav),
                          ))
                    : (_error != null
                        ? ErrorView(
                            message: _friendlyArtistError(_error),
                            onRetry: () => _refresh(items),
                          )
                        : ArtistsCatalogView(
                            artists: displayedArtists,
                            favoriteKeys: favoriteKeys,
                            loading: _loading,
                            showFiltersEmptyState:
                                displayedArtists.isEmpty && !_loading,
                            scrollController: _scroll,
                            onToggleFavorite: (artist) =>
                                _toggleFavoriteArtist(settings, artist),
                            onShowAllServices: () {
                              setState(() => _selectedServices.clear());
                              _refresh(items);
                            },
                            // The interactive page bar lives at the end of the list,
                            // under the last artist.
                            footer: ArtistsPageBar(
                              page: _page,
                              totalPages: _totalPages,
                              canGoBack: _page > 1 && !_loading,
                              canGoForward: _hasMore && !_loading,
                              isRu: isRu,
                              onPageSelected: (p) => _loadPage(page: p),
                            ),
                          )),
              ),
            ],
          );
        },
      ),
    );
  }

  String _friendlyArtistError(Object? error) {
    final message = error.toString();
    if (message.contains(_cloudflareChallengeHint)) {
      return 'Fapello blocks automated requests with a Cloudflare challenge, '
          'so its pages cannot be read from the app. Enable another artist '
          'provider in Providers.';
    }
    if (message.contains('HandshakeException') ||
        message.contains('artist works are unavailable')) {
      return 'Artist API is unavailable right now. Try refresh or another provider.';
    }
    return message;
  }

  bool _matchesDisplayFilters(ArtistProfile a) {
    final s = a.service.toLowerCase();
    if (_providerId == 'fapello' || s == 'fapello') {
      if (_selectedServices.isEmpty) return true;
      return _selectedServices.contains('fapello');
    }
    if (s != 'patreon' && s != 'fanbox') return false;
    if (_selectedServices.isEmpty) return true;
    return _selectedServices.contains(s);
  }

  Future<void> _refresh(List<ContentProviderConfig> configs) async {
    if (configs.isEmpty) return;
    setState(() {
      _page = 1;
      _hasMore = true;
      _initialLoaded = false;
      _totalArtistsCount = null;
      _totalPages = null;
      _loadedArtists.clear();
      _artists = const [];
      _error = null;
    });
    await _loadPage(page: 1);
  }

  Future<void> _loadPage({int? page}) async {
    if (_loading || _providerId == null) return;
    final target = (page ?? _page).clamp(1, _totalPages ?? 999999);
    setState(() {
      _loading = true;
      _page = target;
      _error = null;
    });
    // A new page starts at the top of the list, not mid-scroll.
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    try {
      final manager = ref.read(providerManagerProvider);
      final providers = await manager.activeArtistProviders();
      if (providers is! Success<List<ArtistProvider>>) return;
      ArtistProvider? provider;
      for (final item in providers.data) {
        if ((item as ContentProvider).id == _providerId) {
          provider = item;
          break;
        }
      }
      if (provider == null) return;

      // Update total artists count if not yet known
      if (_totalArtistsCount == null) {
        final count = await provider.getArtistsCount(
          services:
              _selectedServices.isEmpty ? null : _selectedServices.toList(),
          query: _search.text.trim(),
        );
        if (mounted && count != null) {
          setState(() {
            _totalArtistsCount = count;
            _totalPages = (count / _pageSize).ceil();
          });
        }
      }

      final pageResults = await provider.searchArtists(
        _search.text.trim(),
        services:
            _selectedServices.isEmpty ? null : _selectedServices.toList(),
        sort: _sortOrder,
        page: target,
        limit: _pageSize,
      );
      if (!mounted) return;

      final filtered = pageResults.where(_matchesDisplayFilters).toList();
      _loadedArtists.addAll(filtered);

      setState(() {
        _artists = filtered;
        _hasMore = _totalPages != null
            ? target < _totalPages!
            : pageResults.length >= _pageSize;
        _initialLoaded = true;
      });
      _triggerFavoritesEnrichment();
    } catch (error) {
      if (!mounted) return;
      if (_artists.isEmpty && target == 1) {
        // Initial load failed — surface a full-screen error with retry.
        setState(() => _error = error);
      } else {
        // Page flip failed — keep whatever is on screen, notify in place.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.maybeLocaleOf(context)?.languageCode == 'ru'
                  ? 'Не удалось загрузить страницу'
                  : 'Failed to load the page',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFavoriteItem(
    AppSettings settings,
    FavoriteArtistItem fav,
  ) async {
    final updated = List<String>.from(settings.favoriteArtists)
      ..removeWhere((e) {
        try {
          return FavoriteArtistItem.fromJson(
                      jsonDecode(e) as Map<String, dynamic>)
                  .key ==
              fav.key;
        } catch (_) {
          return false;
        }
      });
    await ref
        .read(settingsControllerProvider.notifier)
        .saveSettings(settings.copyWith(favoriteArtists: updated));

    if (fav.providerId == 'pawchive') {
      final activeAcc = settings.activePawchiveAccount;
      if (activeAcc != null) {
        unawaited(
          ref.read(pawchiveSyncServiceProvider).toggleRemoteFavorite(
                account: activeAcc,
                service: fav.service,
                artistId: fav.id,
                isFavorite: false,
              ),
        );
      }
    }
  }
}

class _ArtistsTitle extends StatelessWidget {
  const _ArtistsTitle({
    required this.headerVisible,
    required this.onToggle,
  });

  final ValueNotifier<bool> headerVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Prisma',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isRu ? 'Авторы' : 'Artists',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<bool>(
                valueListenable: headerVisible,
                builder: (context, visible, _) {
                  return Tooltip(
                    message: visible
                        ? (isRu ? 'Свернуть панель' : 'Collapse toolbar')
                        : (isRu ? 'Развернуть панель' : 'Expand toolbar'),
                    child: AnimatedRotation(
                      turns: visible ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
