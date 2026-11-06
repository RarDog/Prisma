import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/provider_diagnostics.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/danbooru_provider.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/provider_manager.dart';

class _FakeProviderRepository extends Fake implements ProviderRepository {
  final configs = <String, ContentProviderConfig>{};
  final health = <String, ProviderHealth>{};

  @override
  Future<Result<void>> deleteProvider(String id) async => const Success(null);

  @override
  Future<Result<void>> ensureSeedProviders() async => const Success(null);

  @override
  Future<Result<List<ProviderDiagnostics>>> getDiagnostics() async =>
      const Success([]);

  @override
  Future<Result<ContentProviderConfig?>> getProvider(String id) async =>
      Success(configs[id]);

  @override
  Future<Result<List<ContentProviderConfig>>> getProviders({
    bool enabledOnly = false,
  }) async =>
      Success(configs.values.toList());

  @override
  Future<Result<void>> saveDiagnostics(ProviderDiagnostics diagnostics) async =>
      const Success(null);

  @override
  Future<Result<void>> saveHealth(ProviderHealth h) async {
    health[h.providerId] = h;
    return const Success(null);
  }

  @override
  Future<Result<void>> saveProvider(ContentProviderConfig config) async {
    configs[config.id] = config;
    return const Success(null);
  }
}

class _DirectProviderFactory extends ProviderFactory {
  _DirectProviderFactory(this.providers);
  final Map<String, ContentProvider> providers;

  @override
  ContentProvider create(ContentProviderConfig config) => providers[config.id]!;
}

void main() {
  group('DanbooruProvider tag limits and 422 fallback', () {
    test('implements TagLimitProvider with maxSearchTags == 2', () {
      final dio = Dio();
      final client = DioClient(dio: dio);
      final provider = DanbooruProvider(
        id: 'danbooru',
        name: 'Danbooru',
        baseUrl: 'https://danbooru.donmai.us',
        dioClient: client,
      );

      expect(provider, isA<TagLimitProvider>());
      expect((provider as TagLimitProvider).maxSearchTags, 2);
    });

    test('truncates tags to at most 2 when sending query to Danbooru', () async {
      String? sentTags;
      final dio = Dio()
        ..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            sentTags = options.queryParameters['tags'] as String?;
            handler.resolve(Response(
              requestOptions: options,
              data: [],
              statusCode: 200,
            ));
          },
        ));
      final client = DioClient(dio: dio);
      final provider = DanbooruProvider(
        id: 'danbooru',
        name: 'Danbooru',
        baseUrl: 'https://danbooru.donmai.us',
        dioClient: client,
      );

      await provider.searchPosts(
        tags: ['solo', '1girl', 'cat_ears', 'smile'],
        page: 0,
        rating: 'general',
      );

      expect(sentTags, isNotNull);
      final tagsList = sentTags!.split(' ').where((t) => t.isNotEmpty).toList();
      expect(tagsList.length, lessThanOrEqualTo(2));
      expect(tagsList, contains('rating:general'));
    });

    test('gracefully returns empty list on HTTP 422 without throwing', () async {
      final dio = Dio()
        ..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 422,
                data: {'message': 'You cannot search for more than 2 tags'},
              ),
              type: DioExceptionType.badResponse,
            ));
          },
        ));
      final client = DioClient(dio: dio);
      final provider = DanbooruProvider(
        id: 'danbooru',
        name: 'Danbooru',
        baseUrl: 'https://danbooru.donmai.us',
        dioClient: client,
      );

      final result = await provider.searchPosts(
        tags: ['tag1', 'tag2', 'tag3'],
        page: 0,
      );

      expect(result, isEmpty);
    });
  });

  group('ProviderManager 422 offline safety', () {
    test('does not mark provider offline when response is 422', () async {
      final dio = Dio()
        ..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 422,
                data: 'Unprocessable Entity',
              ),
              type: DioExceptionType.badResponse,
            ));
          },
        ));
      final client = DioClient(dio: dio);
      final provider = DanbooruProvider(
        id: 'danbooru',
        name: 'Danbooru',
        baseUrl: 'https://danbooru.donmai.us',
        dioClient: client,
      );

      final repo = _FakeProviderRepository()
        ..configs['danbooru'] = ContentProviderConfig(
          id: 'danbooru',
          name: 'Danbooru',
          baseUrl: 'https://danbooru.donmai.us',
          apiType: 'danbooru',
          enabled: true,
          priority: 1,
          timeoutSeconds: 5,
          customHeaders: const {},
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );

      final manager = ProviderManager(
        repo,
        _DirectProviderFactory({'danbooru': provider}),
      );

      await manager.searchAcrossProviders(
        tags: ['tag1', 'tag2', 'tag3'],
        page: 0,
        providerId: 'danbooru',
      );

      // Verify Danbooru was NOT recorded as offline
      expect(repo.health['danbooru']?.status, isNot(ProviderStatus.offline));
    });
  });
}
