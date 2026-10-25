import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/favorite_enums.dart';

class FavoritesFilterBar extends StatelessWidget {
  const FavoritesFilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.videoCount,
    required this.imageCount,
    required this.selectedProvider,
    required this.availableProviders,
    required this.onProviderChanged,
    required this.isRu,
  });

  final FavoriteMediaType currentFilter;
  final ValueChanged<FavoriteMediaType> onFilterChanged;
  final int videoCount;
  final int imageCount;
  final String? selectedProvider;
  final List<String> availableProviders;
  final ValueChanged<String?> onProviderChanged;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterCapsule(
              label: isRu ? 'Все' : 'All',
              isSelected: currentFilter == FavoriteMediaType.all,
              onTap: () => onFilterChanged(FavoriteMediaType.all),
            ),
            const SizedBox(width: 8),
            FilterCapsule(
              icon: Icons.videocam_rounded,
              label: isRu ? 'Видео' : 'Videos',
              count: videoCount,
              isSelected: currentFilter == FavoriteMediaType.video,
              onTap: () => onFilterChanged(FavoriteMediaType.video),
            ),
            const SizedBox(width: 8),
            FilterCapsule(
              icon: Icons.image_rounded,
              label: isRu ? 'Фото' : 'Images',
              count: imageCount,
              isSelected: currentFilter == FavoriteMediaType.image,
              onTap: () => onFilterChanged(FavoriteMediaType.image),
            ),
            if (availableProviders.length > 1) ...[
              const SizedBox(width: 8),
              ProviderFilterMenu(
                selectedProvider: selectedProvider,
                availableProviders: availableProviders,
                onProviderChanged: onProviderChanged,
                isRu: isRu,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FilterCapsule extends StatelessWidget {
  const FilterCapsule({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? scheme.primary
            : (isDark
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.50)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55)),
        border: Border.all(
          color: isSelected
              ? scheme.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06)),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Colors.white : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProviderFilterMenu extends StatelessWidget {
  const ProviderFilterMenu({
    super.key,
    required this.selectedProvider,
    required this.availableProviders,
    required this.onProviderChanged,
    required this.isRu,
  });

  final String? selectedProvider;
  final List<String> availableProviders;
  final ValueChanged<String?> onProviderChanged;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasFilter = selectedProvider != null;

    return PopupMenuButton<String?>(
      initialValue: selectedProvider,
      tooltip: isRu ? 'Фильтр по источнику' : 'Filter by source',
      onSelected: (val) {
        HapticFeedback.selectionClick();
        onProviderChanged(val);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(
                Icons.clear_all_rounded,
                size: 18,
                color: !hasFilter ? scheme.primary : null,
              ),
              const SizedBox(width: 8),
              Text(
                isRu ? 'Все источники' : 'All sources',
                style: TextStyle(
                  fontWeight: !hasFilter ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...availableProviders.map(
          (prov) => PopupMenuItem<String?>(
            value: prov,
            child: Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  size: 18,
                  color: selectedProvider == prov ? scheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(
                  prov,
                  style: TextStyle(
                    fontWeight: selectedProvider == prov
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: hasFilter
              ? scheme.secondaryContainer
              : (isDark
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.50)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.55)),
          border: Border.all(
            color: hasFilter
                ? scheme.secondary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06)),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.tune_rounded : Icons.filter_list_rounded,
              size: 14,
              color: hasFilter
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              hasFilter ? selectedProvider! : (isRu ? 'Источник' : 'Source'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasFilter ? FontWeight.bold : FontWeight.w600,
                color: hasFilter
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onProviderChanged(null);
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ] else ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
