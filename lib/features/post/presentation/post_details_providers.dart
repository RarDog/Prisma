import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/sources/mappers/pixiv_mapper.dart';
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

  String get baseId => post.id.split('_p').first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostPagesArgs &&
          post.providerId == other.post.providerId &&
          baseId == other.baseId;

  @override
  int get hashCode => Object.hash(post.providerId, baseId);
}

final postPagesProvider = FutureProvider.autoDispose
    .family<List<Post>, PostPagesArgs>((ref, args) async {
  final post = args.post;
  final isPixiv = post.providerId == 'pixiv';
  if (!post.isMultiPage && args.post.pageCount <= 1 && !isPixiv) {
    return [post];
  }
  final result = await ref.watch(providerManagerProvider).getPostPages(post);
  if (result is Success<List<Post>> && result.data.length > 1) {
    return result.data;
  }
  if (isPixiv && (post.isMultiPage || post.pageCount > 1)) {
    return PixivMapper.synthesizePages(post);
  }
  return result is Success<List<Post>> && result.data.isNotEmpty
      ? result.data
      : [post];
});
