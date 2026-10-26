import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';

ContentProviderConfig _config(String id, String apiType) =>
    ContentProviderConfig(
      id: id,
      name: id,
      baseUrl: 'https://example.com',
      apiType: apiType,
      enabled: true,
      priority: 0,
      timeoutSeconds: 20,
      customHeaders: const {},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _FakeProviderRepository extends Fake implements ProviderRepository {
  final List<ProviderHealth> savedHealth = [];

  @override
  Future<Result<void>> ensureSeedProviders() async => const Success(null);

  @override
  Future<Result<List<ContentProviderConfig>>> getProviders({
    bool enabledOnly = false,
  }) async =>
      Success([
        _config('gelbooru', 'gelbooru'),
        _config('e621', 'e621'),
        _config('fapello', 'fapello'),
      ]);

  @override
  Future<Result<ContentProviderConfig?>> getProvider(String providerId) async =>
      Success(<String, ContentProviderConfig>{
        for (final config in [
          _config('gelbooru', 'gelbooru'),
          _config('e621', 'e621'),
          _config('fapello', 'fapello'),
        ])
          config.id: config,
      }[providerId]);

  @override
  Future<Result<void>> saveHealth(ProviderHealth health) async {
    savedHealth.add(health);
    return const Success(null);
  }
}

class _FakeProviderFactory extends Fake implements ProviderFactory {
  _FakeProviderFactory(this.healthByType);

  final Map<String, ProviderStatus> healthByType;

  @override
  ContentProvider create(ContentProviderConfig config) => _FakeProvider(
        config,
        healthByType[config.apiType] ?? ProviderStatus.online,
      );
}

class _FakeProvider implements ContentProvider {
  _FakeProvider(this._config, this._status);

  final ContentProviderConfig _config;
  final ProviderStatus _status;

  @override
  String get id => _config.id;

  @override
  String get name => _config.name;

  @override
  String get baseUrl => _config.baseUrl;

  @override
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
      };

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async =>
      const [];

  @override
  Future<Post?> getPost(String id) async => null;

  @override
  Future<ProviderHealth> checkHealth() async => ProviderHealth(
        providerId: id,
        status: _status,
        pingMs: 7,
        lastCheckedAt: DateTime(2026, 1, 1),
        apiVersion: _config.apiType,
      );
}

void main() {
  test('checkOne persists the health of the requested provider', () async {
    final repository = _FakeProviderRepository();
    final service = ProviderCheckService(
      repository,
      _FakeProviderFactory(const {}),
      ProviderManager(repository, _FakeProviderFactory(const {})),
    );

    final result = await service.checkOne('gelbooru');

    expect(result, isA<Success<ProviderHealth>>());
    final health = (result as Success<ProviderHealth>).data;
    expect(health.providerId, 'gelbooru');
    expect(health.isOnline, isTrue);
    expect(repository.savedHealth, hasLength(1));
  });

  test('checkOne surfaces an offline source', () async {
    final service = ProviderCheckService(
      _FakeProviderRepository(),
      _FakeProviderFactory(const {'fapello': ProviderStatus.offline}),
      ProviderManager(
          _FakeProviderRepository(), _FakeProviderFactory(const {})),
    );

    final result = await service.checkOne('fapello');
    final health = (result as Success<ProviderHealth>).data;

    expect(health.isOnline, isFalse);
    expect(health.status, ProviderStatus.offline);
  });

  test('checkOne reports a missing provider as an error', () async {
    final service = ProviderCheckService(
      _FakeProviderRepository(),
      _FakeProviderFactory(const {}),
      ProviderManager(
          _FakeProviderRepository(), _FakeProviderFactory(const {})),
    );

    final result = await service.checkOne('missing');

    expect(result, isA<Error<ProviderHealth>>());
    expect((result as Error<ProviderHealth>).failure.code, 'not_found');
  });

  test('checkAll checks every enabled provider and persists each result',
      () async {
    // Exercises the real ProviderManager fan-out, including `_runLimited`.
    final repository = _FakeProviderRepository();
    final factory =
        _FakeProviderFactory(const {'fapello': ProviderStatus.offline});
    final service = ProviderCheckService(
      repository,
      factory,
      ProviderManager(repository, factory),
    );

    final result = await service.checkAll();

    expect(result, isA<Success<List<ProviderHealth>>>());
    final health = (result as Success<List<ProviderHealth>>).data;
    expect(health, hasLength(3));
    expect(health.map((h) => h.providerId),
        unorderedEquals(['gelbooru', 'e621', 'fapello']));
    expect(
      health.where((h) => h.isOnline).map((h) => h.providerId),
      unorderedEquals(['gelbooru', 'e621']),
    );
    // Every result is persisted, so the health banners refresh.
    expect(repository.savedHealth, hasLength(3));
    expect(
      repository.savedHealth.map((h) => h.providerId),
      unorderedEquals(['gelbooru', 'e621', 'fapello']),
    );
  });
}
