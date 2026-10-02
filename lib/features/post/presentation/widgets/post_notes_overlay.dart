import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_note.dart';

class PostNotesOverlay extends StatelessWidget {
  const PostNotesOverlay({
    required this.post,
    required this.notes,
    super.key,
  });

  final Post post;
  final List<PostNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty || post.width <= 0 || post.height <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = Size(post.width.toDouble(), post.height.toDouble());
        final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
        final renderedW = fitted.destination.width;
        final renderedH = fitted.destination.height;
        final dx = (containerSize.width - renderedW) / 2.0;
        final dy = (containerSize.height - renderedH) / 2.0;
        final scaleX = renderedW / post.width;
        final scaleY = renderedH / post.height;

        return Stack(
          children: [
            for (final note in notes)
              if (note.isActive)
                Positioned(
                  left: dx + (note.x * scaleX),
                  top: dy + (note.y * scaleY),
                  width: (note.width * scaleX).clamp(16.0, renderedW),
                  height: (note.height * scaleY).clamp(16.0, renderedH),
                  child: NoteBox(note: note),
                ),
          ],
        );
      },
    );
  }
}

class NoteBox extends StatelessWidget {
  const NoteBox({required this.note, super.key});

  final PostNote note;

  static String cleanNoteBody(String raw) {
    var text = raw
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    text = text.replaceAll(RegExp(r'\[/?[a-zA-Z0-9_=#]+\]'), '');
    text = text.replaceAll(RegExp(r'</?[a-zA-Z0-9_]+>'), '');
    return text.trim();
  }

  static void showNoteDialog(BuildContext context, PostNote note) {
    final cleaned = cleanNoteBody(note.body);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.translate_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.authorName != null && note.authorName!.isNotEmpty
                      ? '${isRu ? "Перевод" : "Translation"} (${note.authorName})'
                      : (isRu ? 'Перевод' : 'Translation'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SelectableText(
            cleaned,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(isRu ? 'Копировать' : 'Copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cleaned));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isRu
                          ? 'Текст перевода скопирован'
                          : 'Translation text copied',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(isRu ? 'Закрыть' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = cleanNoteBody(note.body);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showNoteDialog(context, note),
      child: Tooltip(
        message: cleaned,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey.shade900 : Colors.grey.shade200)
                .withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isDark ? Colors.white54 : Colors.black45,
              width: 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                cleaned,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
