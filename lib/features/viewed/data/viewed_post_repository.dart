import 'package:isar/isar.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/viewed/models/viewed_post.dart';

class ViewedPostRepository {
  ViewedPostRepository(this._databaseService);

  final DatabaseService _databaseService;

  /// Growth cap: viewed history used to grow unbounded — every opened post
  /// added a row forever. Oldest entries beyond the cap are pruned on write.
  static const _retentionCap = 5000;

  Future<Result<void>> markViewed(String providerId, String postId) {
    return _databaseService.safeWrite((isar) async {
      final key = ViewedPost.keyFor(providerId, postId);
      await isar.viewedPostEntitys.put(
        ViewedPostEntity.fromModel(
          ViewedPost(
            viewedKey: key,
            providerId: providerId,
            postId: postId,
            viewedAt: DateTime.now(),
          ),
        ),
      );
      final count = await isar.viewedPostEntitys.count();
      if (count <= _retentionCap) return;
      final staleIds = await isar.viewedPostEntitys
          .where()
          .sortByViewedAt()
          .limit(count - _retentionCap)
          .isarIdProperty()
          .findAll();
      if (staleIds.isNotEmpty) {
        await isar.viewedPostEntitys.deleteAll(staleIds);
      }
    });
  }

  Future<Result<bool>> exists(String providerId, String postId) {
    return _databaseService.safeRead((isar) async {
      final entity = await isar.viewedPostEntitys
          .filter()
          .viewedKeyEqualTo(ViewedPost.keyFor(providerId, postId))
          .findFirst();
      return entity != null;
    });
  }

  Future<Result<Set<String>>> keys() {
    return _databaseService.safeRead((isar) async {
      final keys =
          await isar.viewedPostEntitys.where().viewedKeyProperty().findAll();
      return keys.toSet();
    });
  }

  Future<Result<List<ViewedPost>>> recent({int? limit}) {
    return _databaseService.safeRead((isar) async {
      final query = isar.viewedPostEntitys.where().sortByViewedAtDesc();
      final items = limit != null
          ? await query.limit(limit).findAll()
          : await query.findAll();
      return items.map((item) => item.toModel()).toList();
    });
  }

  Future<Result<void>> deleteItem(String providerId, String postId) {
    return _databaseService.safeWrite((isar) async {
      await isar.viewedPostEntitys.deleteByViewedKey(
        ViewedPost.keyFor(providerId, postId),
      );
    });
  }

  Future<Result<void>> clear() {
    return _databaseService.safeWrite((isar) async {
      await isar.viewedPostEntitys.clear();
    });
  }
}
