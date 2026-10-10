import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'package:gel_rule_app/shared/widgets/provider_health_banner.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'widgets/pawchive_accounts_sheet.dart';

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

enum _ArtistsTab {
  all,
  favorites,
}

class ArtistsScreen extends ConsumerStatefulWidget {
  const ArtistsScreen({super.key});

  @override
  ConsumerState<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends ConsumerState<ArtistsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _selectedServices = <String>{};
  _ArtistsTab _currentTab = _ArtistsTab.all;
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

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_currentTab == _ArtistsTab.favorites) {
        setState(() {});
      }
    });
    _scroll.addListener(() {
      final offset = _scroll.offset;
      if (_scroll.hasClients &&
          _scroll.position.hasContentDimensions &&
          _scroll.position.extentAfter < 500) {
        _loadMore();
      }

      // Responsive scroll: collapses on intentional downward scroll (28px),
      // and immediately reveals on any gentle upward movement (6px) or when near top.
      if (offset <= 80) {
        if (!_headerVisible) setState(() => _headerVisible = true);
      } else if (offset > _lastScrollOffset + 28) {
        if (_headerVisible) setState(() => _headerVisible = false);
      } else if (offset < _lastScrollOffset - 6) {
        if (!_headerVisible) setState(() => _headerVisible = true);
      }
      _lastScrollOffset = offset;
    });
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
            if (_selectedServices.isNotEmpty && !_selectedServices.contains(s)) {
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
                firstChild: _ArtistsHeader(
                  currentTab: _currentTab,
                  onTabChanged: (tab) {
                    setState(() => _currentTab = tab);
                  },
                  favoritesCount: favoriteItems.length,
                  searchController: _search,
                  providers: items,
                  selectedProviderId: _providerId,
                  selectedServices: _selectedServices,
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
                    if (_currentTab == _ArtistsTab.all) {
                      _refresh(items);
                    }
                  },
                  onClearServices: () {
                    setState(() => _selectedServices.clear());
                    if (_currentTab == _ArtistsTab.all) {
                      _refresh(items);
                    }
                  },
                  onSearch: () {
                    if (_currentTab == _ArtistsTab.all) {
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
                child: _currentTab == _ArtistsTab.favorites
                    ? (displayedFavorites.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    favoriteItems.isEmpty
                                        ? Icons.star_border_rounded
                                        : Icons.person_search_outlined,
                                    size: 52,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    favoriteItems.isEmpty
                                        ? (isRu
                                            ? 'Список любимых авторов пуст'
                                            : 'No favorite artists yet')
                                        : (isRu
                                            ? 'Ничего не найдено в избранном'
                                            : 'No favorites matching filter'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Text(
                                      favoriteItems.isEmpty
                                          ? (isRu
                                              ? 'Нажмите на звёздочку ★ на карточке любого автора в каталоге, чтобы быстро возвращаться к его работам.'
                                              : 'Tap the star ★ icon on any artist in the catalog to add them to your favorites.')
                                          : (isRu
                                              ? 'Попробуйте изменить поисковый запрос или сбросить фильтры по платформам.'
                                              : 'Try clearing the search query or platform filters.'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (favoriteItems.isEmpty)
                                    FilledButton.tonalIcon(
                                      icon: const Icon(Icons.explore_rounded,
                                          size: 18),
                                      label: Text(isRu
                                          ? 'Перейти в каталог'
                                          : 'Browse catalog'),
                                      onPressed: () {
                                        setState(() =>
                                            _currentTab = _ArtistsTab.all);
                                      },
                                    )
                                  else if (_selectedServices.isNotEmpty ||
                                      _search.text.isNotEmpty)
                                    FilledButton.tonal(
                                      onPressed: () {
                                        setState(() {
                                          _selectedServices.clear();
                                          _search.clear();
                                        });
                                      },
                                      child: Text(isRu
                                          ? 'Сбросить фильтры'
                                          : 'Reset filters'),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = Responsive.isMobile(context)
                                  ? 1
                                  : constraints.maxWidth >= 1100
                                      ? 3
                                      : constraints.maxWidth >= 760
                                          ? 2
                                          : 1;
                              return GridView.builder(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  150.0 + MediaQuery.paddingOf(context).bottom,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent:
                                      Responsive.isMobile(context) ? 116 : 124,
                                ),
                                itemCount: displayedFavorites.length,
                                itemBuilder: (context, index) {
                                  final fav = displayedFavorites[index];
                                  return _FavoriteArtistCard(
                                    item: fav,
                                    onRemove: () =>
                                        _removeFavoriteItem(settings, fav),
                                    onTap: () => context.push(
                                      '/artists/${fav.providerId}/${fav.service}/${fav.id}?name=${Uri.encodeComponent(fav.name)}',
                                    ),
                                  );
                                },
                              );
                            },
                          ))
                    : (_error != null
                        ? ErrorView(
                            message: _friendlyArtistError(_error),
                            onRetry: () => _refresh(items),
                          )
                        : displayedArtists.isEmpty && !_loading
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_search_outlined,
                                          size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        isRu
                                            ? 'Нет авторов по выбранным фильтрам'
                                            : 'No artists matching selected filters',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          setState(() =>
                                              _selectedServices.clear());
                                          _refresh(items);
                                        },
                                        child: Text(
                                          isRu
                                              ? 'Показать все сервисы'
                                              : 'Show all services',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = Responsive.isMobile(context)
                                      ? 1
                                      : constraints.maxWidth >= 1100
                                          ? 3
                                          : constraints.maxWidth >= 760
                                              ? 2
                                              : 1;
                                  return GridView.builder(
                                    controller: _scroll,
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior.onDrag,
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      16,
                                      150.0 + MediaQuery.paddingOf(context).bottom,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      mainAxisExtent:
                                          Responsive.isMobile(context)
                                              ? 116
                                              : 124,
                                    ),
                                    itemCount: displayedArtists.length +
                                        (_loading ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= displayedArtists.length) {
                                        return const _ArtistSkeletonCard();
                                      }
                                      final artist = displayedArtists[index];
                                      final isFav = favoriteKeys.contains(
                                          '${artist.providerId}:${artist.service}:${artist.id}');
                                      return _ArtistCard(
                                        artist: artist,
                                        isFavorite: isFav,
                                        onToggleFavorite: () =>
                                            _toggleFavoriteArtist(
                                                settings, artist),
                                        onTap: () => context.push(
                                          '/artists/${artist.providerId}/${artist.service}/${artist.id}?name=${Uri.encodeComponent(artist.displayName)}',
                                        ),
                                      );
                                    },
                                  );
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
      setState(() => _error = error);
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

Color _serviceColor(String service) {
  switch (service.toLowerCase()) {
    case 'patreon':
      return const Color(0xFFFF424D);
    case 'fanbox':
      return const Color(0xFF0096FA);
    case 'fantia':
      return const Color(0xFFFF2E74);
    case 'boosty':
      return const Color(0xFFF15F2C);
    case 'discord':
      return const Color(0xFF5865F2);
    case 'subscribestar':
      return const Color(0xFF009688);
    case 'gumroad':
      return const Color(0xFFFF90E8);
    case 'afdian':
      return const Color(0xFF946CE6);
    case 'fapello':
      return const Color(0xFFE8467C);
    default:
      return const Color(0xFF7C4DFF);
  }
}

String _formatServiceName(String s) {
  switch (s.toLowerCase()) {
    case 'patreon':
      return 'Patreon';
    case 'fanbox':
      return 'Pixiv Fanbox';
    case 'fantia':
      return 'Fantia';
    case 'boosty':
      return 'Boosty';
    case 'discord':
      return 'Discord';
    case 'fapello':
      return 'Fapello';
    default:
      return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }
}

class _ArtistsLiquidCard extends StatelessWidget {
  const _ArtistsLiquidCard({
    required this.child,
    this.padding,
    this.glowColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = glowColor ?? theme.colorScheme.primary;
    final r = BorderRadius.circular(22);

    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.62),
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.40),
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
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.32)
                : accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.06 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: onTap != null
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: r,
                    onTap: onTap,
                    child: cardContent,
                  ),
                )
              : cardContent,
        ),
      ),
    );
  }
}

