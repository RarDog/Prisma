import 'package:isar/isar.dart' hide Collection;

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/collections/models/collection.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/feed/data/post_repository.dart';

class CollectionRepository {
  CollectionRepository(
    this._databaseService,
    this._postRepository, {
    this.onDataChanged,
  });

  final DatabaseService _databaseService;
  final PostRepository _postRepository;
  final void Function()? onDataChanged;

  Future<Result<Collection>> save(Collection collection) async {
    final res = await _databaseService.safeWrite((isar) async {
      await isar.collectionEntitys.put(
        CollectionEntity()
          ..collectionId = collection.id
          ..name = collection.name
          ..description = collection.description
          ..coverUrl = collection.coverUrl
          ..createdAt = collection.createdAt
          ..updatedAt = collection.updatedAt,
      );
      return collection;
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<void>> delete(String id) async {
    final res = await _databaseService.safeWrite((isar) async {
      await isar.collectionPostEntitys
          .filter()
          .collectionIdEqualTo(id)
          .deleteAll();
      await isar.collectionEntitys.deleteByCollectionId(id);
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<List<Collection>>> all() {
    return _databaseService.safeRead((isar) async {
      final items = await isar.collectionEntitys.where().findAll();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items.map((entity) => entity.toModel()).toList();
    });
  }

  Future<Result<Collection?>> getById(String id) {
    return _databaseService.safeRead((isar) async {
      final entity = await isar.collectionEntitys
          .filter()
          .collectionIdEqualTo(id)
          .findFirst();
      return entity?.toModel();
    });
  }

  Future<Result<void>> addPost(String collectionId, Post post) async {
    await _postRepository.cachePosts([post]);
    final res = await _databaseService.safeWrite((isar) async {
      await isar.collectionPostEntitys.put(
        CollectionPostEntity()
          ..linkKey = '$collectionId:${post.providerId}:${post.id}'
          ..collectionId = collectionId
          ..postId = post.id
          ..providerId = post.providerId
          ..addedAt = DateTime.now(),
      );
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<void>> addPosts(String collectionId, List<Post> posts) async {
    if (posts.isEmpty) return const Success(null);
    await _postRepository.cachePosts(posts);
    final res = await _databaseService.safeWrite((isar) async {
      final now = DateTime.now();
      await isar.collectionPostEntitys.putAll([
        for (final post in posts)
          CollectionPostEntity()
            ..linkKey = '$collectionId:${post.providerId}:${post.id}'
            ..collectionId = collectionId
            ..postId = post.id
            ..providerId = post.providerId
            ..addedAt = now,
      ]);
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<void>> removePost(
    String collectionId,
    String postId,
    String providerId,
  ) async {
    final res = await _databaseService.safeWrite((isar) async {
      await isar.collectionPostEntitys
          .filter()
          .linkKeyEqualTo('$collectionId:$providerId:$postId')
          .deleteAll();
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<List<Post>>> posts(String collectionId) {
    return _databaseService.safeRead((isar) async {
      final links = await isar.collectionPostEntitys
          .filter()
          .collectionIdEqualTo(collectionId)
          .findAll();
      links.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      final posts = <Post>[];
      for (final link in links) {
        final entity = await isar.cachedPostEntitys
            .filter()
            .providerIdEqualTo(link.providerId)
            .postIdEqualTo(link.postId)
            .findFirst();
        if (entity != null) posts.add(entity.toModel());
      }
      return posts;
    });
  }
}
