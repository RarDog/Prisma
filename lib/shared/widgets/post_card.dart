import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/settings/models/post_card_badge_config.dart';
import 'blur_content.dart';
import 'loading_skeleton.dart';
import 'post_card/feed_video_preview.dart';
import 'post_card/multi_page_stack_container.dart';
import 'post_card/post_card_badges_overlay.dart';
import 'post_card/post_card_context_menu.dart';
import 'post_card/post_card_hover_actions.dart';
import 'post_card/post_card_previews.dart';

export 'post_card/add_to_collection_picker.dart';
export 'post_card/feed_video_preview.dart';
export 'post_card/multi_page_stack_container.dart';
export 'post_card/post_card_badges.dart';
export 'post_card/post_card_badges_overlay.dart';
export 'post_card/post_card_context_menu.dart';
export 'post_card/post_card_hover_actions.dart';
export 'post_card/post_card_previews.dart';

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
    this.badgeConfig,
    this.customPlaceholder,
    super.key,
  });

  final Post post;
  final bool blurExplicit;
  final bool showBadges;
  final PostCardBadgeConfig? badgeConfig;
  final Widget? customPlaceholder;
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
  Timer? _pressTimer;
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
    _pressTimer?.cancel();
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

    PostCardBadgeConfig badgeConfig =
        widget.badgeConfig ?? const PostCardBadgeConfig();
    if (widget.badgeConfig == null) {
      try {
        badgeConfig = ref.watch(
              appSettingsProvider
                  .select((s) => s.value?.cardBadgeConfig),
            ) ??
            const PostCardBadgeConfig();
      } catch (_) {
        badgeConfig = const PostCardBadgeConfig();
      }
    }

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
        onTapDown: (_) {
          _pressTimer?.cancel();
          _pressTimer = Timer(const Duration(milliseconds: 64), () {
            if (mounted) setState(() => _pressed = true);
          });
        },
        onTapUp: (_) {
          _pressTimer?.cancel();
          if (_pressed) setState(() => _pressed = false);
        },
        onTapCancel: () {
          _pressTimer?.cancel();
          if (_pressed) setState(() => _pressed = false);
        },
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
        onSecondaryTapDown: (details) => showPostCardContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          onOpen: widget.onOpen,
          onFavorite: widget.onFavorite,
          onAddToCollection: widget.onAddToCollection,
          onHide: widget.onHide,
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.978 : (_hovered && !mobile ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: MultiPageStackContainer(
            post: post,
            child: Container(
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
                          if (widget.customPlaceholder != null) {
                            return widget.customPlaceholder!;
                          }
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
                          final isGif = MediaUrlSelector.isGif(post) ||
                              post.fileType.toLowerCase().contains('gif') ||
                              imageUrl.toLowerCase().contains('.gif');
                          return CachedNetworkImage(
                            imageUrl: imageUrl,
                            httpHeaders: headers,
                            memCacheWidth: isGif ? null : memCacheWidth,
                            maxWidthDiskCache: isGif ? null : maxDiskWidth,
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
                  PostCardBadgesOverlay(
                    post: post,
                    badgeConfig: badgeConfig,
                    showBadges: widget.showBadges,
                    isFavorite: widget.isFavorite,
                    isViewed: widget.isViewed,
                    isDownloaded: widget.isDownloaded,
                    isMobile: mobile,
                    onFavorite: widget.onFavorite,
                    isVideoPost: isVideoPost,
                    isAudioPost: isAudioPost,
                    isTextPost: isTextPost,
                  ),
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
                  PostCardHoverActionsOverlay(
                    hovered: _hovered,
                    isMobile: mobile,
                    isFavorite: widget.isFavorite,
                    onFavorite: widget.onFavorite,
                    onAddToCollection: widget.onAddToCollection,
                    onHide: widget.onHide,
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

