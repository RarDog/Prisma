import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import '../post_details_providers.dart';
import 'post_details_action_handler.dart';

/// Bottom sheet displaying quick actions for a post on mobile devices.
class PostDetailsQuickActionsSheet extends ConsumerWidget {
  const PostDetailsQuickActionsSheet({
    super.key,
    required this.post,
    required this.favoriteKeys,
    this.onToggleFavorite,
    this.onAddToCollection,
    this.onDownload,
    this.onDownloadAllPages,
  });

  final Post post;
  final Set<String> favoriteKeys;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onDownload;
  final ValueChanged<List<Post>>? onDownloadAllPages;

  /// Shows the modal bottom sheet for [post].
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required Post post,
    required Set<String> favoriteKeys,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => PostDetailsQuickActionsSheet(
        post: post,
        favoriteKeys: favoriteKeys,
        onToggleFavorite: () =>
            PostDetailsActionHandler.toggleFavorite(ref, post, favoriteKeys),
        onAddToCollection: () =>
            PostDetailsActionHandler.addToCollection(context, ref, post),
        onDownload: () =>
            PostDetailsActionHandler.download(context, ref, post),
        onDownloadAllPages: (pages) =>
            PostDetailsActionHandler.downloadAllPages(context, ref, pages),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = favoriteKeys.contains(post.cacheKey);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            title: Text(
              isFavorite
                  ? (isRu ? 'Удалить из избранного' : 'Remove favorite')
                  : (isRu ? 'В избранное' : 'Favorite'),
            ),
            onTap: () {
              Navigator.pop(context);
              if (onToggleFavorite != null) {
                onToggleFavorite!();
              } else {
                PostDetailsActionHandler.toggleFavorite(ref, post, favoriteKeys);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark_rounded),
            title: Text(isRu ? 'Добавить в коллекцию' : 'Add to collection'),
            onTap: () {
              Navigator.pop(context);
              if (onAddToCollection != null) {
                onAddToCollection!();
              } else {
                PostDetailsActionHandler.addToCollection(context, ref, post);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(isRu ? 'Копировать ссылку' : 'Copy link'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: post.fileUrl));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: Text(isRu ? 'Скачать' : 'Download'),
            onTap: () {
              Navigator.pop(context);
              if (onDownload != null) {
                onDownload!();
              } else {
                PostDetailsActionHandler.download(context, ref, post);
              }
            },
          ),
          Builder(
            builder: (ctx) {
              final pages =
                  ref.watch(postPagesProvider(PostPagesArgs(post))).value ??
                      [post];
              if (pages.length <= 1) return const SizedBox.shrink();
              final isRu =
                  Localizations.maybeLocaleOf(ctx)?.languageCode == 'ru';
              return ListTile(
                leading: const Icon(Icons.download_for_offline_rounded),
                title: Text(
                  isRu
                      ? 'Скачать все страницы (${pages.length})'
                      : 'Download all pages (${pages.length})',
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (onDownloadAllPages != null) {
                    onDownloadAllPages!(pages);
                  } else {
                    PostDetailsActionHandler.downloadAllPages(
                      context,
                      ref,
                      pages,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
