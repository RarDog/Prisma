import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:prisma_app/core/database/app_database.dart';
import 'package:prisma_app/core/database/database_service.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/utils/logger.dart';
import 'package:prisma_app/core/utils/result.dart';

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
        await isar.cachedPostEntitys
            .filter()
            .cachedAtLessThan(cutoff)
            .deleteAll();
      }
      if (maxItems != null && maxItems > 0) {
        await _evictOverflow(isar, maxItems);
      }
    });
  }

  Future<Result<void>> clear() {
    return _databaseService.safeWrite((isar) async {
      await isar.cachedPostEntitys.clear();
    });
  }

  Future<Result<int>> getCachedPostsCount() {
    return _databaseService.safeRead((isar) async {
      return isar.cachedPostEntitys.count();
    });
  }

  Future<void> _evictOverflow(Isar isar, int maxItems) async {
    final count = await isar.cachedPostEntitys.count();
    if (count <= maxItems) return;
    final toDelete = count - maxItems;
    final overflowIds = await isar.cachedPostEntitys
        .where()
        .sortByCachedAt()
        .limit(toDelete)
        .isarIdProperty()
        .findAll();
    await isar.cachedPostEntitys.deleteAll(overflowIds);
  }
}
