import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/shared/widgets/formatted_content_text.dart';

class UnsupportedSwfPanel extends StatelessWidget {
  const UnsupportedSwfPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.extension_off_rounded, color: Colors.white, size: 48),
              SizedBox(height: 12),
              Text(
                'SWF / Flash is not supported in this build',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CloudMediaHero extends StatelessWidget {
  const CloudMediaHero({
    required this.post,
    this.onOpenPrimary,
    super.key,
  });

  final Post post;
  final VoidCallback? onOpenPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final links = post.cloudLinks;
    final primaryColor =
        links.isNotEmpty ? links.first.brandColor : theme.colorScheme.primary;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                links.isNotEmpty
                    ? links.first.iconData
                    : Icons.cloud_queue_rounded,
                size: 34,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRu ? 'Контент на внешнем диске' : 'Cloud Drive Media',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              links.isNotEmpty
                  ? (isRu
                      ? 'Автор опубликовал медиа на ${links.map((l) => l.serviceName).toSet().join(', ')}.'
                      : 'Author hosted media on ${links.map((l) => l.serviceName).toSet().join(', ')}.')
                  : (isRu
                      ? 'В данном посте нет медиафайла на сервере.'
                      : 'No media file hosted directly on the server.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(
                  isRu
                      ? 'Открыть ${links.first.serviceName}'
                      : 'Open ${links.first.serviceName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: onOpenPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TextArticleHero extends StatelessWidget {
  const TextArticleHero({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final title = (post.title ?? '').trim();
    final cleanContent =
        CloudLinkExtractor.cleanCommentary(post.description ?? '');
    final displayContent = cleanContent.isNotEmpty
        ? cleanContent
        : (title.isNotEmpty
            ? ''
            : (isRu
                ? 'Публикация автора без текста и вложений'
                : 'Author post without text or attachments'));
    final creatorLinks = CreatorLink.extractLinks(post.description ?? '');
    final cleanTags = post.cleanTags;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.article_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu ? 'Текстовая публикация' : 'Text post',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${post.providerName} • ${post.createdAt.day.toString().padLeft(2, '0')}.${post.createdAt.month.toString().padLeft(2, '0')}.${post.createdAt.year}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: isRu ? 'Скопировать текст' : 'Copy text',
                    onPressed: () {
                      final textToCopy = [
                        if (title.isNotEmpty) title,
                        if (displayContent.isNotEmpty) displayContent,
                      ].join('\n\n');
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isRu
                                ? 'Текст скопирован в буфер обмена'
                                : 'Text copied to clipboard',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              if (displayContent.isNotEmpty)
                FormattedContentText(
                  text: displayContent,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    letterSpacing: 0.15,
                  ),
                ),
              if (creatorLinks.isNotEmpty) ...[
                const SizedBox(height: 18),
                CreatorLinkChips(
                  links: creatorLinks,
                  title:
                      isRu ? 'Ссылки из публикации' : 'Links from publication',
                ),
              ],
              if (cleanTags.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cleanTags.take(8).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
