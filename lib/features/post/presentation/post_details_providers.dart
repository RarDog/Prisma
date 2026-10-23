import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'post_details_controller.dart';

final postNotesProvider = FutureProvider.autoDispose
    .family<List<PostNote>, PostDetailsArgs>((ref, args) async {
  final result = await ref
      .watch(providerManagerProvider)
      .getNotes(args.providerId, args.postId);
  return result is Success<List<PostNote>> ? result.data : const [];
});

final showPostNotesProvider = StateProvider.autoDispose
    .family<bool, String>((ref, postCacheKey) => false);

final postProviderInstanceProvider = FutureProvider.autoDispose
    .family<ContentProvider?, String>((ref, providerId) async {
  return ref.watch(providerManagerProvider).getProviderInstance(providerId);
});

class PostPagesArgs {
  const PostPagesArgs(this.post);
  final Post post;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostPagesArgs &&
          post.providerId == other.post.providerId &&
          post.id == other.post.id &&
          post.pageCount == other.post.pageCount;

  @override
  int get hashCode => Object.hash(post.providerId, post.id, post.pageCount);
}

final postPagesProvider = FutureProvider.autoDispose
    .family<List<Post>, PostPagesArgs>((ref, args) async {
  final post = args.post;
  final isPixivRoot = post.providerId == 'pixiv' && !post.id.contains('_p');
  if (!post.isMultiPage && args.post.pageCount <= 1 && !isPixivRoot) {
    return [post];
  }
  final result = await ref.watch(providerManagerProvider).getPostPages(post);
  return result is Success<List<Post>> && result.data.isNotEmpty
      ? result.data
      : [post];
});
