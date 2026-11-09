import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_navigator.dart';
import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/collections/presentation/collection_form_dialog.dart';
import 'package:gel_rule_app/features/favorites/presentation/favorites_controller.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/shared/widgets/post_card.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import '../post_details_screen.dart';
import 'post_action_bar.dart';
import 'video_surface.dart';

/// Coordinator for all user-initiated post actions (download, favorite, share,
/// collections, video persistence, comic opening, external navigation).
class PostDetailsActionHandler {
  const PostDetailsActionHandler._();

  /// Opens the collection picker modal and adds [post] to the chosen collection.
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

  /// Downloads [post] to standard app downloads storage.
  static Future<void> download(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    if (!context.mounted) return;
    await ref.read(downloadManagerServiceProvider).start(post);
    if (!context.mounted) return;
    final strings = ref.read(appStringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.ru ? 'Скачивание началось' : 'Download started'),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 2), () {
      ref.invalidate(downloadedMediaByKeyProvider(post.cacheKey));
    });
  }

  /// Downloads every page in [pages] sequentially.
  static Future<void> downloadAllPages(
    BuildContext context,
    WidgetRef ref,
    List<Post> pages,
  ) async {
    final downloadManager = ref.read(downloadManagerServiceProvider);
    for (final page in pages) {
      await downloadManager.start(page);
    }
    if (!context.mounted) return;
    final strings = ref.read(appStringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.ru
              ? 'Начато скачивание всех страниц (${pages.length})'
              : 'Started downloading all pages (${pages.length})',
        ),
      ),
    );
  }

  /// Prompts user with native file picker to choose a destination path,
  /// then downloads [post] directly to that location.
  static Future<void> saveAs(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    if (!context.mounted) return;
    final strings = ref.read(appStringsProvider);
    final url = MediaUrlSelector.download(post) ?? post.fileUrl;
    final parsed = Uri.tryParse(url);
    final segment =
        parsed?.pathSegments.isEmpty ?? true ? '' : parsed!.pathSegments.last;
    final extension = segment.contains('.')
        ? p.extension(segment).replaceAll('.', '')
        : (post.fileType.isNotEmpty ? post.fileType.toLowerCase() : 'jpg');
    final suggested = segment.isNotEmpty
        ? segment
        : '${post.providerId}_${post.id}.$extension';

    final location = await getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: [
        XTypeGroup(
          label: extension.toUpperCase(),
          extensions: [extension],
        ),
      ],
    );
    if (location == null || !context.mounted) return;

    await ref.read(downloadManagerServiceProvider).start(
          post,
          customSavePath: location.path,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.ru
              ? 'Сохранение в ${p.basename(location.path)} началось'
              : 'Saving to ${p.basename(location.path)} started',
        ),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 2), () {
      ref.invalidate(downloadedMediaByKeyProvider(post.cacheKey));
    });
  }

  /// Downloads media from a specific stream URL.
  static Future<void> downloadUrl(
    BuildContext context,
    WidgetRef ref,
    Post post,
    String targetUrl,
  ) async {
    final customPost = post.copyWith(fileUrl: targetUrl, sampleUrl: targetUrl);
    await download(context, ref, customPost);
  }

  /// Shares [post] file using the platform share sheet.
  static Future<void> sharePost(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final strings = ref.read(appStringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.ru
              ? 'Подготовка файла к отправке...'
              : 'Preparing file for sharing...',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    try {
      final path =
          await ref.read(downloadServiceProvider).prepareFileForShare(post);
      await Share.shareXFiles([XFile(path)], text: post.source ?? post.fileUrl);
    } catch (e) {
      if (!context.mounted) return;
      final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isRu ? "Ошибка отправки" : "Share error"}: $e',
          ),
        ),
      );
    }
  }

  /// Toggles favorite status for [post], syncing with e621 remote if authorized.
  static Future<void> toggleFavorite(
    WidgetRef ref,
    Post post,
    Set<String> favoriteKeys,
  ) async {
    final isFav = favoriteKeys.contains(post.cacheKey);
    if (isFav) {
      await ref
          .read(favoriteServiceProvider)
          .removeFavorite(post.id, post.providerId);
      final provider = await ref
          .read(providerManagerProvider)
          .getProviderInstance(post.providerId);
      if (provider is E621Provider && provider.isAuthorized) {
        unawaited(provider.removeFavorite(post.id));
      }
    } else {
      await ref.read(favoriteServiceProvider).addFavorite(post);
      await maybeAutoDownloadFavorite(ref, post);
      final provider = await ref
          .read(providerManagerProvider)
          .getProviderInstance(post.providerId);
      if (provider is E621Provider && provider.isAuthorized) {
        unawaited(provider.addFavorite(post.id));
      }
    }
    ref.invalidate(favoriteKeysProvider);
    ref.invalidate(favoritesControllerProvider);
  }

  /// Triggers automatic download of favorited post if user settings permit.
  static Future<void> maybeAutoDownloadFavorite(
    WidgetRef ref,
    Post post,
  ) async {
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    if (!settings.autoDownloadFavorites || !settings.allowDownloads) return;
    await ref.read(downloadManagerServiceProvider).start(post);
  }

  /// Deletes local downloaded copy of [post].
  static Future<void> deleteLocalFile(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final strings = ref.read(appStringsProvider);
    await ref.read(downloadedMediaServiceProvider).deleteLocalFile(
          post.cacheKey,
        );
    ref.invalidate(downloadedMediaByKeyProvider(post.cacheKey));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.deleteLocalFile)),
    );
  }

  /// Hides [post] locally and notifies caller via [onHidden].
  static Future<void> hidePost(
    BuildContext context,
    WidgetRef ref,
    Post post, {
    VoidCallback? onHidden,
  }) async {
    await ref.read(settingsServiceProvider).hidePostKey(post.cacheKey);
    ref.invalidate(appSettingsProvider);
    unawaited(ref.read(feedControllerProvider.notifier).refresh());
    if (!context.mounted) return;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isRu ? 'Пост скрыт локально' : 'Post hidden locally'),
      ),
    );
    onHidden?.call();
  }

  /// Navigates to similar posts screen for [post].
  static void openSimilar(BuildContext context, Post post) {
    AppNavigator.openSimilarPosts(context, post: post);
  }

  /// Opens the original source webpage of [post] in browser.
  static Future<void> openSourcePage(WidgetRef ref, Post post) async {
    final source = post.source?.trim();
    String? url = source != null && source.isNotEmpty ? source : null;
    if (url == null) {
      final result =
          await ref.read(providerManagerProvider).getPostPageUrl(post);
      if (result is Success<String?>) url = result.data;
    }
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url));
  }

  /// Loads e621 pool posts and navigates to the comic viewer.
  static Future<void> openComic(
    BuildContext context,
    E621Provider provider,
    String poolId,
    Post currentPost, [
    String? targetId,
  ]) async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(isRu ? 'Загрузка комикса...' : 'Loading comic...'),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    List<Post> poolPosts = const [];
    try {
      poolPosts = await provider.getPoolPosts(poolId);
    } catch (_) {
      poolPosts = const [];
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (poolPosts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRu
              ? 'Не удалось загрузить страницы комикса'
              : 'Could not load comic pages'),
        ),
      );
      return;
    }

    final idToFind = targetId ?? currentPost.id;
    final targetIndex = poolPosts.indexWhere((p) => p.id == idToFind);
    final startPost =
        targetIndex >= 0 ? poolPosts[targetIndex] : poolPosts.first;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => PostDetailsScreen(
          providerId: provider.id,
          postId: startPost.id,
          initialPost: startPost,
          postsList: poolPosts,
        ),
      ),
    );
  }

  /// Navigates to a post by its ID within the same provider.
  static void openPostById(
    BuildContext context,
    String providerId,
    String targetId,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => PostDetailsScreen(
          providerId: providerId,
          postId: targetId,
          fromFeed: false,
        ),
      ),
    );
  }

  /// Navigates to an artist post from the related artist posts carousel.
  static void openArtistPost(
    BuildContext context,
    Post artistPost,
    List<Post> filtered,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailsScreen(
          providerId: artistPost.providerId,
          postId: artistPost.id,
          initialPost: artistPost,
          postsList: filtered,
        ),
      ),
    );
  }

  /// Launches an external video/audio stream URL.
  static Future<void> playStream(String streamUrl) => launchUrl(
        Uri.parse(streamUrl),
        mode: LaunchMode.externalApplication,
      );

  /// Saves playback preferences (muted, volume, loop, etc.) to app settings.
  static Future<void> saveVideoPreferences(
    WidgetRef ref,
    VideoPlaybackSnapshot snapshot,
  ) async {
    final result = await ref.read(settingsServiceProvider).getSettings();
    if (result is! Success<AppSettings>) return;
    final settings = result.data;
    if (settings.videoPlayerMuted == snapshot.muted &&
        settings.videoPlayerHalfVolume == snapshot.halfVolume &&
        settings.videoPlayerLoop == snapshot.loopVideo &&
        settings.videoPlayerCover == snapshot.coverVideo &&
        (settings.videoPlayerVolume - snapshot.volume).abs() < 0.01) {
      return;
    }
    await ref.read(settingsServiceProvider).updateSettings(
          settings.copyWith(
            videoPlayerMuted: snapshot.muted,
            videoPlayerHalfVolume: snapshot.halfVolume,
            videoPlayerLoop: snapshot.loopVideo,
            videoPlayerCover: snapshot.coverVideo,
            videoPlayerVolume: snapshot.volume,
          ),
        );
    ref.invalidate(appSettingsProvider);
  }

  /// Persists current video playback timestamp for resuming later.
  static Future<void> saveVideoSnapshot(
    WidgetRef ref,
    Post post,
    VideoPlaybackSnapshot snapshot,
  ) async {
    await ref.read(settingsServiceProvider).saveVideoPlaybackPosition(
          post.cacheKey,
          snapshot.position.inMilliseconds,
        );
    ref.invalidate(appSettingsProvider);
  }

  /// Builds bilingual [PostActionLabels] based on current [AppStrings].
  static PostActionLabels buildActionLabels(AppStrings strings) {
    return PostActionLabels(
      favorite: strings.favorite,
      unfavorite: strings.removeFavorite,
      collection: strings.collection,
      similar: strings.similar,
      openOriginal: strings.open,
      saveAs: strings.ru ? 'Сохранить как...' : 'Save as...',
      copyLink: strings.ru ? 'Копировать ссылку' : 'Copy link',
      download: strings.download,
      deleteLocalFile: strings.deleteLocalFile,
      hidePost: strings.hidePost,
      share: strings.ru ? 'Поделиться' : 'Share',
    );
  }
}
