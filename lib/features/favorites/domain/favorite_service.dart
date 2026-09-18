import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/favorites/models/favorite.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/favorites/data/favorite_repository.dart';
import 'package:gel_rule_app/features/feed/data/post_repository.dart';
import 'package:gel_rule_app/features/downloads/domain/download_manager_service.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

class FavoriteService {
  FavoriteService(this._repository, [this._postRepository]);

  final FavoriteRepository _repository;
  final PostRepository? _postRepository;

  Future<Result<void>> addFavorite(
    Post post, {
    AppSettings settings = AppSettings.defaults,
    DownloadManagerService? downloadManager,
  }) async {
    final result = await _repository.add(post);
    if (result is Success<void> &&
        settings.autoDownloadFavorites &&
        settings.allowDownloads) {
      await downloadManager?.start(post);
    }
    return result;
  }

  Future<Result<void>> addFavorites(List<Post> posts) {
    return _repository.addAll(posts);
  }

  Future<Result<void>> removeFavorite(String postId, String providerId) {
    return _repository.remove(postId, providerId);
  }

  Future<Result<bool>> isFavorite(String postId, String providerId) {
    return _repository.exists(postId, providerId);
  }

  Future<Result<List<Favorite>>> getFavorites() => _repository.all();
  Future<Result<List<Post>>> getFavoritePosts() async {
    final postRepository = _postRepository;
    if (postRepository == null) return const Success([]);
    final favoritesResult = await _repository.all();
    if (favoritesResult is Error<List<Favorite>>) {
      return Error(favoritesResult.failure);
    }
    final favorites = (favoritesResult as Success<List<Favorite>>).data;
    return postRepository.getCachedPostsByKeys(
      favorites.map((favorite) => '${favorite.providerId}:${favorite.postId}'),
    );
  }

  Future<Result<void>> clearFavorites() => _repository.clear();
}
