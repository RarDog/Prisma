import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';

import 'artist_service_utils.dart';
import 'artists_filter_bar.dart';
import 'artists_liquid_card.dart';
import 'artists_search_field.dart';
import 'artists_tab_toggle.dart';

/// Thin composer placing the tab toggle, search field and filter bar inside
/// the liquid glass header card. The visual blocks live in their own files.
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
    required this.isRu,
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
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: ArtistsLiquidCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtistsTabToggle(
              currentTab: currentTab,
              onTabChanged: onTabChanged,
              favoritesCount: favoritesCount,
              isRu: isRu,
            ),
            const SizedBox(height: 8),
            ArtistsSearchField(
              searchController: searchController,
              onSearch: onSearch,
              isRu: isRu,
            ),
            const SizedBox(height: 8),
            ArtistsFilterBar(
              providers: providers,
              selectedProviderId: selectedProviderId,
              selectedServices: selectedServices,
              onProviderChanged: onProviderChanged,
              onToggleService: onToggleService,
              onClearServices: onClearServices,
              isRu: isRu,
            ),
          ],
        ),
      ),
    );
  }
}
