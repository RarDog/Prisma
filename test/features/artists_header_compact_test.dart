import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artist_card.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artist_service_utils.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artists_filter_sheet.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artists_header.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artists_page_bar.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/artists_page_picker_sheet.dart';
import 'package:gel_rule_app/features/favorites/models/favorite_artist_item.dart';
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

    testWidgets('FavoriteArtistCard renders post count and relative updated line',
        (tester) async {
      final now = DateTime.now().subtract(const Duration(hours: 3));
      final favItem = FavoriteArtistItem(
        id: '42',
        service: 'fanbox',
        providerId: 'pawchive',
        name: 'MasterArtist',
        postCount: 5210,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: FavoriteArtistCard(
              item: favItem,
              onTap: () {},
              onRemove: () {},
            ),
          ),
        ),
      );

      expect(find.text('MasterArtist'), findsOneWidget);
      expect(find.text('Pixiv Fanbox'), findsOneWidget);
      expect(find.text('5 210 постов'), findsOneWidget);
      expect(find.textContaining('Обновлено: 3 часа назад'), findsOneWidget);
    });

    testWidgets('ArtistsPageBar renders page numbers and navigates on tap',
        (tester) async {
      int? selectedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArtistsPageBar(
              page: 1,
              totalPages: 150,
              canGoBack: false,
              canGoForward: true,
              isRu: true,
              onPageSelected: (p) => selectedPage = p,
            ),
          ),
        ),
      );

      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      // Tap on page 2
      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();

      expect(selectedPage, 2);
    });

    testWidgets('ArtistsPagePickerSheet lets user pick page and confirm',
        (tester) async {
      int? confirmedPage;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open Picker'),
                onPressed: () => ArtistsPagePickerSheet.show(
                  context,
                  currentPage: 1,
                  totalPages: 160,
                  isRu: true,
                  onPageSelected: (p) => confirmedPage = p,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Переход к странице'), findsOneWidget);
      expect(find.text('110'), findsWidgets);

      // Tap quick jump chip 110
      await tester.tap(find.text('110').first);
      await tester.pumpAndSettle();

      expect(find.text('Перейти к странице 110'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Перейти к странице 110'));
      await tester.pumpAndSettle();

      expect(confirmedPage, 110);
    });
  });
}
