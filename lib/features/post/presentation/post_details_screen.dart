import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/app/app_navigator.dart';
import 'package:prisma_app/app/app_strings.dart';
import 'package:prisma_app/app/responsive.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/sources/mappers/pixiv_mapper.dart';
import 'package:prisma_app/shared/widgets/adaptive_scaffold.dart';
import 'package:prisma_app/shared/widgets/empty_view.dart';
import 'package:prisma_app/shared/widgets/error_view.dart';
import 'package:prisma_app/shared/widgets/post_card.dart';
import 'package:prisma_app/features/collections/presentation/collection_form_dialog.dart';
import 'package:prisma_app/features/favorites/presentation/favorites_controller.dart';
import 'package:prisma_app/features/feed/presentation/feed_controller.dart';
import 'package:prisma_app/features/settings/presentation/settings_controller.dart';
import 'package:prisma_app/features/viewed/presentation/viewed_controller.dart';
import 'package:prisma_app/sources/booru/e621_provider.dart';
import 'post_details_controller.dart';
import 'post_details_providers.dart';
import 'widgets/post_action_bar.dart';
import 'widgets/post_details_desktop_layout.dart';
import 'widgets/post_details_mobile_layout.dart';
import 'widgets/post_media_viewer.dart';

export 'post_details_providers.dart';
export 'widgets/post_artist_posts_card.dart';
export 'widgets/post_details_intents.dart';
export 'widgets/post_media_carousel.dart';
export 'widgets/post_translate_button.dart';

class PostDetailsScreen extends ConsumerStatefulWidget {
  const PostDetailsScreen({
    required this.providerId,
    required this.postId,
    this.initialPost,
    this.postsList,
    this.fromFeed = false,
    super.key,
  });

  final String providerId;
  final String postId;
  final Post? initialPost;
  final List<Post>? postsList;
  final bool fromFeed;

