import 'package:flutter/material.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/utils/cloud_link_extractor.dart';

class TextPostCardPreview extends StatelessWidget {
  const TextPostCardPreview({
    super.key,
    required this.post,
    required this.hovered,
  });

  final Post post;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);
    final title = (post.title ?? '').trim();
    final cleanContent =
        CloudLinkExtractor.cleanCommentary(post.description ?? '');
    final hasTitle = title.isNotEmpty;
    final snippet = cleanContent.isNotEmpty
        ? cleanContent
        : (hasTitle
            ? ''
            : (isRu
                ? 'Текстовая публикация автора без вложений'
                : 'Text post by author without attachments'));
    final cloudCount = post.cloudLinks.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHigh,
            theme.colorScheme.surfaceContainer,
          ],
        ),
        border: Border.all(
          color: hovered
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notes_rounded,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${post.createdAt.day.toString().padLeft(2, '0')}.${post.createdAt.month.toString().padLeft(2, '0')}.${post.createdAt.year}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasTitle) ...[
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (snippet.isNotEmpty)
            Expanded(
              child: Text(
                snippet,
                maxLines: hasTitle ? 5 : 7,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.42,
                ),
              ),
            )
          else
            const Spacer(),
          if (cloudCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_download_outlined,
                        size: 12,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRu
                            ? 'Вложения ($cloudCount)'
                            : 'Attachments ($cloudCount)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AudioPostCardPreview extends StatelessWidget {
  const AudioPostCardPreview({
    super.key,
    required this.post,
    required this.hovered,
  });

  final Post post;
  final bool hovered;

  String _deriveAudioTitle(bool isRu) {
    final title = (post.title ?? '').trim();
    if (title.isNotEmpty) return title;
    final uri = Uri.tryParse(post.fileUrl);
    if (uri != null) {
      final queryParam = uri.queryParameters['f'];
      if (queryParam != null && queryParam.trim().isNotEmpty) {
        return queryParam.trim();
      }
      final lastSeg = uri.pathSegments.lastOrNull;
      if (lastSeg != null && lastSeg.isNotEmpty) {
        return lastSeg;
      }
    }
    final artist = post.tagGroups['artist']?.firstOrNull;
    if (artist != null && artist.isNotEmpty) {
      return isRu ? 'Аудиозапись от $artist' : 'Audio track by $artist';
    }
    return isRu ? 'Аудиозапись' : 'Audio track';
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);
    final audioTitle = _deriveAudioTitle(isRu);
    final artistName =
        post.tagGroups['artist']?.firstOrNull ?? post.providerName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(
          color: hovered
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.audiotrack_rounded,
                  size: 20,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${post.createdAt.day.toString().padLeft(2, '0')}.${post.createdAt.month.toString().padLeft(2, '0')}.${post.createdAt.year}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            audioTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.25,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_filled_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isRu ? 'Воспроизвести' : 'Play',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VideoPostCardPreview extends StatelessWidget {
  const VideoPostCardPreview({
    super.key,
    required this.post,
    required this.hovered,
  });

  final Post post;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (post.title ?? '').trim();
    final artistName =
        post.tagGroups['artist']?.firstOrNull ?? post.providerName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ],
        ),
        border: Border.all(
          color: hovered
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  )
                else
                  Text(
                    artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


