import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/favorites/presentation/favorites_controller.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/viewed/presentation/viewed_controller.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'package:gel_rule_app/sources/mappers/pixiv_mapper.dart';
import 'post_details_controller.dart';
import 'post_details_providers.dart';
import 'widgets/post_details_action_handler.dart';
import 'widgets/post_details_desktop_layout.dart';
import 'widgets/post_details_mobile_layout.dart';
import 'widgets/post_details_quick_actions_sheet.dart';
import 'widgets/post_media_viewer.dart';

export 'post_details_providers.dart';
export 'widgets/post_artist_posts_card.dart';
export 'widgets/post_details_action_handler.dart';
export 'widgets/post_details_intents.dart';
export 'widgets/post_details_quick_actions_sheet.dart';
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
            var currentIndex = feedPosts.indexWhere(
              (item) =>
                  item.providerId == post.providerId &&
                  (item.id == post.id || item.id == basePostId),
            );
            if (currentIndex < 0) {
              currentIndex = feedPosts.indexWhere(
                (item) => item.id == post.id || item.id == basePostId,
              );
            }
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

            final labels = PostDetailsActionHandler.buildActionLabels(strings);

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
                    PostDetailsActionHandler.toggleFavorite(ref, p, keys),
                onShowQuickActions: (ctx, ref, p, keys) =>
                    PostDetailsQuickActionsSheet.show(
                  context: ctx,
                  ref: ref,
                  post: p,
                  favoriteKeys: keys,
                ),
                onSaveVideoSnapshot: (ref, p, snapshot) =>
                    PostDetailsActionHandler.saveVideoSnapshot(
                        ref, p, snapshot),
                onSaveVideoPreferences: (ref, snapshot) =>
                    PostDetailsActionHandler.saveVideoPreferences(
                        ref, snapshot),
                onPageSelected: (idx) =>
                    setState(() => _selectedPageIndex = idx),
                onDownloadAllPages: () =>
                    PostDetailsActionHandler.downloadAllPages(
                        context, ref, pages),
                onAddToCollection: () =>
                    PostDetailsActionHandler.addToCollection(
                        context, ref, post),
                onOpenSource: () =>
                    PostDetailsActionHandler.openSourcePage(ref, targetPost),
                onOpenSimilar: () =>
                    PostDetailsActionHandler.openSimilar(context, targetPost),
                onHidePost: () => PostDetailsActionHandler.hidePost(
                  context,
                  ref,
                  targetPost,
                  onHidden: () => _close(context),
                ),
                onDownload: settings.allowDownloads
                    ? () => PostDetailsActionHandler.download(
                        context, ref, post)
                    : null,
                onSaveAs: settings.allowDownloads
                    ? () => PostDetailsActionHandler.saveAs(
                        context, ref, post)
                    : null,
                onDeleteLocalFile: () =>
                    PostDetailsActionHandler.deleteLocalFile(
                        context, ref, targetPost),
                onShare: () => PostDetailsActionHandler.sharePost(
                    context, ref, targetPost),
                onOpenArtistPost: (artistPost, filtered) =>
                    PostDetailsActionHandler.openArtistPost(
                        context, artistPost, filtered),
                onOpenPostId: (targetId) =>
                    PostDetailsActionHandler.openPostById(
                        context, post.providerId, targetId),
                onOpenComic: (poolId, currentPost, [targetId]) =>
                    PostDetailsActionHandler.openComic(
                        context, e621Provider!, poolId, currentPost, targetId),
                onPlayStream: (streamUrl) =>
                    PostDetailsActionHandler.playStream(streamUrl),
                onDownloadStream: settings.allowDownloads
                    ? (streamUrl) => PostDetailsActionHandler.downloadUrl(
                        context, ref, post, streamUrl)
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
              onToggleFavorite: () =>
                  PostDetailsActionHandler.toggleFavorite(
                      ref, post, favoriteKeys),
              onAddToCollection: () =>
                  PostDetailsActionHandler.addToCollection(
                      context, ref, post),
              onClose: () => _close(context),
              onDownload: settings.allowDownloads
                  ? () => PostDetailsActionHandler.download(
                      context, ref, post)
                  : null,
              onSaveAs: settings.allowDownloads
                  ? () => PostDetailsActionHandler.saveAs(
                      context, ref, post)
                  : null,
              onDeleteLocalFile: () =>
                  PostDetailsActionHandler.deleteLocalFile(
                      context, ref, targetPost),
              onShare: () => PostDetailsActionHandler.sharePost(
                  context, ref, targetPost),
              onOpenSource: () =>
                  PostDetailsActionHandler.openSourcePage(ref, targetPost),
              onOpenSimilar: () =>
                  PostDetailsActionHandler.openSimilar(context, targetPost),
              onHidePost: () => PostDetailsActionHandler.hidePost(
                context,
                ref,
                targetPost,
                onHidden: () => _close(context),
              ),
              onPageSelected: (idx) =>
                  setState(() => _selectedPageIndex = idx),
              onDownloadAllPages: () =>
                  PostDetailsActionHandler.downloadAllPages(
                      context, ref, pages),
              onOpenArtistPost: (artistPost, filtered) =>
                  PostDetailsActionHandler.openArtistPost(
                      context, artistPost, filtered),
              onOpenPostId: (targetId) =>
                  PostDetailsActionHandler.openPostById(
                      context, post.providerId, targetId),
              onOpenComic: (poolId, currentPost, [targetId]) =>
                  PostDetailsActionHandler.openComic(
                      context, e621Provider!, poolId, currentPost, targetId),
              onPlayStream: (streamUrl) =>
                  PostDetailsActionHandler.playStream(streamUrl),
              onDownloadStream: settings.allowDownloads
                  ? (streamUrl) => PostDetailsActionHandler.downloadUrl(
                      context, ref, post, streamUrl)
                  : null,
              onToggleNotes: () => ref
                  .read(showPostNotesProvider(targetPost.cacheKey).notifier)
                  .state = !showNotes,
              onVolumeChanged: (vol) => ref
                  .read(settingsControllerProvider.notifier)
                  .setVideoPlayerVolume(vol),
              onPlaybackSnapshot: (snapshot) =>
                  PostDetailsActionHandler.saveVideoSnapshot(
                      ref, targetPost, snapshot),
              onPlaybackPreferencesChanged: (snapshot) =>
                  PostDetailsActionHandler.saveVideoPreferences(
                      ref, snapshot),
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

  void _close(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }
}
