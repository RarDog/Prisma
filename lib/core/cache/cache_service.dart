import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/logger.dart';
import 'package:gel_rule_app/core/utils/result.dart';

class CacheService {
  CacheService(this._databaseService);

  final DatabaseService _databaseService;

  /// Clears disk image cache via DefaultCacheManager
  Future<void> clearDiskImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      AppLogger.warn('CacheService.clearDiskImageCache error', e);
    }
  }

  /// Clears temporary storage entities
  Future<void> clearTemporaryDirectory() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = await tempDir.list(recursive: false).toList();
        for (final entity in entities) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            AppLogger.debug('Failed to delete temp entity: ${entity.path}', e);
          }
        }
      }
    } catch (e) {
      AppLogger.warn('CacheService.clearTemporaryDirectory error', e);
    }
  }

  Future<Result<void>> cachePosts(
    List<Post> posts, {
    int? maxItems,
  }) {
    return _databaseService.safeWrite((isar) async {
      await isar.cachedPostEntitys.putAll(
        posts.map((post) => CachedPostEntity.fromModel(post)).toList(),
      );
      if (maxItems != null && maxItems > 0) {
        await _evictOverflow(isar, maxItems);
      }
    });
  }

  Future<Result<List<Post>>> getCachedPosts({
    Duration maxAge = const Duration(hours: 24),
  }) {
    return _databaseService.safeRead((isar) async {
      final cutoff = DateTime.now().subtract(maxAge);
      final entities = await isar.cachedPostEntitys
          .filter()
          .cachedAtGreaterThan(cutoff)
          .findAll();
      entities.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
      return entities.map((entity) => entity.toModel()).toList();
    });
  }

  Future<Result<void>> prune({
    Duration? olderThan,
    int? maxItems,
  }) {
    return _databaseService.safeWrite((isar) async {
      if (olderThan != null) {
        final cutoff = DateTime.now().subtract(olderThan);
        final stale = await isar.cachedPostEntitys
            .filter()
            .cachedAtLessThan(cutoff)
            .findAll();
        final pinned = await _pinnedKeys(isar);
        final doomedIds = [
          for (final entity in stale)
            if (!pinned.contains(entity.cacheKey)) entity.isarId,
        ];
        if (doomedIds.isNotEmpty) {
          await isar.cachedPostEntitys.deleteAll(doomedIds);
        }
      }
      if (maxItems != null && maxItems > 0) {
        await _evictOverflow(isar, maxItems);
      }
    });
  }

  /// Clears the disposable post cache. Rows backing favorites, collections
  /// and viewed history are pinned and survive the wipe.
  Future<Result<void>> clear() {
    return _databaseService.safeWrite((isar) async {
      final pinned = await _pinnedKeys(isar);
      if (pinned.isEmpty) {
        await isar.cachedPostEntitys.clear();
        return;
      }
      final entities = await isar.cachedPostEntitys.where().findAll();
      final doomedIds = [
        for (final entity in entities)
          if (!pinned.contains(entity.cacheKey)) entity.isarId,
      ];
      if (doomedIds.isNotEmpty) {
        await isar.cachedPostEntitys.deleteAll(doomedIds);
      }
    });
  }

  Future<Result<int>> getCachedPostsCount() {
    return _databaseService.safeRead((isar) async {
      return isar.cachedPostEntitys.count();
    });
  }

  /// Cache keys that back user data: favorites, collections and viewed
  /// history all resolve their posts through `cachedPostEntitys`, so those
  /// rows are pinned and never treated as disposable cache.
  Future<Set<String>> _pinnedKeys(Isar isar) async {
    final favorites = await isar.favoriteEntitys.where().findAll();
    final collectionPosts = await isar.collectionPostEntitys.where().findAll();
    final viewedKeys =
        await isar.viewedPostEntitys.where().viewedKeyProperty().findAll();
    return {
      ...favorites.map((f) => f.favoriteKey),
      ...collectionPosts.map((cp) => '${cp.providerId}:${cp.postId}'),
      ...viewedKeys,
    };
  }

  Future<void> _evictOverflow(Isar isar, int maxItems) async {
    final count = await isar.cachedPostEntitys.count();
    if (count <= maxItems) return;
    final toDelete = count - maxItems;
    final pinned = await _pinnedKeys(isar);
    // Walk rows oldest-first and evict the first [toDelete] that no
    // favorite/collection/viewed entry depends on. Pinned rows are skipped,
    // so a full cache never destroys user data.
    final overflowIds = <Id>[];
    var offset = 0;
    const pageSize = 256;
    while (overflowIds.length < toDelete) {
      final page = await isar.cachedPostEntitys
          .where()
          .sortByCachedAt()
          .offset(offset)
          .limit(pageSize)
          .findAll();
      if (page.isEmpty) break;
      for (final entity in page) {
        if (!pinned.contains(entity.cacheKey)) overflowIds.add(entity.isarId);
      }
      offset += page.length;
    }
    if (overflowIds.isEmpty) return;
    await isar.cachedPostEntitys
        .deleteAll(overflowIds.take(toDelete).toList(growable: false));
  }
}
