import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/shared/widgets/adaptive_scaffold.dart';
import 'package:prisma_app/shared/widgets/empty_view.dart';
import 'package:prisma_app/shared/widgets/error_view.dart';
import 'package:prisma_app/shared/widgets/provider_health_banner.dart';
import 'package:prisma_app/features/settings/presentation/settings_controller.dart';
import 'widgets/artist_service_utils.dart';
import 'widgets/artists_catalog_view.dart';
import 'widgets/artists_favorites_empty.dart';
import 'widgets/artists_favorites_view.dart';
import 'widgets/artists_header.dart';
import 'widgets/pawchive/pawchive_accounts_sheet.dart';

export 'widgets/artist_card.dart';
export 'widgets/artist_service_utils.dart';
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
      .where((c) => c.id != 'fapello' && c.apiType != 'fapello')
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
  String? _providerId;
  var _page = 1;
  var _loading = false;
  var _hasMore = true;
  Object? _error;
  List<ArtistProfile> _artists = const [];

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

  bool _headerVisible = true;
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
    if (_scroll.hasClients &&
        _scroll.position.hasContentDimensions &&
        _scroll.position.extentAfter < 500) {
      _loadMore();
    }

    if (offset <= 60) {
      _scrollDeltaAccumulator = 0;
      if (!_headerVisible) setState(() => _headerVisible = true);
    } else {
      final delta = offset - _lastScrollOffset;
      if ((delta > 0 && _scrollDeltaAccumulator < 0) ||
          (delta < 0 && _scrollDeltaAccumulator > 0)) {
        _scrollDeltaAccumulator = 0;
      }
      _scrollDeltaAccumulator += delta;

      if (_scrollDeltaAccumulator > 50) {
        if (_headerVisible) setState(() => _headerVisible = false);
      } else if (_scrollDeltaAccumulator < -14) {
        if (!_headerVisible) setState(() => _headerVisible = true);
      }
    }
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
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
          if (_artists.isEmpty && !_loading && _error == null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _refresh(items));
          }
          final displayedArtists = _artists.where((a) {
            final s = a.service.toLowerCase();
            if (s != 'patreon' && s != 'fanbox') {
              return false;
            }
            if (_selectedServices.isEmpty) return true;
            return _selectedServices.contains(s);
          }).toList(growable: false);

          final searchQuery = _search.text.trim().toLowerCase();
          final displayedFavorites = favoriteItems.where((fav) {
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
          }).toList(growable: false);

          return Column(
            children: [
              const ProviderHealthBanner(),
              AnimatedCrossFade(
                firstChild: ArtistsHeader(
                  currentTab: _currentTab,
                  onTabChanged: (tab) {
                    setState(() => _currentTab = tab);
                  },
                  favoritesCount: favoriteItems.length,
                  searchController: _search,
                  providers: items,
                  selectedProviderId: _providerId,
                  selectedServices: _selectedServices,
                  isRu: isRu,
                  onProviderChanged: (value) {
                    setState(() => _providerId = value);
                    _refresh(items);
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
                secondChild: const SizedBox.shrink(),
                crossFadeState: _headerVisible
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeInOutCubic,
              ),
              Expanded(
                child: _currentTab == ArtistsTab.favorites
                    ? (displayedFavorites.isEmpty
                        ? ArtistsFavoritesEmpty(
                            hasAnyFavorites: favoriteItems.isEmpty,
                            hasActiveFilters: _selectedServices.isNotEmpty ||
                                _search.text.isNotEmpty,
                            isRu: isRu,
                            onBrowseCatalog: () => setState(
                                () => _currentTab = ArtistsTab.all),
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

  Future<void> _refresh(List<ContentProviderConfig> configs) async {
    if (configs.isEmpty) return;
    setState(() {
      _page = 1;
      _hasMore = true;
      _artists = const [];
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _providerId == null) return;
    setState(() => _loading = true);
    try {
      final manager = ref.read(providerManagerProvider);
      final providers = await manager.activeArtistProviders();
      if (providers is! Success<List<ArtistProvider>>) return;
      final provider = providers.data.firstWhere(
        (item) => (item as ContentProvider).id == _providerId,
      );
      final next = await provider.searchArtists(
        _search.text.trim(),
        services: _selectedServices.isEmpty ? null : _selectedServices.toList(),
        page: _page,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _artists = [..._artists, ...next];
        _page++;
        _hasMore = next.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      if (_artists.isEmpty) {
        // Initial load failed — surface a full-screen error with retry.
        setState(() => _error = error);
      } else {
        // Pagination hiccup — keep the loaded content, notify in place.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.maybeLocaleOf(context)?.languageCode == 'ru'
                  ? 'Не удалось загрузить ещё авторов'
                  : 'Failed to load more artists',
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
