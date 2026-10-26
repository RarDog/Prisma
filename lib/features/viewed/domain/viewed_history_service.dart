import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/viewed/models/viewed_post.dart';
import 'package:gel_rule_app/features/feed/data/post_repository.dart';
import 'package:gel_rule_app/features/viewed/data/viewed_post_repository.dart';

class ViewedHistoryService {
  ViewedHistoryService(this._repository, this._postRepository);

  final ViewedPostRepository _repository;
  final PostRepository _postRepository;

  Future<Result<void>> markViewed(Post post) async {
    final cacheResult = await _postRepository.cachePosts([post]);
    if (cacheResult is Error<void>) return cacheResult;
    return _repository.markViewed(post.providerId, post.id);
  }

  Future<Result<bool>> isViewed(String postId, String providerId) {
    return _repository.exists(providerId, postId);
  }

  Future<Result<Set<String>>> getViewedKeys() {
    return _repository.keys();
  }

  Future<Result<List<Post>>> getViewedPosts() async {
    final viewedResult = await _repository.recent();
    if (viewedResult is Error<List<ViewedPost>>) {
      return Error(viewedResult.failure);
    }
    final viewed = (viewedResult as Success<List<ViewedPost>>).data;
    return _postRepository.getCachedPostsByKeys(
      viewed.map((item) => item.viewedKey),
    );
  }

  Future<Result<List<ViewedPostEntry>>> getViewedPostEntries() async {
    final viewedResult = await _repository.recent();
    if (viewedResult is Error<List<ViewedPost>>) {
      return Error(viewedResult.failure);
    }
    final viewed = (viewedResult as Success<List<ViewedPost>>).data;
    final postsResult = await _postRepository.getCachedPostsByKeys(
      viewed.map((item) => item.viewedKey),
    );
    if (postsResult is Error<List<Post>>) {
      return Error(postsResult.failure);
    }
    final postsByKey = {
      for (final post in (postsResult as Success<List<Post>>).data)
        post.cacheKey: post,
    };
    return Success([
      for (final item in viewed)
        if (postsByKey[item.viewedKey] != null)
          ViewedPostEntry(
              post: postsByKey[item.viewedKey]!, viewedAt: item.viewedAt),
    ]);
  }

  Future<Result<void>> deleteItem(String providerId, String postId) {
    return _repository.deleteItem(providerId, postId);
  }

  Future<Result<void>> clearHistory() {
    return _repository.clear();
  }
}

class ViewedPostEntry {
  const ViewedPostEntry({required this.post, required this.viewedAt});

  final Post post;
  final DateTime viewedAt;
}
