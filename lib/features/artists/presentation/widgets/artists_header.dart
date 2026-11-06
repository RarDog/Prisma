import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';

import 'artist_service_utils.dart';
import 'artists_filter_sheet.dart';
import 'artists_liquid_card.dart';
import 'artists_search_field.dart';
import 'artists_tab_toggle.dart';

/// Ultra-compact mobile-first artists header with integrated search,
/// quick horizontal sort & service pills, and bottom sheet filter dialog.
class ArtistsHeader extends StatelessWidget {
  const ArtistsHeader({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.favoritesCount,
    required this.searchController,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedServices,
    required this.selectedSort,
    required this.onProviderChanged,
    required this.onToggleService,
    required this.onClearServices,
    required this.onSortChanged,
    required this.onSearch,
    required this.isRu,
    this.currentPage,
    this.totalPages,
    this.onOpenPagePicker,
  });

  final ArtistsTab currentTab;
  final ValueChanged<ArtistsTab> onTabChanged;
  final int favoritesCount;
  final TextEditingController searchController;
  final List<ContentProviderConfig> providers;
  final String? selectedProviderId;
  final Set<String> selectedServices;
  final ArtistSortOrder selectedSort;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onToggleService;
  final VoidCallback onClearServices;
  final ValueChanged<ArtistSortOrder> onSortChanged;
  final VoidCallback onSearch;
  final bool isRu;
  final int? currentPage;
  final int? totalPages;
  final VoidCallback? onOpenPagePicker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeFilterCount =
        (selectedServices.isNotEmpty ? selectedServices.length : 0) +
            (selectedSort != ArtistSortOrder.popularityDesc ? 1 : 0) +
            (selectedProviderId != null &&
                    providers.isNotEmpty &&
                    selectedProviderId != providers.first.id
                ? 1
                : 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: ArtistsLiquidCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Compact Tab Toggle + Filter Sheet Trigger
            Row(
              children: [
                Expanded(
                  child: ArtistsTabToggle(
                    currentTab: currentTab,
                    onTabChanged: onTabChanged,
                    favoritesCount: favoritesCount,
                    isRu: isRu,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ArtistsFilterSheet.show(
                    context,
                    selectedSort: selectedSort,
                    selectedServices: selectedServices,
                    providers: providers,
                    selectedProviderId: selectedProviderId,
                    isRu: isRu,
                    onApply: ({
                      required sort,
                      required services,
                      required providerId,
                    }) {
                      if (sort != selectedSort) onSortChanged(sort);
                      if (providerId != selectedProviderId) {
                        onProviderChanged(providerId);
                      }
                      for (final s in services) {
                        if (!selectedServices.contains(s)) onToggleService(s);
                      }
                      for (final s in selectedServices) {
                        if (!services.contains(s)) onToggleService(s);
                      }
                    },
                  ),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: activeFilterCount > 0
                          ? theme.colorScheme.primary
                              .withValues(alpha: isDark ? 0.3 : 0.15)
                          : (isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeFilterCount > 0
                            ? theme.colorScheme.primary
                                .withValues(alpha: isDark ? 0.6 : 0.4)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: activeFilterCount > 0
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                        if (activeFilterCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$activeFilterCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (currentTab == ArtistsTab.all &&
                    currentPage != null &&
                    onOpenPagePicker != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onOpenPagePicker,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 15,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            totalPages != null
                                ? '$currentPage/$totalPages'
                                : (isRu ? 'Стр. $currentPage' : 'p. $currentPage'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Search field
            ArtistsSearchField(
              searchController: searchController,
              onSearch: onSearch,
              isRu: isRu,
            ),
            const SizedBox(height: 8),

            // Row 3: Horizontal quick filter & sort pills
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Quick Sort Menu Chip
                  PopupMenuButton<ArtistSortOrder>(
                    tooltip: isRu ? 'Сортировка' : 'Sort order',
                    initialValue: selectedSort,
                    onSelected: onSortChanged,
                    itemBuilder: (context) => ArtistSortOrder.values.map((s) {
                      return PopupMenuItem<ArtistSortOrder>(
                        value: s,
                        child: Row(
                          children: [
                            Icon(
                              s.icon,
                              size: 16,
                              color: s == selectedSort
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.label(isRu),
                              style: TextStyle(
                                fontWeight: s == selectedSort
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: s == selectedSort
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                    child: _QuickSortChip(
                      selectedSort: selectedSort,
                      isRu: isRu,
                      isDark: isDark,
                      accentColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Quick service chips (Patreon, Fanbox)
                  for (final service in const ['patreon', 'fanbox']) ...[
                    _QuickServiceChip(
                      label: formatArtistServiceName(service),
                      serviceColor: artistServiceColor(service),
                      selected: selectedServices.contains(service),
                      isDark: isDark,
                      onTap: () => onToggleService(service),
                    ),
                    const SizedBox(width: 6),
                  ],

                  if (selectedServices.isNotEmpty ||
                      selectedSort != ArtistSortOrder.popularityDesc)
                    InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        onClearServices();
                        if (selectedSort != ArtistSortOrder.popularityDesc) {
                          onSortChanged(ArtistSortOrder.popularityDesc);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isDark
                                ? Colors.redAccent.withValues(alpha: 0.35)
                                : Colors.red.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: isDark
                                  ? Colors.redAccent
                                  : Colors.red.shade700,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isRu ? 'Сброс' : 'Reset',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.redAccent
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
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

class _QuickSortChip extends StatelessWidget {
  const _QuickSortChip({
    required this.selectedSort,
    required this.isRu,
    required this.isDark,
    required this.accentColor,
  });

  final ArtistSortOrder selectedSort;
  final bool isRu;
  final bool isDark;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final hasCustomSort = selectedSort != ArtistSortOrder.popularityDesc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: hasCustomSort
            ? accentColor.withValues(alpha: isDark ? 0.28 : 0.14)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: hasCustomSort
              ? accentColor.withValues(alpha: isDark ? 0.65 : 0.45)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selectedSort.icon,
            size: 13,
            color: hasCustomSort
                ? accentColor
                : (isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(width: 5),
          Text(
            selectedSort.label(isRu),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: hasCustomSort ? FontWeight.bold : FontWeight.w500,
              color: hasCustomSort
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down_rounded,
            size: 14,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ],
      ),
    );
  }
}

class _QuickServiceChip extends StatelessWidget {
  const _QuickServiceChip({
    required this.label,
    required this.serviceColor,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final Color serviceColor;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? serviceColor.withValues(alpha: isDark ? 0.28 : 0.16)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? serviceColor.withValues(alpha: isDark ? 0.75 : 0.6)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
            width: selected ? 1.2 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: serviceColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
