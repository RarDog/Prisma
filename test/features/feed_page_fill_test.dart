import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_state.dart';

class _FakeFeedService extends Fake implements FeedService {
  int callCount = 0;
  int postsPerCall = 3;
  int _globalPostId = 0;

  @override
  Future<Result<List<Post>>> refresh({
    List<String> tags = const [],
    String? rating,
    String? providerId,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    callCount++;
    return Success(_generatePosts(postsPerCall));
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
    callCount++;
    return Success(_generatePosts(postsPerCall));
  }

  List<Post> _generatePosts(int count) {
    return List.generate(count, (i) {
      final id = 'post_${++_globalPostId}';
      return Post(
        id: id,
        providerId: 'fake_booru',
        providerName: 'Fake Booru',
        previewUrl: 'https://example.com/preview/$id.jpg',
        sampleUrl: 'https://example.com/sample/$id.jpg',
        fileUrl: 'https://example.com/file/$id.jpg',
        tags: const ['tag1', 'tag2'],
        rating: 'general',
        width: 100,
        height: 100,
        createdAt: DateTime(2025, 1, 1),
        fileType: 'jpg',
        score: 10,
      );
    });
  }
}

class _FakeProviderManager extends Fake implements ProviderManager {
  final _softRetryController =
      StreamController<ProviderSoftRetryResult>.broadcast();

  @override
  Stream<ProviderSoftRetryResult> get softRetryResults =>
      _softRetryController.stream;

  @override
  Future<Result<List<ContentProviderConfig>>> loadFeedConfigs({
    bool enabledOnly = true,
  }) async {
    return Success([
      ContentProviderConfig(
        id: 'fake_booru',
        name: 'Fake Booru',
        baseUrl: 'https://fake.booru',
        apiType: 'danbooru',
        enabled: true,
        priority: 1,
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
      lastFeedProviderIds: ['fake_booru'],
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

void main() {
  test('FeedController loadInitial accumulates multiple raw batches when each batch is small',
      () async {
    final fakeFeedService = _FakeFeedService()..postsPerCall = 8;
    final container = ProviderContainer(
      overrides: [
        feedServiceProvider.overrideWithValue(fakeFeedService),
        providerManagerProvider.overrideWithValue(_FakeProviderManager()),
        settingsServiceProvider.overrideWithValue(_FakeSettingsService()),
        providerRepositoryProvider.overrideWithValue(_FakeProviderRepository()),
      ],
    );
    addTearDown(container.dispose);

    // Trigger controller build and loadInitial
    container.read(feedControllerProvider.notifier);

    // Wait until loadInitial completes and populates posts
    FeedState? state;
    for (var i = 0; i < 50; i++) {
      state = container.read(feedControllerProvider).value;
      if (state != null && state.posts.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(state, isNotNull);

    // With 8 posts per call and target >= 30, it should have called feed service 4 times (32 posts)
    expect(fakeFeedService.callCount, greaterThan(1));
    expect(state!.posts.length, greaterThanOrEqualTo(30));
  });

  test('FeedController loadNextPage accumulates up to target page size or max attempts',
      () async {
    final fakeFeedService = _FakeFeedService()..postsPerCall = 10;
    final container = ProviderContainer(
      overrides: [
        feedServiceProvider.overrideWithValue(fakeFeedService),
        providerManagerProvider.overrideWithValue(_FakeProviderManager()),
        settingsServiceProvider.overrideWithValue(_FakeSettingsService()),
        providerRepositoryProvider.overrideWithValue(_FakeProviderRepository()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(feedControllerProvider.notifier);
    FeedState? state;
    for (var i = 0; i < 50; i++) {
      state = container.read(feedControllerProvider).value;
      if (state != null && state.posts.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(state, isNotNull);

    final initialCount = state!.posts.length;
    fakeFeedService.callCount = 0;

    await controller.loadNextPage();

    final nextState = container.read(feedControllerProvider).value!;
    // With 10 posts per call and target 30, it should fetch 3 batches
    expect(fakeFeedService.callCount, greaterThanOrEqualTo(3));
    expect(nextState.posts.length - initialCount, greaterThanOrEqualTo(30));
  });

  test('FeedController stops and marks hasMore false when upstream runs out of posts',
      () async {
    final fakeFeedService = _FakeFeedService()..postsPerCall = 0;
    final container = ProviderContainer(
      overrides: [
        feedServiceProvider.overrideWithValue(fakeFeedService),
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
      if (state != null && fakeFeedService.callCount >= 3) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(state, isNotNull);
    expect(state!.posts, isEmpty);
    expect(state.hasMore, isFalse);
    expect(fakeFeedService.callCount, equals(3));
  });
}
