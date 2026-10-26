import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/motion.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'blur_content.dart';
import 'loading_skeleton.dart';
import 'rating_badge.dart';
import 'post_card/feed_video_preview.dart';
import 'post_card/post_card_badges.dart';
import 'post_card/post_card_previews.dart';

class PostCard extends ConsumerStatefulWidget {
  static void clearResolvedPostCache() {
    _PostCardState.clearResolvedPostCache();
  }

  const PostCard({
    required this.post,
    required this.blurExplicit,
    required this.showBadges,
    required this.isFavorite,
    required this.isViewed,
    required this.isDownloaded,
    required this.mediaQualityMode,
    required this.onOpen,
    required this.onFavorite,
    this.onAddToCollection,
    this.onPreview,
    this.onHide,
    this.onToggleSelected,
    this.selectionMode = false,
    this.selected = false,
    this.forceSquare = false,
    super.key,
  });

  final Post post;
  final bool blurExplicit;
  final bool showBadges;
  final bool isFavorite;
  final bool isViewed;
  final bool isDownloaded;
  final MediaQualityMode mediaQualityMode;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onPreview;
  final VoidCallback? onHide;
  final VoidCallback? onToggleSelected;
  final bool selectionMode;
  final bool selected;
  final bool forceSquare;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  static final Map<String, Post> _resolvedRealbooruPosts = {};
  static const int _maxResolvedPostsCache = 200;

  static void _cacheResolvedPost(String key, Post post) {
    if (_resolvedRealbooruPosts.length >= _maxResolvedPostsCache) {
      _resolvedRealbooruPosts.remove(_resolvedRealbooruPosts.keys.first);
    }
    _resolvedRealbooruPosts[key] = post;
  }

  static void clearResolvedPostCache() {
    _resolvedRealbooruPosts.clear();
  }

  bool _hovered = false;
  bool _pressed = false;
  bool _videoHoverActive = false;
  Timer? _videoHoverTimer;
  Post? _resolvedPost;
  bool _showHeart = false;
  AnimationController? _heartController;
  Animation<double>? _heartScale;
  Animation<double>? _heartOpacity;

  @override
  void initState() {
    super.initState();
    SmartMemoryManager.registerTrimCallback(clearResolvedPostCache);
    _resolvedPost = _resolvedRealbooruPosts[widget.post.cacheKey];
    _maybeResolveRealbooruPost();
  }

