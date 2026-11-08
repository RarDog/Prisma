import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_note.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'fullscreen_image_viewer_page.dart';
import 'post_media_headers.dart';
import 'post_playback_memory.dart';

/// True while the fullscreen gallery modal is pushed onto the root navigator.
final isFullscreenViewerActiveProvider = StateProvider<bool>((ref) => false);

/// Tracks dynamically resolved image dimensions for posts that lack width/height metadata.
final postMediaDimensionsProvider =
    StateProvider.autoDispose.family<Size?, String>((ref, cacheKey) => null);

/// Opens the fullscreen image/video viewer modal for [post] within optional [postsList].
Future<void> openPostFullscreenGallery({
  required BuildContext context,
  required WidgetRef ref,
  required Post post,
  List<Post>? postsList,
  MediaQualityMode qualityMode = MediaQualityMode.auto,
  List<PostNote> notes = const [],
  bool showNotes = false,
  String? localFilePath,
  Duration? initialVideoPosition,
  bool useLiveFeed = false,
  ValueChanged<int>? onPostChanged,
  VoidCallback? onLoadMore,
}) async {
  final initPos =
      initialVideoPosition ?? getPostVideoPlaybackPosition(post.cacheKey);
  ref.read(isFullscreenViewerActiveProvider.notifier).state = true;
  final posts =
      (postsList != null && postsList.isNotEmpty) ? postsList : [post];
  final postIndex = posts.indexWhere((p) => p.cacheKey == post.cacheKey);
  final initialIndex = postIndex >= 0 ? postIndex : 0;

  int? nextIndex;
  try {
    nextIndex = await Navigator.of(context, rootNavigator: true).push<int>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => FullscreenImageViewerPage(
          posts: posts,
          initialIndex: initialIndex,
          qualityMode: qualityMode,
          notes: notes,
          showNotes: showNotes,
          headersBuilder: (p) => getPostMediaHeaders(p),
          localFilePath: localFilePath,
          initialVideoPosition: initPos,
          useLiveFeed: useLiveFeed,
          onPostChanged: onPostChanged,
          onLoadMore: onLoadMore,
        ),
      ),
    );
  } finally {
    ref.read(isFullscreenViewerActiveProvider.notifier).state = false;
  }
  if (nextIndex != null && nextIndex != initialIndex) {
    onPostChanged?.call(nextIndex);
  }
}
