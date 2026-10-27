import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:gel_rule_app/core/cache/cache_service.dart';
import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/result.dart';

/// Pins the data-safety contract of CacheService: favorites, collections and
/// viewed history resolve their posts through `cachedPostEntitys`, so cache
/// eviction and "clear cache" must never destroy the rows they depend on.
void main() {
  late Directory directory;
  late AppDatabase database;
  late DatabaseService databaseService;
  late CacheService cacheService;

  setUpAll(() async {
    if (Platform.isLinux) {
      await Isar.initializeIsarCore(
        libraries: {
          Abi.linuxX64:
              '${Directory.current.path}/third_party/isar_flutter_libs/linux/libisar.so',
        },
      );
    }
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prisma_cache_pin_test_');
    database = await AppDatabase.open(directory: directory.path);
    databaseService = DatabaseService(database);
    cacheService = CacheService(databaseService);
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  Post post(String id) => Post(
        id: id,
        providerId: 'danbooru',
        providerName: 'Danbooru',
        previewUrl: 'https://example.com/$id.jpg',
        sampleUrl: 'https://example.com/$id.jpg',
        fileUrl: 'https://example.com/$id.jpg',
        tags: const [],
        rating: 's',
        width: 800,
        height: 600,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 0,
      );

  Future<void> seedCachedPost(String id) async {
    final res = await cacheService.cachePosts([post(id)]);
    expect(res, isA<Success<void>>());
  }

  Future<void> seedFavorite(String id) async {
    final res = await databaseService.safeWrite((isar) async {
      await isar.favoriteEntitys.put(
        FavoriteEntity()
          ..favoriteKey = 'danbooru:$id'
          ..favoriteId = 'danbooru:$id'
          ..postId = id
          ..providerId = 'danbooru'
          ..savedAt = DateTime.now(),
      );
    });
    expect(res, isA<Success<void>>());
  }

  Future<void> seedViewed(String id) async {
    final res = await databaseService.safeWrite((isar) async {
      await isar.viewedPostEntitys.put(
        ViewedPostEntity()
          ..viewedKey = 'danbooru:$id'
          ..postId = id
          ..providerId = 'danbooru'
          ..viewedAt = DateTime.now(),
      );
    });
    expect(res, isA<Success<void>>());
  }

  Future<void> seedCollectionPost(String id) async {
    final res = await databaseService.safeWrite((isar) async {
      await isar.collectionPostEntitys.put(
        CollectionPostEntity()
          ..linkKey = 'col1:danbooru:$id'
          ..collectionId = 'col1'
          ..postId = id
          ..providerId = 'danbooru'
          ..addedAt = DateTime.now(),
      );
    });
    expect(res, isA<Success<void>>());
  }

  Future<bool> cacheRowExists(String id) async {
    final res = await databaseService.safeRead((isar) async {
      return await isar.cachedPostEntitys
              .filter()
              .cacheKeyEqualTo('danbooru:$id')
              .count() >
          0;
    });
    return res is Success<bool> && res.data;
  }

  test('overflow eviction keeps rows pinned by favorites/viewed/collections',
      () async {
    // Pinned rows are cached first (oldest cachedAt), filler rows after.
    await seedFavorite('fav');
    await seedViewed('viewed');
    await seedCollectionPost('col');
    await seedCachedPost('fav');
    await seedCachedPost('viewed');
    await seedCachedPost('col');
    // Ensure the pinned rows are genuinely the oldest ones.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (var i = 0; i < 5; i++) {
      await seedCachedPost('filler$i');
    }

    final res = await cacheService.cachePosts(
      [post('filler5')],
      maxItems: 4,
    );
    expect(res, isA<Success<void>>());

    for (final pinned in ['fav', 'viewed', 'col']) {
      expect(await cacheRowExists(pinned), isTrue,
          reason: 'pinned post "$pinned" must survive eviction');
    }
    expect(await cacheRowExists('filler0'), isFalse,
        reason: 'unpinned oldest row must be evicted');
    expect(await cacheRowExists('filler5'), isTrue,
        reason: 'newest unpinned row fits in the cap once pinned rows are skipped');
  });

  test('clear() keeps pinned rows and drops only disposable ones', () async {
    await seedFavorite('fav');
    await seedCachedPost('fav');
    await seedViewed('viewed');
    await seedCachedPost('viewed');
    await seedCachedPost('disposable');

    final res = await cacheService.clear();
    expect(res, isA<Success<void>>());

    expect(await cacheRowExists('fav'), isTrue);
    expect(await cacheRowExists('viewed'), isTrue);
    expect(await cacheRowExists('disposable'), isFalse);
  });

  test('prune(olderThan) keeps pinned rows even when they are stale',
      () async {
    await seedFavorite('old-fav');
    final res = await databaseService.safeWrite((isar) async {
      final entity = CachedPostEntity.fromModel(post('old-fav'));
      entity.cachedAt = DateTime.now().subtract(const Duration(days: 30));
      await isar.cachedPostEntitys.put(entity);
    });
    expect(res, isA<Success<void>>());
    await seedCachedPost('fresh');

    final pruned = await cacheService.prune(
      olderThan: const Duration(days: 7),
    );
    expect(pruned, isA<Success<void>>());

    expect(await cacheRowExists('old-fav'), isTrue,
        reason: 'favorite-backed row must survive age-based pruning');
    expect(await cacheRowExists('fresh'), isTrue);
  });

  test('clear() with no pinned rows wipes everything (legacy behavior)',
      () async {
    await seedCachedPost('a');
    await seedCachedPost('b');

    final res = await cacheService.clear();
    expect(res, isA<Success<void>>());

    expect(await cacheRowExists('a'), isFalse);
    expect(await cacheRowExists('b'), isFalse);
  });
}