  void _ensureHeartAnimation() {
    if (_heartController != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.4, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
    ]).animate(controller);
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(controller);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showHeart = false);
        controller.reset();
      }
    });
    _heartController = controller;
  }

  @override
  void dispose() {
    _videoHoverTimer?.cancel();
    _heartController?.dispose();
    super.dispose();
  }

  void _triggerDoubleTapFavorite() {
    HapticFeedback.lightImpact();
    widget.onFavorite();
    _ensureHeartAnimation();
    setState(() => _showHeart = true);
    _heartController?.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final post = _resolvedPost ?? widget.post;
    final sensitive = _isSensitive(post.rating);
    final isAudioPost =
        MediaUrlSelector.isAudio(post) || post.fileType == 'audio';
    final isVideoPost = MediaUrlSelector.isVideo(post);
    final isTextPost = post.fileType == 'text' ||
        (post.previewUrl.trim().isEmpty &&
            post.sampleUrl.trim().isEmpty &&
            post.fileUrl.trim().isEmpty &&
            !isVideoPost &&
            !isAudioPost);
    final aspect = widget.forceSquare
        ? 1.0
        : (post.width > 0 && post.height > 0
            ? post.width / post.height
            : _fallbackAspect(
                isTextPost ? 'text' : (isAudioPost ? 'audio' : post.fileType)));
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final urls = _feedUrls(post, mobile: mobile);
    final imageUrl = urls.isEmpty ? post.previewUrl : urls.first;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _videoHoverTimer?.cancel();
        if (MediaUrlSelector.isVideo(widget.post)) {
          _videoHoverTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && _hovered) {
              setState(() => _videoHoverActive = true);
            }
          });
        } else {
          _prewarmDetailsImage(context, widget.post);
        }
      },
      onExit: (_) {
        _videoHoverTimer?.cancel();
        setState(() {
          _hovered = false;
          _videoHoverActive = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          if (widget.selectionMode) {
            widget.onToggleSelected?.call();
            return;
          }
          widget.onOpen();
        },
        onDoubleTap: _triggerDoubleTapFavorite,
        onLongPress: () {
          if (widget.selectionMode && widget.onToggleSelected != null) {
            widget.onToggleSelected!();
            return;
          }
          if (widget.onPreview != null) {
            widget.onPreview!();
            return;
          }
          widget.onToggleSelected?.call();
        },
        onSecondaryTapDown: (details) {
          showMenu<void>(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy,
              details.globalPosition.dx,
              details.globalPosition.dy,
            ),
            items: [
              PopupMenuItem(
                onTap: widget.onOpen,
                child: const Text('Open'),
              ),
              PopupMenuItem(
                onTap: widget.onFavorite,
                child: const Text('Favorite'),
              ),
              if (widget.onAddToCollection != null)
                PopupMenuItem(
                  onTap: widget.onAddToCollection,
                  child: const Text('Add to collection'),
                ),
              if (widget.onHide != null)
                PopupMenuItem(
                  onTap: widget.onHide,
                  child: const Text('Hide post'),
                ),
            ],
          );
        },
        child: AnimatedScale(
          scale: _pressed ? 0.978 : (_hovered && !mobile ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: _wrapWithMultiPageStack(
            context,
            theme,
            isDark,
            post,
            Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? theme.colorScheme.primary
                    : (_hovered && !mobile
                        ? theme.colorScheme.primary.withValues(alpha: 0.55)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08))),
                width: widget.selected ? 2.0 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.35)
                      : (_hovered && !mobile
                          ? theme.colorScheme.primary.withValues(alpha: 0.22)
                          : Colors.black
                              .withValues(alpha: isDark ? 0.32 : 0.08)),
                  blurRadius: _hovered && !mobile ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15.2),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: aspect.clamp(0.28, 2.2),
                    child: BlurContent(
                      enabled: widget.blurExplicit && sensitive,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (isTextPost) {
                            return TextPostCardPreview(
                              post: post,
                              hovered: _hovered && !mobile,
                            );
                          }
                          if (isAudioPost &&
                              (imageUrl.isEmpty ||
                                  !imageUrl.startsWith('http'))) {
                            return AudioPostCardPreview(
                              post: post,
                              hovered: _hovered && !mobile,
                            );
                          }
                          if (isVideoPost &&
                              (imageUrl.isEmpty ||
                                  !imageUrl.startsWith('http'))) {
                            return VideoPostCardPreview(
                              post: post,
                              hovered: _hovered && !mobile,
                            );
                          }
                          final dpr = MediaQuery.devicePixelRatioOf(context);
                          final cacheWidth = (constraints.maxWidth * dpr)
                              .round()
                              .clamp(280, 960);
                          final memCacheWidth = switch (widget.mediaQualityMode) {
                            MediaQualityMode.original =>
                              (constraints.maxWidth * dpr * 2)
                                  .round()
                                  .clamp(480, 2560),
                            MediaQualityMode.highQuality =>
                              (constraints.maxWidth * dpr * 1.5)
                                  .round()
                                  .clamp(360, 1440),
                            _ => cacheWidth,
                          };
                          final maxDiskWidth = switch (widget.mediaQualityMode) {
                            MediaQualityMode.original => null,
                            MediaQualityMode.highQuality =>
                              (constraints.maxWidth * dpr * 2)
                                  .round()
                                  .clamp(720, 1920),
                            _ => cacheWidth,
                          };
                          final headers = _headersFor(post);
                          final videoUrls = MediaUrlSelector.video(post);
                          if (!mobile &&
                              _videoHoverActive &&
                              MediaUrlSelector.isVideo(post) &&
                              videoUrls.isNotEmpty) {
                            return FeedVideoPreview(
                              videoUrl: videoUrls.first,
                              headers: headers,
                              fallbackImageUrl: imageUrl,
                              cacheWidth: cacheWidth,
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            httpHeaders: headers,
                            memCacheWidth: memCacheWidth,
                            maxWidthDiskCache: maxDiskWidth,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const LoadingSkeleton(),
                            errorWidget: (context, url, error) {
                              if (imageUrl != post.previewUrl &&
                                  post.previewUrl.trim().isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: post.previewUrl,
                                  httpHeaders: headers,
                                  memCacheWidth: memCacheWidth,
                                  maxWidthDiskCache: maxDiskWidth,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const LoadingSkeleton(),
                                  errorWidget: (context, url, error) =>
                                      _buildErrorPlaceholder(
                                    context,
                                    isVideoPost,
                                    isAudioPost,
                                  ),
                                );
                              }
                              return _buildErrorPlaceholder(
                                context,
                                isVideoPost,
                                isAudioPost,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  // Bottom cinematic gradient overlay for badges and favorite (only on media posts)
                  if (!isTextPost)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 74,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.82),
                                Colors.black.withValues(alpha: 0.40),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.52, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.showBadges) ...[
                    Positioned(
                      left: 8,
                      top: 8,
                      child: ProviderBadge(name: post.providerName),
                    ),
                    if (post.isMultiPage ||
                        post.isUgoira ||
                        post.fileType.toLowerCase().contains('video') ||
                        post.fileType.toLowerCase().contains('webm') ||
                        post.fileType.toLowerCase().contains('mp4') ||
                        post.fileType.toLowerCase().contains('gif') ||
                        isVideoPost ||
                        isAudioPost ||
                        isTextPost)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (post.isMultiPage)
                              PageCountBadge(count: post.pageCount),
                            if (post.isMultiPage &&
                                (post.isUgoira ||
                                    post.fileType.toLowerCase().contains('video') ||
                                    post.fileType.toLowerCase().contains('webm') ||
                                    post.fileType.toLowerCase().contains('mp4') ||
                                    post.fileType.toLowerCase().contains('gif') ||
                                    isVideoPost ||
                                    isAudioPost ||
                                    isTextPost))
                              const SizedBox(width: 4),
                            if (post.tagGroups['duration_text']?.isNotEmpty == true) ...[
                              DurationBadge(duration: post.tagGroups['duration_text']!.first),
                              const SizedBox(width: 4),
                            ],
                            if (post.isUgoira ||
                                post.fileType.toLowerCase().contains('video') ||
                                post.fileType.toLowerCase().contains('webm') ||
                                post.fileType.toLowerCase().contains('mp4') ||
                                post.fileType.toLowerCase().contains('gif') ||
                                isVideoPost ||
                                isAudioPost ||
                                isTextPost)
                              MediaBadge(
                                fileType: post.isUgoira
                                    ? 'ugoira'
                                    : (isAudioPost
                                        ? 'audio'
                                        : (isTextPost
                                            ? 'text'
                                            : (isVideoPost ? 'video' : post.fileType))),
                              ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isViewed || widget.isDownloaded) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.isViewed) const SeenBadge(),
                                if (widget.isViewed && widget.isDownloaded)
                                  const SizedBox(width: 4),
                                if (widget.isDownloaded)
                                  const DownloadedBadge(),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          RatingBadge(rating: post.rating),
                        ],
                      ),
                    ),
                  ],
                  if (widget.selected)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.24),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.check_circle_rounded),
                          ),
                        ),
                      ),
                    ),
                  if (mobile)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: FavoriteButton(
                        isFavorite: widget.isFavorite,
                        onPressed: widget.onFavorite,
                      ),
                    ),
                  // Double-tap heart animation overlay
                  if (_showHeart &&
                      _heartController != null &&
                      _heartOpacity != null &&
                      _heartScale != null)
                    Positioned.fill(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _heartController!,
                          builder: (context, _) => Opacity(
                            opacity: _heartOpacity!.value,
                            child: Transform.scale(
                              scale: _heartScale!.value,
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 72,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_hovered || mobile,
                      child: AnimatedOpacity(
                        opacity: _hovered && !mobile ? 1 : 0,
                        duration: AppMotion.duration(context, 140),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: widget.isFavorite
                                        ? 'Remove favorite'
                                        : 'Favorite',
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      widget.onFavorite();
                                    },
                                    icon: Icon(
                                      widget.isFavorite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    tooltip: 'Add to collection',
                                    onPressed: widget.onAddToCollection,
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                  if (widget.onHide != null) ...[
                                    const SizedBox(width: 6),
                                    IconButton.filledTonal(
                                      tooltip: 'Hide post',
                                      onPressed: widget.onHide,
                                      icon: const Icon(
                                          Icons.visibility_off_rounded),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _wrapWithMultiPageStack(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Post post,
    Widget cardChild,
  ) {
    if (!post.isMultiPage) return cardChild;

    final sheetColor =
        isDark ? const Color(0xFF1E2024) : const Color(0xFFF1F3F5);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);
    final count = post.pageCount;
    final showThirdSheet = count >= 3;

    return Padding(
      padding: EdgeInsets.only(
        top: showThirdSheet ? 5.0 : 3.5,
        right: showThirdSheet ? 5.0 : 3.5,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Third sheet (bottom-most, visible if 3+ pages)
          if (showThirdSheet)
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(5.0, -5.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 4,
                        offset: const Offset(1, -1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Second sheet (middle, visible if 2+ pages)
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(2.5, -2.5),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 5,
                      offset: const Offset(1, -1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Foreground card
          cardChild,
        ],
      ),
    );
  }

  bool _isSensitive(String rating) {
    final normalized = rating.toLowerCase();
    return normalized.startsWith('e') ||
        normalized.startsWith('q') ||
        normalized.contains('explicit') ||
        normalized.contains('questionable');
  }

  double _fallbackAspect(String fileType) {
    final normalized = fileType.toLowerCase();
    if (normalized == 'text') return 0.95;
    if (normalized == 'audio' || normalized.contains('mp3')) return 1.25;
    if (normalized.contains('video') || normalized.contains('webm')) {
      return 16 / 9;
    }
    if (normalized.contains('gif')) return 1;
    return 0.72;
  }

  Widget _buildErrorPlaceholder(
    BuildContext context,
    bool isVideoPost,
    bool isAudioPost,
  ) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          isVideoPost
              ? Icons.videocam_outlined
              : (isAudioPost
                  ? Icons.music_note_rounded
                  : Icons.broken_image_rounded),
        ),
      ),
    );
  }

  static final Set<String> _prewarmedDetailUrls = {};

  void _prewarmDetailsImage(BuildContext context, Post post) {
    final detailsUrls =
        MediaUrlSelector.details(post, mode: widget.mediaQualityMode);
    final url = detailsUrls.firstOrNull;
    if (url == null || url.trim().isEmpty || url == post.previewUrl) return;
    if (_prewarmedDetailUrls.contains(url)) return;
    if (_prewarmedDetailUrls.length >= 300) {
      _prewarmedDetailUrls.remove(_prewarmedDetailUrls.first);
    }
    _prewarmedDetailUrls.add(url);
    final headers = _headersFor(post);
    final provider = CachedNetworkImageProvider(url, headers: headers);
    unawaited(
      precacheImage(
        provider,
        context,
        onError: (_, __) {},
      ),
    );
  }

  List<String> _feedUrls(Post post, {required bool mobile}) {
    return MediaUrlSelector.feed(
      post,
      mode: widget.mediaQualityMode,
      mobile: mobile,
    );
  }

  Map<String, String> _headersFor(Post post) {
    return getPostMediaHeaders(post);
  }

  void _maybeResolveRealbooruPost() {
    final post = widget.post;
    if (!_needsRealbooruDetails(post) ||
        _resolvedRealbooruPosts.containsKey(post.cacheKey)) {
      return;
    }
    Future<void>(() async {
      final result = await ref
          .read(providerManagerProvider)
          .getPost(post.providerId, post.id);
      if (!mounted) return;
      if (result is Success<Post?> && result.data != null) {
        final resolved = result.data!;
        _cacheResolvedPost(post.cacheKey, resolved);
        setState(() => _resolvedPost = resolved);
      }
    });
  }

  bool _needsRealbooruDetails(Post post) {
    if (post.providerId != 'realbooru' && post.providerId != 'rule34_us') {
      return false;
    }
    return post.fileUrl.isEmpty || post.fileUrl == post.previewUrl;
  }
}

Future<void> showAddToCollectionPicker(
  BuildContext context, {
  required List<Collection> collections,
  required void Function(Collection collection) onSelected,
  required VoidCallback onCreate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.add_rounded),
          title: const Text('Create collection'),
          onTap: () {
            Navigator.pop(context);
            onCreate();
          },
        ),
        for (final collection in collections)
          ListTile(
            title: Text(collection.name),
            subtitle: Text(collection.description ?? ''),
            onTap: () {
              Navigator.pop(context);
              onSelected(collection);
            },
          ),
      ],
    ),
  );
}

