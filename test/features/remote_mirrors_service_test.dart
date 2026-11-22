import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/providers/domain/remote_mirrors_service.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/features/providers/models/remote_mirrors_config.dart';
import 'package:gel_rule_app/sources/provider_manager.dart';

class _FakeProviderRepository extends Fake implements ProviderRepository {
  final Map<String, ContentProviderConfig> providers = {};

  @override
  Future<Result<List<ContentProviderConfig>>> getProviders({
    bool enabledOnly = false,
  }) async {
    return Success(providers.values.toList());
  }

  @override
  Future<Result<ContentProviderConfig?>> getProvider(String id) async {
    return Success(providers[id]);
  }

  @override
  Future<Result<void>> saveProvider(ContentProviderConfig config) async {
    providers[config.id] = config;
    return const Success(null);
  }

  @override
  Future<void> clearCredentials(String id) async {}

  @override
  Future<Result<void>> deleteProvider(String id) async {
    providers.remove(id);
    return const Success(null);
  }
}

class _FakeProviderManager extends Fake implements ProviderManager {
  int invalidationCount = 0;

  @override
  void invalidateConfigCache() {
    invalidationCount++;
  }
}

void main() {
  group('RemoteMirrorsConfig JSON parsing', () {
    test('parses complete mirrors payload', () {
      final json = {
        'version': 2,
        'updated_at': '2026-11-18',
        'broadcast_message': {
          'id': 'msg_1',
          'active': true,
          'title_ru': 'Важное объявление',
          'message_ru': 'Зеркала обновлены',
          'title_en': 'Notice',
          'message_en': 'Mirrors updated',
        },
        'mirrors': {
          'mangalib': {
            'baseUrl': 'https://mangalib.me',
            'customHeaders': {'Site-Id': '1'},
          },
          'fapello': {
            'baseUrl': 'https://fapello.is',
          },
        },
      };

      final config = RemoteMirrorsConfig.fromJson(json);
      expect(config.version, 2);
      expect(config.broadcast?.active, isTrue);
      expect(config.broadcast?.title(true), 'Важное объявление');
      expect(config.broadcast?.title(false), 'Notice');
      expect(config.mirrors.length, 2);
      expect(config.mirrors['mangalib']?.baseUrl, 'https://mangalib.me');
      expect(config.mirrors['mangalib']?.customHeaders?['Site-Id'], '1');
      expect(config.mirrors['fapello']?.baseUrl, 'https://fapello.is');
    });

    test('parses empty or invalid payload safely', () {
      final config = RemoteMirrorsConfig.fromJson({});
      expect(config.version, 1);
      expect(config.broadcast, isNull);
      expect(config.mirrors, isEmpty);
    });
  });

  group('RemoteMirrorsService sync', () {
    late _FakeProviderRepository repo;
    late _FakeProviderManager manager;
    final now = DateTime(2026, 1, 1);

    setUp(() {
      repo = _FakeProviderRepository();
      manager = _FakeProviderManager();

      repo.providers['mangalib'] = ContentProviderConfig(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://old-mangalib.me',
        apiType: 'mangalib',
        enabled: true,
        priority: 1,
        timeoutSeconds: 10,
        customHeaders: const {'Site-Id': '1', 'api_key': 'secret_123'},
        createdAt: now,
        updatedAt: now,
      );
      repo.providers['rule34'] = ContentProviderConfig(
        id: 'rule34',
        name: 'Rule34',
        baseUrl: 'https://api.rule34.xxx',
        apiType: 'rule34',
        enabled: true,
        priority: 2,
        timeoutSeconds: 10,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      );
    });

    test('updates provider baseUrl and non-secret headers without touching secrets',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'version': 1,
                  'mirrors': {
                    'mangalib': {
                      'baseUrl': 'https://new-mangalib.me',
                      'customHeaders': {
                        'Site-Id': '2',
                        'api_key': 'should_not_overwrite',
                      },
                    },
                  },
                },
              ),
            );
          },
        ),
      );

      final service = RemoteMirrorsService(
        dio: dio,
        providerRepository: repo,
        providerManager: manager,
      );

      final result = await service.syncMirrors(force: true);
      expect(result.isSuccess, isTrue);
      final syncResult = (result as Success<RemoteMirrorsSyncResult>).data;
      expect(syncResult.updatedCount, 1);
      expect(manager.invalidationCount, 1);

      final updated = repo.providers['mangalib']!;
      expect(updated.baseUrl, 'https://new-mangalib.me');
      expect(updated.customHeaders['Site-Id'], '2');
      // Secret header api_key should be untouched!
      expect(updated.customHeaders['api_key'], 'secret_123');
    });

    test('skips update if provider baseUrl and headers are already identical',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'version': 1,
                  'mirrors': {
                    'rule34': {
                      'baseUrl': 'https://api.rule34.xxx',
                    },
                  },
                },
              ),
            );
          },
        ),
      );

      final service = RemoteMirrorsService(
        dio: dio,
        providerRepository: repo,
        providerManager: manager,
      );

      final result = await service.syncMirrors(force: true);
      expect(result.isSuccess, isTrue);
      final syncResult = (result as Success<RemoteMirrorsSyncResult>).data;
      expect(syncResult.updatedCount, 0);
      expect(manager.invalidationCount, 0);
    });

    test('debounces sync within 12 hours when force is false', () async {
      int requestCount = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            return handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'version': 1,
                  'mirrors': {},
                },
              ),
            );
          },
        ),
      );

      final service = RemoteMirrorsService(
        dio: dio,
        providerRepository: repo,
        providerManager: manager,
      );

      final first = await service.syncMirrors();
      expect(first.isSuccess, isTrue);
      expect(requestCount, 1);

      // Second call immediately without force should be debounced
      final second = await service.syncMirrors(force: false);
      expect(second.isSuccess, isTrue);
      expect(requestCount, 1);

      // Force call should bypass debounce
      final third = await service.syncMirrors(force: true);
      expect(third.isSuccess, isTrue);
      expect(requestCount, 2);
    });

    test('handles network failure gracefully without throwing', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Network unreachable',
              ),
            );
          },
        ),
      );

      final service = RemoteMirrorsService(
        dio: dio,
        providerRepository: repo,
        providerManager: manager,
      );

      final result = await service.syncMirrors(force: true);
      expect(result.isSuccess, isFalse);
    });
  });
}
