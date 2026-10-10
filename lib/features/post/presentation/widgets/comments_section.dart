import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_controller.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<PostComment>, PostDetailsArgs>((ref, args) async {
  final result = await ref
      .watch(providerManagerProvider)
      .getComments(args.providerId, args.postId);
  return result is Success<List<PostComment>> ? result.data : const [];
});

class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  bool _expanded = false;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final providerInstance = await ref
        .read(providerManagerProvider)
        .getProviderInstance(widget.post.providerId);
    if (providerInstance is! E621Provider) return;

    if (!providerInstance.isAuthorized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Для отправки комментариев укажите API-ключ e621 в Источниках'
                : 'To post comments, specify e621 API key in Sources',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final created = await providerInstance.createComment(
      postId: widget.post.id,
      body: text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created != null) {
      _commentController.clear();
      ref.invalidate(
        postCommentsProvider(
          PostDetailsArgs(
            providerId: widget.post.providerId,
            postId: widget.post.id,
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'Комментарий опубликован!' : 'Comment posted!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Не удалось отправить комментарий'
                : 'Failed to post comment',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final comments = _expanded
        ? ref.watch(
            postCommentsProvider(
              PostDetailsArgs(
                providerId: widget.post.providerId,
                postId: widget.post.id,
              ),
            ),
          )
        : null;
    final scheme = Theme.of(context).colorScheme;
    final isE621 =
        widget.post.providerId == 'e621' || widget.post.providerId == 'e926';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          color: scheme.primary,
        ),
        onExpansionChanged: (value) => setState(() => _expanded = value),
        title: Text(
          strings.comments,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: [
          (comments ?? const AsyncValue<List<PostComment>>.data([])).when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                strings.commentsUnavailable,
                style: TextStyle(color: scheme.outline),
              ),
            ),
            data: (items) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        strings.noComments,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final comment in items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: scheme.primaryContainer,
                              child: Text(
                                (comment.authorName.isNotEmpty
                                        ? comment.authorName[0]
                                        : '?')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.authorName.isEmpty
                                        ? strings.anonymous
                                        : comment.authorName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.body,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (isE621) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: strings.ru
                                  ? 'Написать комментарий...'
                                  : 'Add a comment...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                              filled: true,
                              fillColor: scheme.surfaceContainerHigh,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onSubmitted: (_) => _submitComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSubmitting ? null : _submitComment,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          tooltip: strings.ru ? 'Отправить' : 'Send',
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