class _ArtistsHeader extends StatelessWidget {
  const _ArtistsHeader({
    required this.currentTab,
    required this.onTabChanged,
    required this.favoritesCount,
    required this.searchController,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedServices,
    required this.onProviderChanged,
    required this.onToggleService,
    required this.onClearServices,
    required this.onSearch,
  });

  final _ArtistsTab currentTab;
  final ValueChanged<_ArtistsTab> onTabChanged;
  final int favoritesCount;
  final TextEditingController searchController;
  final List<ContentProviderConfig> providers;
  final String? selectedProviderId;
  final Set<String> selectedServices;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onToggleService;
  final VoidCallback onClearServices;
  final VoidCallback onSearch;

  static const _availableServices = [
    'patreon',
    'fanbox',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: _ArtistsLiquidCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode Selector: Catalog vs Favorites
            Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onTabChanged(_ArtistsTab.all),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: currentTab == _ArtistsTab.all
                              ? (isDark
                                  ? theme.colorScheme.primary.withValues(alpha: 0.28)
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: currentTab == _ArtistsTab.all
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.explore_rounded,
                                size: 16,
                                color: currentTab == _ArtistsTab.all
                                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRu ? 'Каталог' : 'Catalog',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: currentTab == _ArtistsTab.all
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: currentTab == _ArtistsTab.all
                                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onTabChanged(_ArtistsTab.favorites),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: currentTab == _ArtistsTab.favorites
                              ? (isDark
                                  ? Colors.amber.withValues(alpha: 0.25)
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: currentTab == _ArtistsTab.favorites
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: currentTab == _ArtistsTab.favorites
                                    ? Colors.amber
                                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRu ? 'Любимые' : 'Favorites',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: currentTab == _ArtistsTab.favorites
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: currentTab == _ArtistsTab.favorites
                                      ? (isDark ? Colors.amber.shade300 : const Color(0xFFB45309))
                                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                              if (favoritesCount > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: currentTab == _ArtistsTab.favorites
                                        ? Colors.amber.withValues(alpha: 0.3)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : Colors.black.withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$favoritesCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: currentTab == _ArtistsTab.favorites
                                          ? (isDark ? Colors.amber.shade200 : const Color(0xFF92400E))
                                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Glass search bar (completely transparent inside, no unwanted background tint)
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            isRu ? 'Поиск авторов...' : 'Search artists...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : const Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => onSearch(),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (context, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        color:
                            isDark ? Colors.white60 : const Color(0xFF94A3B8),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: isRu ? 'Очистить' : 'Clear',
                        onPressed: () {
                          searchController.clear();
                          onSearch();
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: onSearch,
                      child: Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isRu ? 'Найти' : 'Search',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Unified single-row filter bar: providers + separator + platforms
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Providers
                  for (final provider in providers) ...[
                    Builder(
                      builder: (context) {
                        final isSelected = provider.id == selectedProviderId;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onProviderChanged(provider.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.20)
                                      : const Color(0xFF0F172A))
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                        ? Colors.white.withValues(alpha: 0.40)
                                        : const Color(0xFF0F172A))
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                width: 1.1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.dns_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  provider.name,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Vertical divider between provider and platforms
                  if (providers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 4),
                      child: Container(
                        width: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // "All platforms" chip
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onClearServices,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selectedServices.isEmpty
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.20)
                                : const Color(0xFF0F172A))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedServices.isEmpty
                              ? (isDark
                                  ? Colors.white.withValues(alpha: 0.40)
                                  : const Color(0xFF0F172A))
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                          width: 1.1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isRu ? 'Все платформы' : 'All platforms',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selectedServices.isEmpty
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selectedServices.isEmpty
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Platform chips
                  for (final service in _availableServices) ...[
                    Builder(
                      builder: (context) {
                        final sColor = _serviceColor(service);
                        final isSelected = selectedServices.contains(service);
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onToggleService(service),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? sColor.withValues(
                                      alpha: isDark ? 0.26 : 0.14)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.035)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? sColor.withValues(alpha: 0.75)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                width: 1.1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: sColor,
                                    shape: BoxShape.circle,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color:
                                                  sColor.withValues(alpha: 0.6),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatServiceName(service),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? sColor
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF334155)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
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

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artist,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final ArtistProfile artist;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final sColor = _serviceColor(artist.service);

    return _ArtistsLiquidCard(
      glowColor: sColor.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          _ArtistAvatar(artist: artist),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _LiquidMiniBadge(
                      label: artist.service.isEmpty ? 'Artist' : artist.service,
                      color: sColor,
                      hasDot: true,
                    ),
                    if (artist.postCount != null)
                      _LiquidMiniBadge(
                        label:
                            '${artist.postCount} ${isRu ? 'постов' : 'posts'}',
                        color:
                            isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                  ],
                ),
                if (artist.updatedAt != null) ...[
                  const SizedBox(height: 5),
                  Builder(
                    builder: (_) {
                      final dt = artist.updatedAt!.toLocal();
                      final d = dt.day.toString().padLeft(2, '0');
                      final m = dt.month.toString().padLeft(2, '0');
                      final y = dt.year;
                      final hr = dt.hour.toString().padLeft(2, '0');
                      final min = dt.minute.toString().padLeft(2, '0');
                      return Text(
                        '${isRu ? 'Обновлено' : 'Updated'}: $d.$m.$y $hr:$min',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Interactive Favorite button with gold glow
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onToggleFavorite,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFavorite
                      ? Colors.amber.withValues(alpha: isDark ? 0.22 : 0.15)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFavorite
                        ? Colors.amber.withValues(alpha: 0.6)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                  ),
                  boxShadow: isFavorite
                      ? [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite ? Colors.amber : scheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _FavoriteArtistCard extends StatelessWidget {
  const _FavoriteArtistCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteArtistItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final sColor = _serviceColor(item.service);

    final avatarFallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            sColor.withValues(alpha: 0.85),
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          item.name.trim().isNotEmpty
              ? item.name.trim().characters.first.toUpperCase()
              : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );

    return _ArtistsLiquidCard(
      glowColor: sColor.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.90),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: sColor.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.avatarUrl!,
                      memCacheWidth: 140,
                      memCacheHeight: 140,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => avatarFallback,
                      errorWidget: (_, __, ___) => avatarFallback,
                    )
                  : avatarFallback,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _LiquidMiniBadge(
                      label: item.service.isEmpty
                          ? 'Artist'
                          : _formatServiceName(item.service),
                      color: sColor,
                      hasDot: true,
                    ),
                    _LiquidMiniBadge(
                      label: isRu ? 'В избранном' : 'Favorited',
                      color: Colors.amber,
                      hasDot: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Interactive Remove from Favorites star button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onRemove,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({
    required this.artist,
  });

  final ArtistProfile artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = artist.displayName.trim();
    final initials = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final accent = theme.colorScheme.primary;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.85),
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: artist.avatarUrl == null || artist.avatarUrl!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: artist.avatarUrl!,
                memCacheWidth: 140,
                memCacheHeight: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _LiquidMiniBadge extends StatelessWidget {
  const _LiquidMiniBadge({
    required this.label,
    required this.color,
    this.hasDot = false,
  });

  final String label;
  final Color color;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLabel =
        label.isEmpty ? '' : label[0].toUpperCase() + label.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistSkeletonCard extends StatelessWidget {
  const _ArtistSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _ArtistsLiquidCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
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
