import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_state.dart';

class _FakeMultiFeedService extends Fake implements FeedService {
  List<Post> nextPosts = [];

  @override
  Future<Result<List<Post>>> refresh({
    List<String> tags = const [],
    String? rating,
    String? providerId,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    return Success(nextPosts);
  }

  @override
  Future<Result<List<Post>>> loadNextPage({
    List<String> tags = const [],
    String? rating,
    String? providerId,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    return const Success([]);
  }
}

class _FakeProviderManager extends Fake implements ProviderManager {
  final _softRetryController =
      StreamController<ProviderSoftRetryResult>.broadcast();

  @override
  Stream<ProviderSoftRetryResult> get softRetryResults =>
      _softRetryController.stream;

  void emitSoftRetry(ProviderSoftRetryResult result) {
    _softRetryController.add(result);
  }

  @override
  Future<Result<List<ContentProviderConfig>>> loadFeedConfigs({
    bool enabledOnly = true,
  }) async {
    return Success([
      ContentProviderConfig(
        id: 'danbooru',
        name: 'Danbooru',
        baseUrl: 'https://danbooru.donmai.us',
        apiType: 'danbooru',
        enabled: true,
        priority: 1,
        timeoutSeconds: 10,
        customHeaders: const {},
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
      ContentProviderConfig(
        id: 'gelbooru',
        name: 'Gelbooru',
        baseUrl: 'https://gelbooru.com',
        apiType: 'gelbooru',
        enabled: true,
        priority: 2,
        timeoutSeconds: 10,
        customHeaders: const {},
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    ]);
  }
}

class _FakeSettingsService extends Fake implements SettingsService {
  @override
  Future<Result<AppSettings>> getSettings() async {
    return Success(AppSettings.defaults.copyWith(
      lastFeedProviderIds: ['danbooru', 'gelbooru'],
    ));
  }

  @override
  Future<Result<void>> updateSettings(AppSettings settings) async {
    return const Success(null);
  }
}

class _FakeProviderRepository extends Fake implements ProviderRepository {
  @override
  Future<Result<List<ProviderDiagnostics>>> getDiagnostics() async {
    return const Success([]);
  }
}

Post _samplePost({
  required String id,
  required String providerId,
  String? md5,
  String? fileUrl,
}) {
  return Post(
    id: id,
    providerId: providerId,
    providerName: providerId,
    previewUrl: 'https://example.com/$id.jpg',
    sampleUrl: 'https://example.com/$id.jpg',
    fileUrl: fileUrl ?? 'https://example.com/$id.jpg',
    tags: const ['tag1'],
    rating: 'general',
    width: 100,
    height: 100,
    createdAt: DateTime(2025, 1, 1),
    fileType: 'jpg',
    score: 10,
    tagGroups: {
      if (md5 != null) 'md5': [md5],
    },
  );
}

void main() {
  group('Post content deduplication key', () {
    test('extracts md5 from tagGroups', () {
      final post = _samplePost(
        id: '1',
        providerId: 'danbooru',
        md5: '2be732d6406d6f4c64818f1bf7fb2a03',
      );
      expect(post.contentDedupeKey, 'md5:2be732d6406d6f4c64818f1bf7fb2a03');
    });

    test('extracts md5 from fileUrl filename if tagGroups has no md5', () {
      final post = _samplePost(
        id: '2',
        providerId: 'gelbooru',
        fileUrl: 'https://gelbooru.com/images/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.jpg',
      );
      expect(post.contentDedupeKey, 'md5:2be732d6406d6f4c64818f1bf7fb2a03');
    });

    test('falls back to cacheKey when no 32-char hex md5 is found', () {
      final post = _samplePost(
        id: '123',
        providerId: 'pixiv',
        fileUrl: 'https://i.pximg.net/img-original/img/2025/01/01/123_p0.jpg',
      );
      expect(post.contentDedupeKey, 'pixiv:123');
    });
  });

  group('FeedController cross-provider deduplication and soft retry', () {
    test('deduplicates identical images across Danbooru and Gelbooru by md5',
        () async {
      final postDan = _samplePost(
        id: '100',
        providerId: 'danbooru',
        md5: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final postGel = _samplePost(
        id: '200',
        providerId: 'gelbooru',
        md5: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', // same md5
      );
      final postOther = _samplePost(
        id: '300',
        providerId: 'gelbooru',
        md5: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );

      final fakeService = _FakeMultiFeedService()
        ..nextPosts = [postDan, postGel, postOther];

      final container = ProviderContainer(
        overrides: [
          feedServiceProvider.overrideWithValue(fakeService),
          providerManagerProvider.overrideWithValue(_FakeProviderManager()),
          settingsServiceProvider.overrideWithValue(_FakeSettingsService()),
          providerRepositoryProvider.overrideWithValue(_FakeProviderRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(feedControllerProvider.notifier);

      FeedState? state;
      for (var i = 0; i < 50; i++) {
        state = container.read(feedControllerProvider).value;
        if (state != null && state.posts.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(state, isNotNull);
      // postDan and postGel share the same MD5, so only 2 distinct posts must be kept
      expect(state!.posts.length, 2);
      expect(state.posts.map((p) => p.contentDedupeKey).toSet().length, 2);
    });

    test('soft retry appends new posts without shuffling existing posts', () async {
      final post1 = _samplePost(id: '1', providerId: 'danbooru');
      final post2 = _samplePost(id: '2', providerId: 'danbooru');
      final retryPost = _samplePost(id: '3', providerId: 'gelbooru');

      final fakeService = _FakeMultiFeedService()..nextPosts = [post1, post2];
      final fakeManager = _FakeProviderManager();

      final container = ProviderContainer(
        overrides: [
          feedServiceProvider.overrideWithValue(fakeService),
          providerManagerProvider.overrideWithValue(fakeManager),
          settingsServiceProvider.overrideWithValue(_FakeSettingsService()),
          providerRepositoryProvider.overrideWithValue(_FakeProviderRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(feedControllerProvider.notifier);

      FeedState? state;
      for (var i = 0; i < 50; i++) {
        state = container.read(feedControllerProvider).value;
        if (state != null && state.posts.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(state, isNotNull);
      final initialOrder = state!.posts.map((p) => p.id).toList();

      // Emit soft retry with a new post
      fakeManager.emitSoftRetry(
        ProviderSoftRetryResult(
          providerId: 'gelbooru',
          posts: [retryPost],
          page: 0,
          limit: 50,
          tags: state.selectedTags,
          rating: state.ratingFilter,
          topPeriod: state.topPeriodFilter,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final updatedState = container.read(feedControllerProvider).value!;

      expect(updatedState.posts.length, 3);
      // Existing first two posts must maintain their exact positions
      expect(updatedState.posts[0].id, initialOrder[0]);
      expect(updatedState.posts[1].id, initialOrder[1]);
      expect(updatedState.posts[2].id, '3');
    });
  });
}
