import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artist_service_utils.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artists_filter_sheet.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artists_header.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';

void main() {
  group('ArtistsHeader compact mobile layout & filtering', () {
    final mockProviders = [
      ContentProviderConfig(
        id: 'pawchive',
        name: 'Pawchive',
        baseUrl: 'https://pawchive.pw',
        apiType: 'pawchive',
        enabled: true,
        priority: 12,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];

    testWidgets('renders compact search, tabs, quick sort chip and service pills',
        (tester) async {
      final searchController = TextEditingController();
      ArtistSortOrder currentSort = ArtistSortOrder.popularityDesc;
      final selectedServices = <String>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistsHeader(
              currentTab: ArtistsTab.all,
              onTabChanged: (_) {},
              favoritesCount: 5,
              searchController: searchController,
              providers: mockProviders,
              selectedProviderId: 'pawchive',
              selectedServices: selectedServices,
              selectedSort: currentSort,
              isRu: true,
              onProviderChanged: (_) {},
              onToggleService: (_) {},
              onClearServices: () {},
              onSortChanged: (s) => currentSort = s,
              onSearch: () {},
            ),
          ),
        ),
      );

      // Verify essential components rendered
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Каталог'), findsOneWidget);
      expect(find.text('Любимые'), findsOneWidget);
      expect(find.text('По популярности'), findsOneWidget);
      expect(find.text('Patreon'), findsOneWidget);
      expect(find.text('Pixiv Fanbox'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('ArtistsFilterSheet lets user choose postsAsc and applies it',
        (tester) async {
      ArtistSortOrder appliedSort = ArtistSortOrder.popularityDesc;
      Set<String> appliedServices = {};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ArtistsFilterSheet.show(
                  context,
                  selectedSort: ArtistSortOrder.popularityDesc,
                  selectedServices: const {},
                  providers: mockProviders,
                  selectedProviderId: 'pawchive',
                  isRu: true,
                  onApply: ({required sort, required services, required providerId}) {
                    appliedSort = sort;
                    appliedServices = services;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Tap open
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Фильтры и сортировка'), findsOneWidget);
      expect(find.text('Меньше постов'), findsOneWidget);
      expect(find.text('Свежие посты'), findsOneWidget);

      // Select 'Меньше постов' (postsAsc)
      await tester.tap(find.text('Меньше постов'));
      await tester.pumpAndSettle();

      // Select 'Patreon'
      await tester.tap(find.text('Patreon'));
      await tester.pumpAndSettle();

      // Tap Apply
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();

      expect(appliedSort, ArtistSortOrder.postsAsc);
      expect(appliedServices, contains('patreon'));
    });
  });
}
