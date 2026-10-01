import 'package:flutter/material.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_screen.dart';
import 'package:gel_rule_app/features/post/presentation/similar_posts_screen.dart';

class AppNavigator {
  const AppNavigator._();

  static Future<void> openPost(
    BuildContext context, {
    required Post post,
    List<Post>? postsList,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => PostDetailsScreen(
          providerId: post.providerId,
          postId: post.id,
          initialPost: post,
          postsList: postsList,
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static Future<void> openSimilarPosts(
    BuildContext context, {
    required Post post,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => SimilarPostsScreen(
          providerId: post.providerId,
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
