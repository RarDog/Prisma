import 'package:flutter/material.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_screen.dart';
import 'package:gel_rule_app/features/post/presentation/similar_posts_screen.dart';

class AppNavigator {
  const AppNavigator._();

  static void openPost(
    BuildContext context, {
    required Post post,
    List<Post>? postsList,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => PostDetailsScreen(
          providerId: post.providerId,
          postId: post.id,
          initialPost: post,
          postsList: postsList,
        ),
      ),
    );
  }

  static void openSimilarPosts(
    BuildContext context, {
    required Post post,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => SimilarPostsScreen(
          providerId: post.providerId,
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
  }
}
