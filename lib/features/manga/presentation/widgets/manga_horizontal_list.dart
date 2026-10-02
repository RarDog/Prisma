import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';

class MangaHorizontalList extends StatelessWidget {
  const MangaHorizontalList({
    required this.title,
    required this.icon,
    required this.items,
    required this.onSelect,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Post> items;
  final ValueChanged<Post> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFF6740)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              '${items.length}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final itemTitle = item.title ?? item.tags.take(2).join(', ');
              final coverUrl = item.previewUrl.isNotEmpty
                  ? item.previewUrl
                  : item.sampleUrl;

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelect(item);
                },
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 0.72,
                          child: coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  httpHeaders: getPostMediaHeaders(item),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.white10,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFF6740),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.white10,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.white38,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.auto_stories_rounded,
                                    color: Colors.white38,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        itemTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
