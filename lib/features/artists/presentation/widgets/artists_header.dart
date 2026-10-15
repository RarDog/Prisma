import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';

import 'artist_service_utils.dart';
import 'artists_liquid_card.dart';

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
    required this.onProviderChanged,
    required this.onToggleService,
    required this.onClearServices,
    required this.onSearch,
  });

  final ArtistsTab currentTab;
  final ValueChanged<ArtistsTab> onTabChanged;
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
      child: ArtistsLiquidCard(
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
                      onTap: () => onTabChanged(ArtistsTab.all),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: currentTab == ArtistsTab.all
                              ? (isDark
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.28)
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: currentTab == ArtistsTab.all
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.08),
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
                                color: currentTab == ArtistsTab.all
                                    ? (isDark
                                        ? Colors.white
                                        : theme.colorScheme.primary)
                                    : (isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRu ? 'Каталог' : 'Catalog',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: currentTab == ArtistsTab.all
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: currentTab == ArtistsTab.all
                                      ? (isDark
                                          ? Colors.white
                                          : theme.colorScheme.primary)
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF475569)),
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
                      onTap: () => onTabChanged(ArtistsTab.favorites),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: currentTab == ArtistsTab.favorites
                              ? (isDark
                                  ? Colors.amber.withValues(alpha: 0.25)
                                  : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: currentTab == ArtistsTab.favorites
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.08),
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
                                color: currentTab == ArtistsTab.favorites
                                    ? Colors.amber
                                    : (isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRu ? 'Любимые' : 'Favorites',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: currentTab == ArtistsTab.favorites
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: currentTab == ArtistsTab.favorites
                                      ? (isDark
                                          ? Colors.amber.shade300
                                          : const Color(0xFFB45309))
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF475569)),
                                ),
                              ),
                              if (favoritesCount > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: currentTab == ArtistsTab.favorites
                                        ? Colors.amber.withValues(alpha: 0.3)
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.12)
                                            : Colors.black
                                                .withValues(alpha: 0.08)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$favoritesCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: currentTab == ArtistsTab.favorites
                                          ? (isDark
                                              ? Colors.amber.shade200
                                              : const Color(0xFF92400E))
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF475569)),
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
                        final sColor = artistServiceColor(service);
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
                                  formatArtistServiceName(service),
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
