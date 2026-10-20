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

final postPagesProvider = FutureProvider.autoDispose
    .family<List<Post>, Post>((ref, post) async {
  if (!post.isMultiPage) return [post];
  final result = await ref.watch(providerManagerProvider).getPostPages(post);
  return result is Success<List<Post>> && result.data.isNotEmpty
      ? result.data
      : [post];
});