  @override
  ConsumerState<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends ConsumerState<PostDetailsScreen> {
  late String _activeProviderId;
  late String _activePostId;
  Post? _activePost;
  int _selectedPageIndex = 0;
  bool _mediaGestureLocked = false;

  void _setMediaGestureLocked(bool locked) {
    if (_mediaGestureLocked == locked) return;
    setState(() => _mediaGestureLocked = locked);
  }

  @override
  void initState() {
    super.initState();
    _activeProviderId = widget.providerId;
    _activePostId = widget.postId;
    _activePost = widget.initialPost;
    final initialId = widget.initialPost?.id ?? widget.postId;
    if (initialId.contains('_p')) {
      final parts = initialId.split('_p');
      _selectedPageIndex = int.tryParse(parts.last) ?? 0;
    } else {
      _selectedPageIndex = 0;
    }
  }

  @override
  void didUpdateWidget(covariant PostDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId ||
        oldWidget.postId != widget.postId) {
      _activeProviderId = widget.providerId;
      _activePostId = widget.postId;
      _activePost = widget.initialPost;
      final newId = widget.initialPost?.id ?? widget.postId;
      if (newId.contains('_p')) {
        final parts = newId.split('_p');
        _selectedPageIndex = int.tryParse(parts.last) ?? 0;
      } else {
        _selectedPageIndex = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = PostDetailsArgs(
      providerId: _activeProviderId,
      postId: _activePostId,
      initialPost: _activePost,
    );
    final postAsync = ref.watch(postDetailsControllerProvider(args));
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final strings = ref.watch(appStringsProvider);
    final List<Post> feedPosts;
    if (widget.fromFeed) {
      final liveFeedPosts = ref.watch(feedControllerProvider).value?.posts;
      feedPosts = (liveFeedPosts != null && liveFeedPosts.isNotEmpty)
          ? liveFeedPosts
          : (widget.postsList ??
              (widget.initialPost != null
                  ? [widget.initialPost!]
                  : const <Post>[]));
    } else {
      feedPosts = widget.postsList ??
          (widget.initialPost != null ? [widget.initialPost!] : const <Post>[]);
    }
    final favoriteKeys = ref.watch(favoriteKeysProvider).value ?? <String>{};
    final isFullscreen = ref.watch(isFullscreenViewerActiveProvider);
    return AdaptiveScaffold(
      title: strings.post,
      actions: [
        IconButton(
          tooltip: strings.fullscreen,
          onPressed: () => _openFullscreen(
            context,
            postAsync.valueOrNull ?? _activePost,
            feedPosts,
          ),
          icon: const Icon(Icons.fullscreen_rounded),
        ),
        IconButton(
          tooltip: strings.close,
          onPressed: () => _close(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
      body: Offstage(
        key: const ValueKey('post_details_offstage'),
        offstage: isFullscreen,
        child: Builder(
          builder: (context) {
            final effectivePost = postAsync.valueOrNull ?? _activePost;
            if (effectivePost == null) {
              if (postAsync.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (postAsync.hasError) {
                return ErrorView(message: postAsync.error.toString());
              }
              return const EmptyView(title: 'Post not found');
            }
            final post = effectivePost;
            final pagesAsync = ref.watch(postPagesProvider(PostPagesArgs(post)));
            final loadedPages = pagesAsync.value;
            final hasPages = loadedPages != null && loadedPages.length > 1;
            final pages = hasPages
                ? loadedPages
                : (post.providerId == 'pixiv' && post.pageCount > 1
                    ? PixivMapper.synthesizePages(post)
                    : (post.pageCount > 1
                        ? List.generate(
                            post.pageCount,
                            (i) => i == 0
                                ? post
                                : post.copyWith(
                                    id: '${post.id.split('_p').first}_p$i',
                                  ),
                          )
                        : [post]));
            final isMultiPage = pages.length > 1;
            final currentPostIndex =
                _selectedPageIndex.clamp(0, pages.length - 1);
            final targetPost = isMultiPage ? pages[currentPostIndex] : post;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(viewedHistoryServiceProvider).markViewed(post);
              ref.invalidate(viewedKeysProvider);
              ref.invalidate(viewedControllerProvider);
            });
            final basePostId = post.id.split('_p').first;
            final currentIndex = feedPosts.indexWhere(
              (item) =>
                  item.providerId == post.providerId &&
                  (item.id == post.id || item.id == basePostId),
            );
            final previous =
                currentIndex > 0 ? feedPosts[currentIndex - 1] : null;
            final next =
                currentIndex >= 0 && currentIndex < feedPosts.length - 1
                    ? feedPosts[currentIndex + 1]
                    : null;
            final qualityMode =
                MediaQualityMode.fromName(settings.mediaQualityMode);
            final localMedia = ref
                .watch(downloadedMediaByKeyProvider(targetPost.cacheKey))
                .value;
            final fileSizeBytes = localMedia != null
                ? DownloadedMediaService.getFileSizeSync(localMedia)
                : null;
            final isDownloading = ref.watch(
              downloadTasksProvider.select(
                (tasks) =>
                    tasks.value?.any(
                      (t) =>
                          (t.post?.cacheKey == targetPost.cacheKey ||
                              t.id == targetPost.cacheKey) &&
                          (t.status == DownloadTaskStatus.running ||
                              t.status == DownloadTaskStatus.queued),
                    ) ??
                    false,
              ),
            );
            final notesAsync = ref.watch(postNotesProvider(PostDetailsArgs(
                providerId: targetPost.providerId, postId: targetPost.id)));
            final notes = notesAsync.value ?? const [];
            final showNotes =
                ref.watch(showPostNotesProvider(targetPost.cacheKey));
            final isTextOnly = targetPost.fileType == 'text' ||
                (targetPost.previewUrl.isEmpty &&
                    targetPost.sampleUrl.isEmpty &&
                    targetPost.fileUrl.isEmpty &&
                    !MediaUrlSelector.isVideo(targetPost) &&
                    !MediaUrlSelector.isAudio(targetPost));
            final shouldShowCloudCard = isTextOnly
                ? targetPost.cloudLinks.isNotEmpty
                : (targetPost.cloudLinks.isNotEmpty ||
                    (targetPost.commentary != null &&
                        targetPost.commentary!.trim().isNotEmpty));

            final providerInstance =
                ref.watch(postProviderInstanceProvider(post.providerId)).value;
            final e621Provider =
                providerInstance is E621Provider ? providerInstance : null;

            final labels = _postActionLabels(strings);

            if (Responsive.isMobile(context)) {
              return PostDetailsMobileLayout(
                post: post,
                targetPost: targetPost,
                pages: pages,
                currentPageIndex: currentPostIndex,
                feedPosts: feedPosts,
                settings: settings,
                strings: strings,
                labels: labels,
                favoriteKeys: favoriteKeys,
                localMedia: localMedia,
                fileSizeBytes: fileSizeBytes,
                isDownloading: isDownloading,
                qualityMode: qualityMode,
                notes: notes,
                notesAsync: notesAsync,
                showNotes: showNotes,
                e621Provider: e621Provider,
                shouldShowCloudCard: shouldShowCloudCard,
                isTextOnly: isTextOnly,
                fromFeed: widget.fromFeed,
                mediaGestureLocked: _mediaGestureLocked,
                isActive: true,
                onClose: () => _close(context),
                onMediaGestureLockChanged: _setMediaGestureLocked,
                onPostIndexChanged: (newIndex) =>
                    _handlePagerPageChanged(newIndex, feedPosts),
                onToggleFavorite: (ref, p, keys) =>
                    _toggleFavorite(ref, p, keys),
                onShowQuickActions: (ctx, ref, p, keys) =>
                    _showMobileQuickActions(ctx, ref, p, keys),
                onSaveVideoSnapshot: (ref, p, snapshot) =>
                    _saveVideoSnapshot(ref, p, snapshot),
                onSaveVideoPreferences: (ref, snapshot) =>
                    _saveVideoPreferences(ref, snapshot),
                onPageSelected: (idx) =>
                    setState(() => _selectedPageIndex = idx),
                onDownloadAllPages: () =>
                    _downloadAllPages(context, ref, pages),
                onAddToCollection: () => _addToCollection(context, ref, post),
                onOpenSource: () => _openSourcePage(ref, targetPost),
                onOpenSimilar: () => _openSimilar(context, ref, targetPost),
                onHidePost: () => _hidePost(context, ref, targetPost),
                onDownload: settings.allowDownloads
                    ? () => _download(context, ref, post)
                    : null,
                onSaveAs: settings.allowDownloads
                    ? () => _saveAs(context, ref, post)
                    : null,
                onDeleteLocalFile: () =>
                    _deleteLocalFile(context, ref, targetPost),
                onShare: () => _sharePost(context, ref, targetPost),
                onOpenArtistPost: (artistPost, filtered) =>
                    Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetailsScreen(
                      providerId: artistPost.providerId,
                      postId: artistPost.id,
                      initialPost: artistPost,
                      postsList: filtered,
                    ),
                  ),
                ),
                onOpenPostId: (targetId) =>
                    _openPostById(context, post.providerId, targetId),
                onOpenComic: (poolId, currentPost, [targetId]) => _openComic(
                    context, e621Provider!, poolId, currentPost, targetId),
                onPlayStream: (streamUrl) => launchUrl(
                  Uri.parse(streamUrl),
                  mode: LaunchMode.externalApplication,
                ),
                onDownloadStream: settings.allowDownloads
                    ? (streamUrl) =>
                        _downloadUrl(context, ref, post, streamUrl)
                    : null,
                onLoadMore: widget.fromFeed
                    ? () => ref
                        .read(feedControllerProvider.notifier)
                        .loadNextPage()
                    : null,
              );
            }

            return PostDetailsDesktopLayout(
              post: post,
              targetPost: targetPost,
              previous: previous,
              next: next,
              pages: pages,
              isMultiPage: isMultiPage,
              currentPostIndex: currentPostIndex,
              feedPosts: feedPosts,
              settings: settings,
              strings: strings,
              labels: labels,
              favoriteKeys: favoriteKeys,
              localMedia: localMedia,
              fileSizeBytes: fileSizeBytes,
              isDownloading: isDownloading,
              qualityMode: qualityMode,
              notes: notes,
              notesAsync: notesAsync,
              showNotes: showNotes,
              e621Provider: e621Provider,
              shouldShowCloudCard: shouldShowCloudCard,
              isTextOnly: isTextOnly,
              fromFeed: widget.fromFeed,
              onOpenPost: (p) => _openPost(context, p),
              onToggleFavorite: () => _toggleFavorite(ref, post, favoriteKeys),
              onAddToCollection: () => _addToCollection(context, ref, post),
              onClose: () => _close(context),
              onDownload: settings.allowDownloads
                  ? () => _download(context, ref, post)
                  : null,
              onSaveAs: settings.allowDownloads
                  ? () => _saveAs(context, ref, post)
                  : null,
              onDeleteLocalFile: () =>
                  _deleteLocalFile(context, ref, targetPost),
              onShare: () => _sharePost(context, ref, targetPost),
              onOpenSource: () => _openSourcePage(ref, targetPost),
              onOpenSimilar: () => _openSimilar(context, ref, targetPost),
              onHidePost: () => _hidePost(context, ref, targetPost),
              onPageSelected: (idx) =>
                  setState(() => _selectedPageIndex = idx),
              onDownloadAllPages: () =>
                  _downloadAllPages(context, ref, pages),
              onOpenArtistPost: (artistPost, filtered) =>
                  Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PostDetailsScreen(
                    providerId: artistPost.providerId,
                    postId: artistPost.id,
                    initialPost: artistPost,
                    postsList: filtered,
                  ),
                ),
              ),
              onOpenPostId: (targetId) =>
                  _openPostById(context, post.providerId, targetId),
              onOpenComic: (poolId, currentPost, [targetId]) => _openComic(
                  context, e621Provider!, poolId, currentPost, targetId),
              onPlayStream: (streamUrl) => launchUrl(
                Uri.parse(streamUrl),
                mode: LaunchMode.externalApplication,
              ),
              onDownloadStream: settings.allowDownloads
                  ? (streamUrl) =>
                      _downloadUrl(context, ref, post, streamUrl)
                  : null,
              onToggleNotes: () => ref
                  .read(showPostNotesProvider(targetPost.cacheKey).notifier)
                  .state = !showNotes,
              onVolumeChanged: (vol) => ref
                  .read(settingsControllerProvider.notifier)
                  .setVideoPlayerVolume(vol),
              onPlaybackSnapshot: (snapshot) =>
                  _saveVideoSnapshot(ref, targetPost, snapshot),
              onPlaybackPreferencesChanged: (snapshot) =>
                  _saveVideoPreferences(ref, snapshot),
              onLoadMore: widget.fromFeed
                  ? () => ref
                      .read(feedControllerProvider.notifier)
                      .loadNextPage()
                  : null,
            );
          },
        ),
      ),
    );
  }

