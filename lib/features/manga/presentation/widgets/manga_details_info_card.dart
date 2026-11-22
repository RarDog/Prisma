import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Widget _infoRow(
    String label,
    String value, {
    VoidCallback? onTap,
    Color? valueColor,
    bool isMonospace = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    Color? statusColor;
    if (status != null) {
      statusColor = switch (status!.toLowerCase()) {
        'ongoing' => const Color(0xFF10B981),
        'completed' => const Color(0xFF3B82F6),
        'hiatus' => const Color(0xFFF59E0B),
        'cancelled' => const Color(0xFFEF4444),
        _ => null,
      };
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFFFF6740),
              ),
              const SizedBox(width: 8),
              Text(
                isRu ? 'Информация о тайтле' : 'Manga Info',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(isRu ? 'Источник' : 'Source', post.providerName),
          if (post.id.isNotEmpty)
            _infoRow(
              'ID',
              post.id,
              isMonospace: true,
              onTap: () {
                Clipboard.setData(ClipboardData(text: post.id));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isRu ? 'ID скопирован' : 'ID copied'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          if (author != null) _infoRow(isRu ? 'Автор' : 'Author', author!),
          if (artist != null && artist != author)
            _infoRow(isRu ? 'Художник' : 'Artist', artist!),
          _infoRow(isRu ? 'Страниц' : 'Pages', '$totalPages'),
          if (chaptersCount > 0)
            _infoRow(isRu ? 'Всего глав' : 'Total chapters', '$chaptersCount'),
          if (rating != null)
            _infoRow(
              isRu ? 'Рейтинг' : 'Rating',
              rating!.toUpperCase(),
              valueColor: rating!.toLowerCase() == 'pornographic'
                  ? const Color(0xFFEF4444)
                  : null,
            ),
          if (status != null)
            _infoRow(
              isRu ? 'Статус' : 'Status',
              status!.toUpperCase(),
              valueColor: statusColor,
            ),
        ],
      ),
    );
  }
}
