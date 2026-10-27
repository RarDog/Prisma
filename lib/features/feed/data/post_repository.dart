import 'package:isar/isar.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/core/models/post.dart';

class PostRepository {
  PostRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<Result<void>> cachePosts(List<Post> posts) {
    return _databaseService.safeWrite((isar) async {
      await isar.cachedPostEntitys.putAll(
        posts.map((post) => CachedPostEntity.fromModel(post)).toList(),
      );
    });
  }

  Future<Result<Post?>> getCachedPost(String postId, String providerId) {
    return _databaseService.safeRead((isar) async {
      final entity = await isar.cachedPostEntitys
          .filter()
          .providerIdEqualTo(providerId)
          .postIdEqualTo(postId)
          .findFirst();
      return entity?.toModel();
    });
  }

  Future<Result<List<Post>>> getCachedPostsByKeys(Iterable<String> keys) {
    return _databaseService.safeRead((isar) async {
      // One indexed query per ~64 keys instead of a findFirst round-trip per
      // key; result order follows the caller's key order.
      final wanted = keys.toSet();
      if (wanted.isEmpty) return const [];
      final byKey = <String, Post>{};
      for (var i = 0; i < wanted.length; i += 64) {
        final chunk = wanted.skip(i).take(64).toList();
        final entities = await isar.cachedPostEntitys
            .filter()
            .anyOf(chunk, (q, String key) => q.cacheKeyEqualTo(key))
            .findAll();
        for (final entity in entities) {
          byKey[entity.cacheKey] = entity.toModel();
        }
      }
      return [
        for (final key in wanted)
          if (byKey[key] != null) byKey[key]!,
      ];
    });
  }
}
