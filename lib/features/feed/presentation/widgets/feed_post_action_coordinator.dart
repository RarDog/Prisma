import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/collections/presentation/collection_form_dialog.dart';
import 'package:gel_rule_app/features/favorites/presentation/favorites_controller.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/shared/widgets/post_card.dart';

/// Coordinates user post actions on the feed: favoriting, collections, hiding,
/// and auto-downloading.
class FeedPostActionCoordinator {
  const FeedPostActionCoordinator._();

  /// Toggles favorite status for [post] and invalidates favorites cache.
  static Future<void> toggleFavorite(
    WidgetRef ref,
    Post post,
    Set<String> favoriteKeys,
  ) async {
    if (favoriteKeys.contains(post.cacheKey)) {
      await ref
          .read(favoriteServiceProvider)
          .removeFavorite(post.id, post.providerId);
    } else {
      await ref.read(favoriteServiceProvider).addFavorite(post);
      await maybeAutoDownloadFavorite(ref, post);
    }
    ref.invalidate(favoriteKeysProvider);
    ref.invalidate(favoritesControllerProvider);
  }

  /// Favorites all [selectedPosts] not yet favorited.
  static Future<void> favoriteSelected(
    WidgetRef ref,
    List<Post> selectedPosts, [
    Set<String>? favoriteKeys,
  ]) async {
    final keys =
        favoriteKeys ?? ref.read(favoriteKeysProvider).value ?? <String>{};
    for (final post in selectedPosts) {
      if (!keys.contains(post.cacheKey)) {
        await ref.read(favoriteServiceProvider).addFavorite(post);
        await maybeAutoDownloadFavorite(ref, post);
      }
    }
    ref.invalidate(favoriteKeysProvider);
    ref.invalidate(favoritesControllerProvider);
  }

  /// Opens the collection picker modal to add a single [post] to a collection.
  static Future<void> addToCollection(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final result = await ref.read(collectionServiceProvider).getCollections();
    final collections =
        result is Success<List<Collection>> ? result.data : <Collection>[];
    if (!context.mounted) return;
    await showAddToCollectionPicker(
      context,
      collections: collections,
      onSelected: (collection) {
        ref
            .read(collectionServiceProvider)
            .addPostToCollection(collection.id, post);
      },
      onCreate: () => showCollectionFormDialog(context, ref),
    );
  }

  /// Opens the collection picker modal to add all [selectedPosts] to a collection.
  static Future<void> addSelectedToCollection(
    BuildContext context,
    WidgetRef ref,
    List<Post> selectedPosts, {
    VoidCallback? onDone,
  }) async {
    final result = await ref.read(collectionServiceProvider).getCollections();
    final collections =
        result is Success<List<Collection>> ? result.data : <Collection>[];
    if (!context.mounted) return;
    await showAddToCollectionPicker(
      context,
      collections: collections,
      onSelected: (collection) async {
        await ref
            .read(collectionServiceProvider)
            .addPostsToCollection(collection.id, selectedPosts);
        onDone?.call();
      },
      onCreate: () => showCollectionFormDialog(context, ref),
    );
  }

  /// Hides [post] locally and shows an undo SnackBar.
  static Future<void> hidePost(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    await ref.read(feedControllerProvider.notifier).hidePost(post);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Post hidden locally'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref
                .read(settingsServiceProvider)
                .unhidePostKey(post.cacheKey);
            ref.invalidate(appSettingsProvider);
            unawaited(ref.read(feedControllerProvider.notifier).refresh());
          },
        ),
      ),
    );
  }

  /// Automatically downloads [post] if user settings enable auto-download of favorites.
  static Future<void> maybeAutoDownloadFavorite(
    WidgetRef ref,
    Post post,
  ) async {
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    if (!settings.autoDownloadFavorites || !settings.allowDownloads) return;
    await ref.read(downloadManagerServiceProvider).start(post);
  }
}
