import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'manga_card.dart';

class MangaCatalogView extends StatelessWidget {
  const MangaCatalogView({
    super.key,
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.activeQuery,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.mangaProviders,
    required this.selectedProviderId,
    required this.onProviderSelected,
    required this.selectedTopPeriod,
    required this.onTopPeriodSelected,
    required this.errorMessage,
    required this.onRetry,
    required this.mangaList,
    required this.loading,
    required this.onOpenManga,
  });

  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final String activeQuery;
  final List<TagSuggestion> suggestions;
  final ValueChanged<TagSuggestion> onSuggestionSelected;
  final List<ContentProvider> mangaProviders;
  final String selectedProviderId;
  final ValueChanged<String> onProviderSelected;
  final TopPeriodFilter selectedTopPeriod;
  final ValueChanged<TopPeriodFilter> onTopPeriodSelected;
  final String? errorMessage;
  final VoidCallback onRetry;
  final List<Post> mangaList;
  final bool loading;
  final ValueChanged<Post> onOpenManga;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return CustomScrollView(
      key: const PageStorageKey<String>('manga_catalog_scroll_view'),
      controller: scrollController,
      // ignore: deprecated_member_use
      cacheExtent: 180.0,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              // extendBodyBehindAppBar already folds the toolbar height
              // into padding.top — just a small breathing gap after it.
              MediaQuery.paddingOf(context).top + 12,
              16,
              6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: isRu
                        ? 'Поиск манги, автора или тега...'
                        : 'Search manga, artist or tag...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: searchController.text.isNotEmpty ||
                            activeQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: onClearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in suggestions)
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
                            onSuggestionSelected(suggestion);
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                if (mangaProviders.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: mangaProviders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final provider = mangaProviders[index];
                        final isSelected = provider.id == selectedProviderId;
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
                          onTap: () => onProviderSelected(provider.id),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandColor.withValues(alpha: 0.18)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? brandColor
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon,
                                    size: 16,
                                    color: isSelected
                                        ? brandColor
                                        : theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  provider.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? brandColor
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
                              color: selectedTopPeriod == period
                                  ? (isDark ? Colors.black87 : Colors.white)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            label: Text(
                              switch (period) {
                                TopPeriodFilter.none =>
                                  isRu ? 'Свежее' : 'Recent',
                                TopPeriodFilter.allTime =>
                                  isRu ? 'Топ за все время' : 'All-time Top',
                                TopPeriodFilter.year =>
                                  isRu ? 'Топ за год' : 'Year Top',
                                TopPeriodFilter.month =>
                                  isRu ? 'Топ за месяц' : 'Month Top',
                                TopPeriodFilter.week =>
                                  isRu ? 'Топ за неделю' : 'Week Top',
                                TopPeriodFilter.day =>
                                  isRu ? 'Топ за день' : 'Day Top',
                              },
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            selected: selectedTopPeriod == period,
                            onSelected: (_) => onTopPeriodSelected(period),
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
        if (errorMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(isRu ? 'Повторить' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (mangaList.isEmpty && !loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      isRu ? 'Ничего не найдено' : 'No manga found',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (activeQuery.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: onClearSearch,
                        child: Text(
                          isRu
                              ? 'Очистить поиск «$activeQuery»'
                              : 'Clear search "$activeQuery"',
                        ),
                      ),
                    ],
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
                  final post = mangaList[index];
                  return RepaintBoundary(
                    child: MangaCard(
                      post: post,
                      onTap: () => onOpenManga(post),
                    ),
                  );
                },
                childCount: mangaList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6740))),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
        ),
      ],
    );
  }
}
