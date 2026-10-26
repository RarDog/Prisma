import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/core/models/post.dart';

/// Post navigation goes through go_router so deep links and the back
/// stack behave the same as every other screen.
class AppNavigator {
  const AppNavigator._();

  static Future<void> openPost(
    BuildContext context, {
    required Post post,
    List<Post>? postsList,
    bool fromFeed = false,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await context.push(
      '/post/${post.providerId}/${post.id}',
      extra: PostNavigationContext(
        currentPost: post,
        posts: postsList ?? const <Post>[],
        fromFeed: fromFeed,
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static Future<void> openSimilarPosts(
    BuildContext context, {
    required Post post,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await context.push(
      '/post/${post.providerId}/${post.id}/similar',
      extra: post,
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
