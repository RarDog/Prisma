import 'dart:io';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';

/// Resolves the list of posts to display in the fullscreen viewer.
///
/// When [useLiveFeed] is true and the post at [currentIndex] is present in the
/// live feed, the live feed is used so paging / load-more continues seamlessly.
List<Post> resolveFullscreenPosts({
  required List<Post> posts,
  required List<Post>? liveFeed,
  required int currentIndex,
  required bool useLiveFeed,
}) {
  if (!useLiveFeed) return posts;
  if (liveFeed == null || liveFeed.isEmpty) return posts;
  if (currentIndex < 0 || currentIndex >= posts.length) return posts;
  // Still on a post that belongs to the live feed, so swapping the list in
  // keeps `onLoadMore` appending instead of resetting the gallery.
  final current = posts[currentIndex];
  return liveFeed.any((p) => p.cacheKey == current.cacheKey) ? liveFeed : posts;
}

/// Helpers for resolving media URLs and video formats in fullscreen mode.
class FullscreenMediaHelpers {
  const FullscreenMediaHelpers._();

  /// Returns true if [url] points to a supported video format file extension.
  static bool isDirectVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.webm') ||
        lower.contains('.mov') ||
        lower.contains('.mkv');
  }

  /// Resolves the ordered candidate URLs to display for [post] at [qualityMode].
  static List<String> urlsForPost(
    Post post,
    MediaQualityMode qualityMode, {
    String? localFilePath,
  }) {
    if (post.fileType == 'text' || post.fileType == 'link') {
      return const [];
    }
    if (localFilePath != null &&
        localFilePath.isNotEmpty &&
        File(localFilePath).existsSync()) {
      return [localFilePath];
    }
    final isGif = MediaUrlSelector.isGif(post) ||
        post.fileUrl.toLowerCase().contains('.gif') ||
        post.fileType.toLowerCase() == 'gif';
    if (isGif) {
      final result = <String>[];
      if (post.fileUrl.isNotEmpty) result.add(post.fileUrl);
      if (post.sampleUrl.isNotEmpty && !result.contains(post.sampleUrl)) {
        result.add(post.sampleUrl);
      }
      if (post.previewUrl.isNotEmpty && !result.contains(post.previewUrl)) {
        result.add(post.previewUrl);
      }
      return result;
    }
    final detailsUrls = MediaUrlSelector.details(post, mode: qualityMode);
    if (detailsUrls.isNotEmpty) {
      return detailsUrls;
    }
    final result = <String>[];
    if (post.sampleUrl.isNotEmpty) result.add(post.sampleUrl);
    if (post.fileUrl.isNotEmpty && !result.contains(post.fileUrl)) {
      result.add(post.fileUrl);
    }
    if (post.previewUrl.isNotEmpty && !result.contains(post.previewUrl)) {
      result.add(post.previewUrl);
    }
    return result;
  }
}
