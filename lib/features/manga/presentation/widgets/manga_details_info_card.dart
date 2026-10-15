import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';

class MangaDetailsInfoCard extends StatelessWidget {
  const MangaDetailsInfoCard({
    super.key,
    required this.post,
    this.author,
    this.artist,
    required this.totalPages,
    required this.chaptersCount,
    this.rating,
    this.status,
  });

  final Post post;
  final String? author;
  final String? artist;
  final int totalPages;
  final int chaptersCount;
  final String? rating;
  final String? status;

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRu ? 'Информация о тайтле' : 'Manga Info',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _infoRow(isRu ? 'Источник' : 'Source', post.providerName),
          if (post.id.isNotEmpty) _infoRow('ID', post.id),
          if (author != null) _infoRow(isRu ? 'Автор' : 'Author', author!),
          if (artist != null && artist != author)
            _infoRow(isRu ? 'Художник' : 'Artist', artist!),
          _infoRow(isRu ? 'Страниц' : 'Pages', '$totalPages'),
          if (chaptersCount > 0)
            _infoRow(isRu ? 'Всего глав' : 'Total chapters', '$chaptersCount'),
          if (rating != null)
            _infoRow(isRu ? 'Рейтинг' : 'Rating', rating!.toUpperCase()),
          if (status != null)
            _infoRow(isRu ? 'Статус' : 'Status', status!.toUpperCase()),
        ],
      ),
    );
  }
}
