import 'package:flutter/material.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/settings/models/post_card_badge_config.dart';
import 'package:gel_rule_app/shared/widgets/rating_badge.dart';
import 'post_card_badges.dart';

/// Renders badge widgets in configured card corners (topLeft, topRight, bottomLeft, bottomRight).
class PostCardBadgesOverlay extends StatelessWidget {
  const PostCardBadgesOverlay({
    required this.post,
    required this.badgeConfig,
    required this.showBadges,
    required this.isFavorite,
    required this.isViewed,
    required this.isDownloaded,
    required this.isMobile,
    required this.onFavorite,
    required this.isVideoPost,
    required this.isAudioPost,
    required this.isTextPost,
    super.key,
  });

  final Post post;
  final PostCardBadgeConfig badgeConfig;
  final bool showBadges;
  final bool isFavorite;
  final bool isViewed;
  final bool isDownloaded;
  final bool isMobile;
  final VoidCallback onFavorite;
  final bool isVideoPost;
  final bool isAudioPost;
  final bool isTextPost;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Widget>> cornerWidgets = {
      'topLeft': [],
      'topRight': [],
      'bottomLeft': [],
      'bottomRight': [],
    };

    if (showBadges) {
      if (badgeConfig.showProvider) {
        cornerWidgets[badgeConfig.providerPosition]?.add(
          ProviderBadge(
            name: post.providerName,
            providerId: post.providerId,
          ),
        );
      }
      if (badgeConfig.showMediaType) {
        final hasMedia = post.isMultiPage ||
            post.isUgoira ||
            post.fileType.toLowerCase().contains('video') ||
            post.fileType.toLowerCase().contains('webm') ||
            post.fileType.toLowerCase().contains('mp4') ||
            post.fileType.toLowerCase().contains('gif') ||
            isVideoPost ||
            isAudioPost ||
            isTextPost;
        if (hasMedia ||
            post.tagGroups['duration_text']?.isNotEmpty == true) {
          final isRightSide = badgeConfig.mediaTypePosition == 'topRight' ||
              badgeConfig.mediaTypePosition == 'bottomRight';
          cornerWidgets[badgeConfig.mediaTypePosition]?.add(
            Wrap(
              alignment:
                  isRightSide ? WrapAlignment.end : WrapAlignment.start,
              runAlignment:
                  isRightSide ? WrapAlignment.end : WrapAlignment.start,
              spacing: 4,
              runSpacing: 4,
              children: [
                if (post.isMultiPage)
                  PageCountBadge(count: post.pageCount),
                if (post.tagGroups['duration_text']?.isNotEmpty == true)
                  DurationBadge(
                      duration: post.tagGroups['duration_text']!.first),
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
          );
        }
      }
      if (badgeConfig.showStatus && (isViewed || isDownloaded)) {
        final isRightSide = badgeConfig.statusPosition == 'topRight' ||
            badgeConfig.statusPosition == 'bottomRight';
        cornerWidgets[badgeConfig.statusPosition]?.add(
          Wrap(
            alignment: isRightSide ? WrapAlignment.end : WrapAlignment.start,
            runAlignment:
                isRightSide ? WrapAlignment.end : WrapAlignment.start,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (isViewed) const SeenBadge(),
              if (isDownloaded) const DownloadedBadge(),
            ],
          ),
        );
      }
      if (badgeConfig.showRating) {
        cornerWidgets[badgeConfig.ratingPosition]?.add(
          RatingBadge(rating: post.rating),
        );
      }
    }

    if (isMobile && badgeConfig.showFavorite) {
      cornerWidgets[badgeConfig.favoritePosition]?.add(
        FavoriteButton(
          isFavorite: isFavorite,
          onPressed: onFavorite,
        ),
      );
    }

    return Positioned.fill(
      child: Stack(
        children: [
        if (cornerWidgets['topLeft']!.isNotEmpty)
          Positioned(
            left: 8,
            top: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < cornerWidgets['topLeft']!.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  cornerWidgets['topLeft']![i],
                ],
              ],
            ),
          ),
        if (cornerWidgets['topRight']!.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < cornerWidgets['topRight']!.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  cornerWidgets['topRight']![i],
                ],
              ],
            ),
          ),
        if (cornerWidgets['bottomLeft']!.isNotEmpty)
          Positioned(
            left: 8,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < cornerWidgets['bottomLeft']!.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  cornerWidgets['bottomLeft']![i],
                ],
              ],
            ),
          ),
        if (cornerWidgets['bottomRight']!.isNotEmpty)
          Positioned(
            right: 8,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < cornerWidgets['bottomRight']!.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  cornerWidgets['bottomRight']![i],
                ],
              ],
            ),
          ),
      ],
      ),
    );
  }
}
