import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'package:gel_rule_app/sources/booru/nhentai_provider.dart';
import 'manga_details_screen.dart';

class MangaScreen extends ConsumerStatefulWidget {
  const MangaScreen({super.key});

  @override
  ConsumerState<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends ConsumerState<MangaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
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
  List<TagSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _initProvidersAndLoad();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (!_loading && _hasMore && _errorMessage == null) {
        _loadManga();
      }
    }
  }

  Future<void> _initProvidersAndLoad() async {
    final providerManager = ref.read(providerManagerProvider);
    final providersResult = await providerManager.activeProviders();
    final activeProviders = providersResult is Success<List<ContentProvider>>
        ? providersResult.data
        : <ContentProvider>[];

    final mangaProviders = activeProviders.where((p) {
      return p.id == 'mangadex' ||
          p.id == 'nhentai' ||
          p is MangaDexProvider ||
          p is NHentaiProvider ||
          p.baseUrl.contains('mangadex') ||
          p.baseUrl.contains('nhentai');
    }).toList();

    if (mounted) {
      setState(() {
        _mangaProviders = mangaProviders.isNotEmpty ? mangaProviders : activeProviders;
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
    });
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
    setState(() => _selectedRating = ratings[nextIdx]);
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
    HapticFeedback.lightImpact();
    final selectedTag = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => MangaDetailsScreen(post: post),
      ),
    );
    if (selectedTag != null && selectedTag.isNotEmpty && mounted) {
      _searchController.text = selectedTag;
      setState(() {
        _activeQuery = selectedTag;
        _suggestions = [];
      });
      _loadManga(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: Text(
                isRu ? 'Манга и Комиксы' : 'Manga & Comics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              actions: [
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
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search & Provider selector bar
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

                  // Suggestions Wrap (Authors, Tags, Titles)
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

                  // Provider switcher pills
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
                          final isMangadex = provider.id == 'mangadex';
                          final isNhentai = provider.id == 'nhentai';

                          final Color brandColor = isMangadex
                              ? const Color(0xFFFF6740)
                              : (isNhentai ? const Color(0xFFED2553) : theme.colorScheme.primary);

                          final IconData icon = isMangadex
                              ? Icons.auto_stories_rounded
                              : (isNhentai ? Icons.menu_book_rounded : Icons.hub_rounded);

                          return InkWell(
                            onTap: () => _onProviderSelected(provider.id),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? brandColor.withValues(alpha: 0.18)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? brandColor.withValues(alpha: 0.8)
                                      : Colors.transparent,
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: 16,
                                    color: isSelected ? brandColor : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    provider.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Top period switcher pills
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: TopPeriodFilter.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final period = TopPeriodFilter.values[index];
                        final isSelected = period == _selectedTopPeriod;
                        return InkWell(
                          onTap: () => _onTopPeriodSelected(period),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _periodIcon(period),
                                  size: 14,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  period.localizedLabel(isRu),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error State
          if (_errorMessage != null && _mangaList.isEmpty && !_loading)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isRu ? 'Ошибка соединения с источником' : 'Connection failed',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!.contains('522') || _errorMessage!.contains('timeout')
                            ? (isRu
                                ? 'Сервер источника недоступен или заблокирован (Таймаут/522).'
                                : 'Source server is unreachable (Timeout/522).')
                            : _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(isRu ? 'Повторить' : 'Retry'),
                            onPressed: () => _loadManga(refresh: true),
                          ),
                          if (_selectedProviderId != 'mangadex' &&
                              _mangaProviders.any((p) => p.id == 'mangadex')) ...[
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.auto_stories_rounded, size: 18),
                              label: const Text('MangaDex'),
                              onPressed: () => _onProviderSelected('mangadex'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Empty State
          else if (_mangaList.isEmpty && !_loading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 54, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      isRu ? 'Нет доступных манг' : 'No manga found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Manga Grid
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62, // Book cover aspect ratio (approx 2:3)
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
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
          ),
        ],
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