  Future<void> _addToCollection(
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

  Future<void> _download(BuildContext context, WidgetRef ref, Post post) async {
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

  Future<void> _downloadAllPages(
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

  Future<void> _saveAs(BuildContext context, WidgetRef ref, Post post) async {
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

  Future<void> _downloadUrl(
    BuildContext context,
    WidgetRef ref,
    Post post,
    String targetUrl,
  ) async {
    final customPost = post.copyWith(fileUrl: targetUrl, sampleUrl: targetUrl);
    await _download(context, ref, customPost);
  }

  Future<void> _sharePost(
      BuildContext context, WidgetRef ref, Post post) async {
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

  Future<void> _showMobileQuickActions(
    BuildContext context,
    WidgetRef ref,
    Post post,
    Set<String> favoriteKeys,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                favoriteKeys.contains(post.cacheKey)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              title: Text(
                favoriteKeys.contains(post.cacheKey)
                    ? 'Remove favorite'
                    : 'Favorite',
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _toggleFavorite(ref, post, favoriteKeys);
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_rounded),
              title: const Text('Add to collection'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addToCollection(context, ref, post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy link'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: post.fileUrl));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(sheetContext);
                _download(context, ref, post);
              },
            ),
            Builder(
              builder: (ctx) {
                final pages =
                    ref.read(postPagesProvider(PostPagesArgs(post))).value ??
                        [post];
                if (pages.length <= 1) return const SizedBox.shrink();
                final isRu =
                    Localizations.maybeLocaleOf(ctx)?.languageCode == 'ru';
                return ListTile(
                  leading: const Icon(Icons.download_for_offline_rounded),
                  title: Text(
                    isRu
                        ? 'Скачать все страницы (${pages.length})'
                        : 'Download all pages (${pages.length})',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _downloadAllPages(context, ref, pages);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(
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
      await _maybeAutoDownloadFavorite(ref, post);
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

  Future<void> _openComic(
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

    final poolPosts = await provider.getPoolPosts(poolId);
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

  void _openPostById(BuildContext context, String providerId, String targetId) {
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

  Future<void> _maybeAutoDownloadFavorite(WidgetRef ref, Post post) async {
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    if (!settings.autoDownloadFavorites || !settings.allowDownloads) return;
    await ref.read(downloadManagerServiceProvider).start(post);
  }

  Future<void> _deleteLocalFile(
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

  PostActionLabels _postActionLabels(AppStrings strings) {
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

  Future<void> _hidePost(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    await ref.read(settingsServiceProvider).hidePostKey(post.cacheKey);
    ref.invalidate(appSettingsProvider);
    unawaited(ref.read(feedControllerProvider.notifier).refresh());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post hidden locally')),
    );
    _close(context);
  }

  void _openPost(BuildContext context, Post post) {
    if (_activePostId == post.id && _activeProviderId == post.providerId) {
      return;
    }
    setState(() {
      _activeProviderId = post.providerId;
      _activePostId = post.id;
      _activePost = post;
      _selectedPageIndex = post.id.contains('_p')
          ? (int.tryParse(post.id.split('_p').last) ?? 0)
          : 0;
    });
    ref.read(viewedHistoryServiceProvider).markViewed(post);
    ref.invalidate(viewedKeysProvider);
    ref.invalidate(viewedControllerProvider);
  }

  void _handlePagerPageChanged(int index, List<Post> feedPosts) {
    if (index >= 0 && index < feedPosts.length) {
      final newPost = feedPosts[index];
      if (_activePostId != newPost.id ||
          _activeProviderId != newPost.providerId) {
        setState(() {
          _activeProviderId = newPost.providerId;
          _activePostId = newPost.id;
          _activePost = newPost;
          _selectedPageIndex = 0;
        });
        ref.read(viewedHistoryServiceProvider).markViewed(newPost);
        ref.invalidate(viewedKeysProvider);
        ref.invalidate(viewedControllerProvider);
      }
    }
  }

  Future<void> _openFullscreen(
    BuildContext context,
    Post? post,
    List<Post> feedPosts,
  ) async {
    final rootPost = post ?? _activePost;
    if (rootPost == null) return;

    final pages =
        ref.read(postPagesProvider(PostPagesArgs(rootPost))).value ?? [rootPost];
    final isMulti = pages.length > 1;
    final currentIdx = _selectedPageIndex.clamp(0, pages.length - 1);
    final targetPost = isMulti ? pages[currentIdx] : rootPost;
    final targetList =
        isMulti ? pages : (feedPosts.isNotEmpty ? feedPosts : [rootPost]);

    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    final qualityMode = MediaQualityMode.fromName(settings.mediaQualityMode);
    final notes = ref
            .read(postNotesProvider(PostDetailsArgs(
              providerId: targetPost.providerId,
              postId: targetPost.id,
            )))
            .value ??
        const [];
    final showNotes = ref.read(showPostNotesProvider(targetPost.cacheKey));
    final localMedia =
        ref.read(downloadedMediaByKeyProvider(targetPost.cacheKey)).value;

    await openPostFullscreenGallery(
      context: context,
      ref: ref,
      post: targetPost,
      postsList: targetList,
      qualityMode: qualityMode,
      notes: notes,
      showNotes: showNotes,
      localFilePath: localMedia?.savedPath,
      useLiveFeed: isMulti ? false : widget.fromFeed,
      onPostChanged: (index) {
        if (isMulti) {
          if (index >= 0 && index < pages.length) {
            setState(() => _selectedPageIndex = index);
          }
        } else {
          if (index >= 0 && index < feedPosts.length) {
            final newPost = feedPosts[index];
            _openPost(context, newPost);
          }
        }
      },
      onLoadMore: (!isMulti && widget.fromFeed)
          ? () => ref.read(feedControllerProvider.notifier).loadNextPage()
          : null,
    );
  }

  void _openSimilar(BuildContext context, WidgetRef ref, Post post) {
    AppNavigator.openSimilarPosts(context, post: post);
  }

  Future<void> _openSourcePage(WidgetRef ref, Post post) async {
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

  void _close(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  Future<void> _saveVideoPreferences(
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

  Future<void> _saveVideoSnapshot(
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
}
