import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/shared/widgets/provider_health_banner.dart';

class _FakeProviderRepository extends Fake implements ProviderRepository {
  _FakeProviderRepository(this.offlineIds);

  final Set<String> offlineIds;

  @override
  Future<Result<ProviderHealth?>> getHealth(String providerId) async {
    if (!offlineIds.contains(providerId)) return const Success(null);
    return Success(ProviderHealth(
      providerId: providerId,
      status: ProviderStatus.offline,
      pingMs: 0,
      lastCheckedAt: DateTime(2026, 1, 1),
      errorMessage: 'HTTP 503',
    ));
  }
}

class _FakeProviderFactory extends Fake implements ProviderFactory {
  @override
  ContentProvider create(ContentProviderConfig config) =>
      throw UnimplementedError();
}

class _FakeProviderManager extends Fake implements ProviderManager {
  @override
  Future<Result<List<ContentProviderConfig>>> loadConfigs({
    bool enabledOnly = true,
  }) async =>
      Success([
        ContentProviderConfig(
          id: 'gelbooru',
          name: 'Gelbooru',
          baseUrl: 'https://gelbooru.com',
          apiType: 'gelbooru',
          enabled: true,
          priority: 0,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        ContentProviderConfig(
          id: 'e621',
          name: 'e621',
          baseUrl: 'https://e621.net',
          apiType: 'e621',
          enabled: true,
          priority: 1,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
}

Widget _harness(Set<String> offlineIds) {
  return ProviderScope(
    overrides: [
      // Pinned to English and kept off the real settings/Isar chain so the
      // banner's strings resolve without a database.
      appSettingsProvider.overrideWith(
        (ref) => AppSettings.defaults.copyWith(languageCode: 'en'),
      ),
      providerRepositoryProvider
          .overrideWithValue(_FakeProviderRepository(offlineIds)),
      providerFactoryProvider.overrideWithValue(_FakeProviderFactory()),
      providerManagerProvider.overrideWithValue(_FakeProviderManager()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [ProviderHealthBanner()],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when every source is healthy', (tester) async {
    await tester.pumpWidget(_harness(const {}));
    await tester.pumpAndSettle();

    expect(find.byType(ProviderHealthBanner), findsOneWidget);
    expect(find.text('Gelbooru'), findsNothing);
    expect(find.text('Check sources'), findsNothing);
  });

  testWidgets('names an offline source and offers the check screen',
      (tester) async {
    await tester.pumpWidget(_harness(const {'gelbooru'}));
    await tester.pumpAndSettle();

    expect(find.text('1 source unavailable'), findsOneWidget);
    expect(find.text('Gelbooru'), findsOneWidget);
    expect(find.text('Check sources'), findsOneWidget);
    // Only the failing source is named.
    expect(find.text('e621'), findsNothing);
  });

  testWidgets('counts several failing sources', (tester) async {
    await tester.pumpWidget(_harness(const {'gelbooru', 'e621'}));
    await tester.pumpAndSettle();

    expect(find.text('2 sources unavailable'), findsOneWidget);
    expect(find.text('Gelbooru, e621'), findsOneWidget);
  });

  testWidgets('a source with no recorded health is not reported',
      (tester) async {
    await tester.pumpWidget(_harness(const {}));
    await tester.pumpAndSettle();

    // `unknown`/absent health means "never checked", not "down".
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('auto-dismisses after duration', (tester) async {
    await tester.pumpWidget(_harness(const {'gelbooru'}));
    await tester.pump();
    expect(find.text('1 source unavailable'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('1 source unavailable'), findsNothing);
  });

  testWidgets('does not show banner when disabled in settings', (tester) async {
    final harnessDisabled = ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          (ref) => AppSettings.defaults.copyWith(
            languageCode: 'en',
            showProviderHealthBanner: false,
          ),
        ),
        providerRepositoryProvider
            .overrideWithValue(_FakeProviderRepository({'gelbooru'})),
        providerFactoryProvider.overrideWithValue(_FakeProviderFactory()),
        providerManagerProvider.overrideWithValue(_FakeProviderManager()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [ProviderHealthBanner()],
          ),
        ),
      ),
    );

    await tester.pumpWidget(harnessDisabled);
    await tester.pump();
    expect(find.text('1 source unavailable'), findsNothing);
  });
}
