import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_navigator.dart';
import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/empty_view.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'package:gel_rule_app/shared/widgets/keyboard_shortcut_utils.dart';
import 'package:gel_rule_app/shared/widgets/post_card.dart';
import 'package:gel_rule_app/features/collections/presentation/collection_form_dialog.dart';
import 'package:gel_rule_app/features/favorites/presentation/favorites_controller.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/viewed/presentation/viewed_controller.dart';
import 'post_details_controller.dart';
import 'widgets/cloud_mirrors_card.dart';
import 'widgets/post_action_bar.dart';
import 'widgets/post_media_viewer.dart';
import 'widgets/post_pools_card.dart';
import 'widgets/post_relations_card.dart';
import 'widgets/post_tags_panel.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'widgets/comments_section.dart';
import 'widgets/post_info_card.dart';

import 'post_details_providers.dart';
import 'widgets/post_artist_posts_card.dart';
import 'widgets/post_details_intents.dart';
import 'widgets/post_media_carousel.dart';
import 'widgets/post_translate_button.dart';

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
  }

  @override
  void didUpdateWidget(covariant PostDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId ||
        oldWidget.postId != widget.postId) {
      _activeProviderId = widget.providerId;
      _activePostId = widget.postId;
      _activePost = widget.initialPost;
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(viewedHistoryServiceProvider).markViewed(post);
              ref.invalidate(viewedKeysProvider);
              ref.invalidate(viewedControllerProvider);
            });
            final currentIndex = feedPosts.indexWhere(
              (item) =>
                  item.providerId == post.providerId && item.id == post.id,
            );
            final previous =
                currentIndex > 0 ? feedPosts[currentIndex - 1] : null;
            final next =
                currentIndex >= 0 && currentIndex < feedPosts.length - 1
                    ? feedPosts[currentIndex + 1]
                    : null;
            final qualityMode =
                MediaQualityMode.fromName(settings.mediaQualityMode);
            final localMedia =
                ref.watch(downloadedMediaByKeyProvider(post.cacheKey)).value;
            final fileSizeBytes = localMedia != null
                ? DownloadedMediaService.getFileSizeSync(localMedia)
                : null;
            final isDownloading = ref.watch(
              downloadTasksProvider.select(
                (tasks) =>
                    tasks.value?.any(
                      (t) =>
                          (t.post?.cacheKey == post.cacheKey ||
                              t.id == post.cacheKey) &&
                          (t.status == DownloadTaskStatus.running ||
                              t.status == DownloadTaskStatus.queued),
                    ) ??
                    false,
              ),
            );
            final notesAsync = ref.watch(postNotesProvider(
                PostDetailsArgs(providerId: post.providerId, postId: post.id)));
            final notes = notesAsync.value ?? const [];
            final showNotes = ref.watch(showPostNotesProvider(post.cacheKey));
            final isTextOnly = post.fileType == 'text' ||
                (post.previewUrl.isEmpty &&
                    post.sampleUrl.isEmpty &&
                    post.fileUrl.isEmpty &&
                    !MediaUrlSelector.isVideo(post) &&
                    !MediaUrlSelector.isAudio(post));
            final shouldShowCloudCard = isTextOnly
                ? post.cloudLinks.isNotEmpty
                : (post.cloudLinks.isNotEmpty ||
                    (post.commentary != null &&
                        post.commentary!.trim().isNotEmpty));

            final providerInstance =
                ref.watch(postProviderInstanceProvider(post.providerId)).value;
            final e621Provider =
                providerInstance is E621Provider ? providerInstance : null;

            if (Responsive.isMobile(context)) {
              return _buildMobileDetails(
                context,
                ref,
                post,
                settings,
                favoriteKeys,
                qualityMode,
                strings,
                _mediaGestureLocked,
                _setMediaGestureLocked,
                feedPosts,
                (newIndex) => _handlePagerPageChanged(newIndex, feedPosts),
                true,
              );
            }
            return Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                    const PreviousPostIntent(),
                LogicalKeySet(LogicalKeyboardKey.keyA):
                    const PreviousPostIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowRight):
                    const NextPostIntent(),
                LogicalKeySet(LogicalKeyboardKey.keyD): const NextPostIntent(),
                LogicalKeySet(LogicalKeyboardKey.keyF):
                    const ToggleFavoriteIntent(),
                LogicalKeySet(LogicalKeyboardKey.keyC):
                    const AddCollectionIntent(),
                LogicalKeySet(LogicalKeyboardKey.keyS): const DownloadIntent(),
                LogicalKeySet(
                        LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
                    const DownloadIntent(),
                LogicalKeySet(LogicalKeyboardKey.escape): const CloseIntent(),
              },
              child: Actions(
                actions: {
                  PreviousPostIntent: NonTextInputAction<PreviousPostIntent>(
                    onInvoke: (_) {
                      if (previous != null) _openPost(context, previous);
                      return null;
                    },
                  ),
                  NextPostIntent: NonTextInputAction<NextPostIntent>(
                    onInvoke: (_) {
                      if (next != null) _openPost(context, next);
                      return null;
                    },
                  ),
                  ToggleFavoriteIntent:
                      NonTextInputAction<ToggleFavoriteIntent>(
                    onInvoke: (_) {
                      _toggleFavorite(ref, post, favoriteKeys);
                      return null;
                    },
                  ),
                  AddCollectionIntent: NonTextInputAction<AddCollectionIntent>(
                    onInvoke: (_) {
                      _addToCollection(context, ref, post);
                      return null;
                    },
                  ),
                  CloseIntent: NonTextInputAction<CloseIntent>(
                    onInvoke: (_) {
                      _close(context);
                      return null;
                    },
                  ),
                  DownloadIntent: NonTextInputAction<DownloadIntent>(
                    onInvoke: (_) {
                      if (settings.allowDownloads) {
                        _download(context, ref, post);
                      }
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            tooltip: strings.ru ? 'Предыдущий' : 'Previous',
                            onPressed: previous == null
                                ? null
                                : () => _openPost(context, previous),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Center(
                              child: (MediaUrlSelector.isVideo(post) ||
                                      MediaUrlSelector.isAudio(post))
                                  ? ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaUrlSelector.isAudio(post)
                                                ? 360
                                                : 760,
                                        maxWidth: MediaUrlSelector.isAudio(post)
                                            ? 620
                                            : double.infinity,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio:
                                            MediaUrlSelector.isAudio(post)
                                                ? 1.4
                                                : ((post.width > 0 &&
                                                        post.height > 0)
                                                    ? (post.width / post.height)
                                                        .clamp(0.45, 2.4)
                                                    : (16 / 9)),
                                        child: PostMediaViewer(
                                          key: ValueKey(post.cacheKey),
                                          post: post,
                                          useLiveFeed: widget.fromFeed,
                                          postsList: feedPosts,
                                          onLoadMore: widget.fromFeed
                                              ? () => ref
                                                  .read(feedControllerProvider
                                                      .notifier)
                                                  .loadNextPage()
                                              : null,
                                          onPostIndexChanged: (index) {
                                            final currentPosts = widget.fromFeed
                                                ? (ref
                                                        .read(
                                                            feedControllerProvider)
                                                        .value
                                                        ?.posts ??
                                                    feedPosts)
                                                : feedPosts;
                                            if (index >= 0 &&
                                                index < currentPosts.length) {
                                              final target =
                                                  currentPosts[index];
                                              if (target.cacheKey !=
                                                  post.cacheKey) {
                                                _openPost(context, target);
                                              }
                                            }
                                          },
                                          localFilePath: localMedia?.savedPath,
                                          qualityMode: qualityMode,
                                          notes: notes,
                                          showNotes: showNotes,
                                          mediaHeaders: ref
                                                  .watch(
                                                      postMediaHeadersProvider(
                                                          post))
                                                  .value ??
                                              const {},
                                          initialPosition: Duration(
                                            milliseconds:
                                                settings.videoPlaybackPositions[
                                                        post.cacheKey] ??
                                                    0,
                                          ),
                                          initialLoop: settings.videoPlayerLoop,
                                          initialMuted:
                                              settings.videoPlayerMuted,
                                          initialCoverVideo:
                                              settings.videoPlayerCover,
                                          initialHalfVolume:
                                              settings.videoPlayerHalfVolume,
                                          initialVolume:
                                              settings.videoPlayerVolume,
                                          onVolumeChanged: (vol) => ref
                                              .read(settingsControllerProvider
                                                  .notifier)
                                              .setVideoPlayerVolume(vol),
                                          onPlaybackSnapshot: (snapshot) =>
                                              _saveVideoSnapshot(
                                                  ref, post, snapshot),
                                          onPlaybackPreferencesChanged:
                                              (snapshot) =>
                                                  _saveVideoPreferences(
                                                      ref, snapshot),
                                        ),
                                      ),
                                    )
                                  : ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 760,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: (post.width > 0 &&
                                                post.height > 0)
                                            ? (post.width / post.height)
                                                .clamp(0.2, 5.0)
                                            : (ref.watch(postMediaDimensionsProvider(
                                                            post.cacheKey)) !=
                                                        null &&
                                                    ref
                                                            .watch(postMediaDimensionsProvider(
                                                                post.cacheKey))!
                                                            .height >
                                                        0
                                                ? (ref.watch(postMediaDimensionsProvider(post.cacheKey))!.width /
                                                        ref
                                                            .watch(postMediaDimensionsProvider(post.cacheKey))!
                                                            .height)
                                                    .clamp(0.2, 5.0)
                                                : (16 / 9)),
                                        child: PostMediaViewer(
                                          key: ValueKey(post.cacheKey),
                                          post: post,
                                          useLiveFeed: widget.fromFeed,
                                          postsList: feedPosts,
                                          onLoadMore: widget.fromFeed
                                              ? () => ref
                                                  .read(feedControllerProvider
                                                      .notifier)
                                                  .loadNextPage()
                                              : null,
                                          onPostIndexChanged: (index) {
                                            final currentPosts = widget.fromFeed
                                                ? (ref
                                                        .read(
                                                            feedControllerProvider)
                                                        .value
                                                        ?.posts ??
                                                    feedPosts)
                                                : feedPosts;
                                            if (index >= 0 &&
                                                index < currentPosts.length) {
                                              final target =
                                                  currentPosts[index];
                                              if (target.cacheKey !=
                                                  post.cacheKey) {
                                                _openPost(context, target);
                                              }
                                            }
                                          },
                                          localFilePath: localMedia?.savedPath,
                                          qualityMode: qualityMode,
                                          notes: notes,
                                          showNotes: showNotes,
                                          mediaHeaders: ref
                                                  .watch(
                                                      postMediaHeadersProvider(
                                                          post))
                                                  .value ??
                                              const {},
                                          initialPosition: Duration(
                                            milliseconds:
                                                settings.videoPlaybackPositions[
                                                        post.cacheKey] ??
                                                    0,
                                          ),
                                          initialLoop: settings.videoPlayerLoop,
                                          initialMuted:
                                              settings.videoPlayerMuted,
                                          initialCoverVideo:
                                              settings.videoPlayerCover,
                                          initialHalfVolume:
                                              settings.videoPlayerHalfVolume,
                                          initialVolume:
                                              settings.videoPlayerVolume,
                                          onVolumeChanged: (vol) => ref
                                              .read(settingsControllerProvider
                                                  .notifier)
                                              .setVideoPlayerVolume(vol),
                                          onPlaybackSnapshot: (snapshot) =>
                                              _saveVideoSnapshot(
                                                  ref, post, snapshot),
                                          onPlaybackPreferencesChanged:
                                              (snapshot) =>
                                                  _saveVideoPreferences(
                                                      ref, snapshot),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: strings.ru ? 'Следующий' : 'Next',
                            onPressed: next == null
                                ? null
                                : () => _openPost(context, next),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      if (!MediaUrlSelector.isVideo(post) &&
                          !MediaUrlSelector.isAudio(post) &&
                          (post.providerId.toLowerCase().contains('e621') ||
                              post.providerId.toLowerCase().contains('e926') ||
                              post.hasNotes)) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: GoogleTranslateButton(
                            hasNotes: notes.isNotEmpty,
                            isLoading: notesAsync.isLoading,
                            showNotes: showNotes,
                            notesCount: notes.length,
                            isRu: strings.ru,
                            onToggle: () {
                              ref
                                  .read(showPostNotesProvider(post.cacheKey)
                                      .notifier)
                                  .state = !showNotes;
                            },
                          ),
                        ),
                      ],
                      if (currentIndex >= 0) ...[
                        const SizedBox(height: 10),
                        NeighborStrip(
                          posts: feedPosts,
                          currentIndex: currentIndex,
                          onOpen: (post) => _openPost(context, post),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PostActionBar(
                        isFavorite: favoriteKeys.contains(post.cacheKey),
                        labels: _postActionLabels(strings),
                        downloaded: localMedia != null,
                        isDownloading: isDownloading,
                        onFavorite: () =>
                            _toggleFavorite(ref, post, favoriteKeys),
                        onCollection: () =>
                            _addToCollection(context, ref, post),
                        onOpen: () => launchUrl(Uri.parse(post.fileUrl)),
                        onOpenSource: () => _openSourcePage(ref, post),
                        onCopy: () => Clipboard.setData(
                            ClipboardData(text: post.fileUrl)),
                        onSimilar: () => _openSimilar(context, ref, post),
                        onHide: () => _hidePost(context, ref, post),
                        onDownload: settings.allowDownloads
                            ? () => _download(context, ref, post)
                            : null,
                        onSaveAs: settings.allowDownloads
                            ? () => _saveAs(context, ref, post)
                            : null,
                        onDeleteLocalFile: () =>
                            _deleteLocalFile(context, ref, post),
                        onShare: () => _sharePost(context, ref, post),
                      ),
                      const SizedBox(height: 16),
                      PostInfoCard(
                        post: post,
                        strings: strings,
                        localMedia: localMedia,
                        fileSizeBytes: fileSizeBytes,
                        e621Provider: e621Provider,
                      ),
                      ArtistPostsCard(
                        post: post,
                        onOpenPost: (p, filtered) => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PostDetailsScreen(
                              providerId: p.providerId,
                              postId: p.id,
                              initialPost: p,
                              postsList: filtered,
                            ),
                          ),
                        ),
                      ),
                      if (post.hasRelations) ...[
                        const SizedBox(height: 16),
                        PostRelationsCard(
                          post: post,
                          onOpenPostId: (targetId) =>
                              _openPostById(context, post.providerId, targetId),
                        ),
                      ],
                      if (post.hasPools && e621Provider != null) ...[
                        const SizedBox(height: 16),
                        PostPoolsCard(
                          post: post,
                          provider: e621Provider,
                          onOpenComic: (poolId, currentPost, [targetId]) =>
                              _openComic(context, e621Provider, poolId,
                                  currentPost, targetId),
                          onOpenPostId: (targetId) =>
                              _openPostById(context, post.providerId, targetId),
                        ),
                      ],
                      if (shouldShowCloudCard) ...[
                        const SizedBox(height: 16),
                        CloudMirrorsCard(
                          links: post.cloudLinks,
                          strings: strings,
                          commentary: isTextOnly ? null : post.commentary,
                          onPlayStream: (streamUrl) => launchUrl(
                            Uri.parse(streamUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          onDownloadStream: settings.allowDownloads
                              ? (streamUrl) =>
                                  _downloadUrl(context, ref, post, streamUrl)
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh
                                  .withValues(alpha: 0.70)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.40),
                            width: 1.1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${strings.tags} (${post.cleanTags.length})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            PostTagsPanel(post: post),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CommentsSection(post: post),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileDetails(
    BuildContext context,
    WidgetRef ref,
    Post post,
    AppSettings settings,
    Set<String> favoriteKeys,
    MediaQualityMode qualityMode,
    AppStrings strings,
    bool mediaGestureLocked,
    ValueChanged<bool>? onMediaGestureLockChanged, [
    List<Post>? feedPosts,
    ValueChanged<int>? onPostIndexChanged,
    bool isActive = true,
  ]) {
    final isVideo = MediaUrlSelector.isVideo(post);
    final isAudio = MediaUrlSelector.isAudio(post);
    final localMedia =
        ref.watch(downloadedMediaByKeyProvider(post.cacheKey)).value;
    final fileSizeBytes = localMedia != null
        ? DownloadedMediaService.getFileSizeSync(localMedia)
        : null;
    final isDownloading = ref.watch(
      downloadTasksProvider.select(
        (tasks) =>
            tasks.value?.any(
              (t) =>
                  (t.post?.cacheKey == post.cacheKey ||
                      t.id == post.cacheKey) &&
                  (t.status == DownloadTaskStatus.running ||
                      t.status == DownloadTaskStatus.queued),
            ) ??
            false,
      ),
    );
    final notesAsync = ref.watch(postNotesProvider(
        PostDetailsArgs(providerId: post.providerId, postId: post.id)));
    final notes = notesAsync.value ?? const [];
    final showNotes = ref.watch(showPostNotesProvider(post.cacheKey));
    final isTextOnly = post.fileType == 'text' ||
        (post.previewUrl.isEmpty &&
            post.sampleUrl.isEmpty &&
            post.fileUrl.isEmpty &&
            !MediaUrlSelector.isVideo(post) &&
            !MediaUrlSelector.isAudio(post));
    final shouldShowCloudCard = isTextOnly
        ? post.cloudLinks.isNotEmpty
        : (post.cloudLinks.isNotEmpty ||
            (post.commentary != null && post.commentary!.trim().isNotEmpty));

    final providerInstance =
        ref.watch(postProviderInstanceProvider(post.providerId)).value;
    final e621Provider =
        providerInstance is E621Provider ? providerInstance : null;
    final posts = feedPosts;
    final hasMultiplePosts = posts != null && posts.length > 1;
    final currentIndex = (posts != null && hasMultiplePosts)
        ? posts.indexWhere(
            (item) => item.providerId == post.providerId && item.id == post.id,
          )
        : 0;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableWidth = (screenWidth - 16).clamp(100.0, double.infinity);
    final singleDynamicDim =
        ref.watch(postMediaDimensionsProvider(post.cacheKey));
    final singleMediaHeight = calculateMediaHeight(
      post: post,
      availableWidth: availableWidth,
      screenHeight: screenHeight,
      dynamicDimensions: singleDynamicDim,
    );
    final singleMediaAspect = post.width > 0 && post.height > 0
        ? post.width / post.height
        : (singleDynamicDim != null && singleDynamicDim.height > 0
            ? singleDynamicDim.width / singleDynamicDim.height
            : 16 / 9);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        if (mediaGestureLocked) return;
        if ((details.primaryVelocity ?? 0) > 900) _close(context);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          8,
          8,
          8,
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (posts != null && posts.length > 1)
            MobileMediaCarousel(
              key: const ValueKey('mobile_media_carousel'),
              posts: posts,
              initialIndex: currentIndex >= 0 ? currentIndex : 0,
              activePost: post,
              settings: settings,
              favoriteKeys: favoriteKeys,
              qualityMode: qualityMode,
              onPageChanged: (newIndex) => onPostIndexChanged?.call(newIndex),
              useLiveFeed: widget.fromFeed,
              onLoadMore: widget.fromFeed
                  ? () =>
                      ref.read(feedControllerProvider.notifier).loadNextPage()
                  : null,
              onMediaGestureLockChanged: onMediaGestureLockChanged,
              onToggleFavorite: (r, p) => _toggleFavorite(r, p, favoriteKeys),
              onShowQuickActions: (ctx, r, p) =>
                  _showMobileQuickActions(ctx, r, p, favoriteKeys),
              onSaveVideoSnapshot: (r, p, s) => _saveVideoSnapshot(r, p, s),
              onSaveVideoPreferences: (r, s) => _saveVideoPreferences(r, s),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onDoubleTap: isVideo
                  ? null
                  : () => _toggleFavorite(ref, post, favoriteKeys),
              onLongPress: isVideo
                  ? null
                  : () =>
                      _showMobileQuickActions(context, ref, post, favoriteKeys),
              child: (isVideo || isAudio)
                  ? Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: isAudio ? 340 : singleMediaHeight,
                        ),
                        child: AspectRatio(
                          aspectRatio:
                              isAudio ? 1.3 : singleMediaAspect.clamp(0.2, 5.0),
                          child: PostMediaViewer(
                            key: ValueKey(post.cacheKey),
                            post: post,
                            useLiveFeed: widget.fromFeed,
                            isActive: isActive,
                            postsList: feedPosts,
                            onLoadMore: widget.fromFeed
                                ? () => ref
                                    .read(feedControllerProvider.notifier)
                                    .loadNextPage()
                                : null,
                            onPostIndexChanged: onPostIndexChanged,
                            localFilePath: localMedia?.savedPath,
                            qualityMode: qualityMode,
                            notes: notes,
                            showNotes: showNotes,
                            mediaHeaders: ref
                                    .watch(postMediaHeadersProvider(post))
                                    .value ??
                                const {},
                            initialPosition: Duration(
                              milliseconds: settings
                                      .videoPlaybackPositions[post.cacheKey] ??
                                  0,
                            ),
                            initialLoop: settings.videoPlayerLoop,
                            initialMuted: settings.videoPlayerMuted,
                            initialCoverVideo: settings.videoPlayerCover,
                            initialHalfVolume: settings.videoPlayerHalfVolume,
                            initialVolume: settings.videoPlayerVolume,
                            onVolumeChanged: (vol) => ref
                                .read(settingsControllerProvider.notifier)
                                .setVideoPlayerVolume(vol),
                            onPlaybackSnapshot: (snapshot) =>
                                _saveVideoSnapshot(ref, post, snapshot),
                            onPlaybackPreferencesChanged: (snapshot) =>
                                _saveVideoPreferences(ref, snapshot),
                            onMediaGestureLockChanged: (locked) {
                              onMediaGestureLockChanged?.call(locked);
                            },
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: singleMediaHeight,
                      child: PostMediaViewer(
                        key: ValueKey(post.cacheKey),
                        post: post,
                        useLiveFeed: widget.fromFeed,
                        isActive: isActive,
                        postsList: feedPosts,
                        onLoadMore: widget.fromFeed
                            ? () => ref
                                .read(feedControllerProvider.notifier)
                                .loadNextPage()
                            : null,
                        onPostIndexChanged: onPostIndexChanged,
                        localFilePath: localMedia?.savedPath,
                        qualityMode: qualityMode,
                        notes: notes,
                        showNotes: showNotes,
                        mediaHeaders:
                            ref.watch(postMediaHeadersProvider(post)).value ??
                                const {},
                        initialPosition: Duration(
                          milliseconds:
                              settings.videoPlaybackPositions[post.cacheKey] ??
                                  0,
                        ),
                        initialLoop: settings.videoPlayerLoop,
                        initialMuted: settings.videoPlayerMuted,
                        initialCoverVideo: settings.videoPlayerCover,
                        initialHalfVolume: settings.videoPlayerHalfVolume,
                        initialVolume: settings.videoPlayerVolume,
                        onVolumeChanged: (vol) => ref
                            .read(settingsControllerProvider.notifier)
                            .setVideoPlayerVolume(vol),
                        onPlaybackSnapshot: (snapshot) =>
                            _saveVideoSnapshot(ref, post, snapshot),
                        onPlaybackPreferencesChanged: (snapshot) =>
                            _saveVideoPreferences(ref, snapshot),
                        onMediaGestureLockChanged: (locked) {
                          onMediaGestureLockChanged?.call(locked);
                        },
                      ),
                    ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(post.cacheKey),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!MediaUrlSelector.isVideo(post) &&
                      !MediaUrlSelector.isAudio(post) &&
                      (post.providerId.toLowerCase().contains('e621') ||
                          post.providerId.toLowerCase().contains('e926') ||
                          post.hasNotes)) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: GoogleTranslateButton(
                        hasNotes: notes.isNotEmpty,
                        isLoading: notesAsync.isLoading,
                        showNotes: showNotes,
                        notesCount: notes.length,
                        isRu: strings.ru,
                        onToggle: () {
                          ref
                              .read(
                                  showPostNotesProvider(post.cacheKey).notifier)
                              .state = !showNotes;
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  PostActionBar(
                    isFavorite: favoriteKeys.contains(post.cacheKey),
                    labels: _postActionLabels(strings),
                    downloaded: localMedia != null,
                    isDownloading: isDownloading,
                    onFavorite: () => _toggleFavorite(ref, post, favoriteKeys),
                    onCollection: () => _addToCollection(context, ref, post),
                    onOpen: () => launchUrl(Uri.parse(post.fileUrl)),
                    onOpenSource: () => _openSourcePage(ref, post),
                    onCopy: () =>
                        Clipboard.setData(ClipboardData(text: post.fileUrl)),
                    onSimilar: () => _openSimilar(context, ref, post),
                    onHide: () => _hidePost(context, ref, post),
                    onDownload: settings.allowDownloads
                        ? () => _download(context, ref, post)
                        : null,
                    onSaveAs: settings.allowDownloads
                        ? () => _saveAs(context, ref, post)
                        : null,
                    onDeleteLocalFile: () =>
                        _deleteLocalFile(context, ref, post),
                    onShare: () => _sharePost(context, ref, post),
                  ),
                  const SizedBox(height: 12),
                  PostInfoCard(
                    post: post,
                    strings: strings,
                    localMedia: localMedia,
                    fileSizeBytes: fileSizeBytes,
                    e621Provider: e621Provider,
                  ),
                  ArtistPostsCard(
                    post: post,
                    onOpenPost: (p, filtered) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostDetailsScreen(
                          providerId: p.providerId,
                          postId: p.id,
                          initialPost: p,
                          postsList: filtered,
                        ),
                      ),
                    ),
                  ),
                  if (post.hasRelations) ...[
                    const SizedBox(height: 12),
                    PostRelationsCard(
                      post: post,
                      onOpenPostId: (targetId) =>
                          _openPostById(context, post.providerId, targetId),
                    ),
                  ],
                  if (post.hasPools && e621Provider != null) ...[
                    const SizedBox(height: 12),
                    PostPoolsCard(
                      post: post,
                      provider: e621Provider,
                      onOpenComic: (poolId, currentPost, [targetId]) =>
                          _openComic(context, e621Provider, poolId, currentPost,
                              targetId),
                      onOpenPostId: (targetId) =>
                          _openPostById(context, post.providerId, targetId),
                    ),
                  ],
                  if (shouldShowCloudCard) ...[
                    const SizedBox(height: 12),
                    CloudMirrorsCard(
                      links: post.cloudLinks,
                      strings: strings,
                      commentary: isTextOnly ? null : post.commentary,
                      onPlayStream: (streamUrl) => launchUrl(
                        Uri.parse(streamUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      onDownloadStream: settings.allowDownloads
                          ? (streamUrl) =>
                              _downloadUrl(context, ref, post, streamUrl)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh
                              .withValues(alpha: 0.70)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.40),
                        width: 1.1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      initiallyExpanded: false,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(
                        Icons.tag_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        '${strings.tags} (${post.cleanTags.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PostTagsPanel(post: post),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CommentsSection(post: post),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
    final targetPost = post ?? _activePost;
    if (targetPost == null) return;
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
      postsList: feedPosts.isNotEmpty ? feedPosts : [targetPost],
      qualityMode: qualityMode,
      notes: notes,
      showNotes: showNotes,
      localFilePath: localMedia?.savedPath,
      useLiveFeed: widget.fromFeed,
      onPostChanged: (index) {
        if (index >= 0 && index < feedPosts.length) {
          final newPost = feedPosts[index];
          _openPost(context, newPost);
        }
      },
      onLoadMore: widget.fromFeed
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
