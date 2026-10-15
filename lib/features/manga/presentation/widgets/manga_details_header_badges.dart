import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MangaDetailsHeaderBadges extends StatefulWidget {
  const MangaDetailsHeaderBadges({
    super.key,
    required this.title,
    this.author,
    this.artist,
    this.rating,
    this.status,
    this.description,
    required this.onFilterByTag,
  });

  final String title;
  final String? author;
  final String? artist;
  final String? rating;
  final String? status;
  final String? description;
  final ValueChanged<String> onFilterByTag;

  @override
  State<MangaDetailsHeaderBadges> createState() =>
      _MangaDetailsHeaderBadgesState();
}

class _MangaDetailsHeaderBadgesState extends State<MangaDetailsHeaderBadges> {
  bool _descriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Title
        Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),

        // Badges row: Author, Artist, Rating, Status
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.author != null)
              ActionChip(
                avatar: const Icon(Icons.person_outline_rounded, size: 16),
                label: Text(widget.author!),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onFilterByTag('author:${widget.author}');
                },
              ),
            if (widget.artist != null && widget.artist != widget.author)
              ActionChip(
                avatar: const Icon(Icons.brush_rounded, size: 16),
                label: Text(widget.artist!),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onFilterByTag('artist:${widget.artist}');
                },
              ),
            if (widget.rating != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.rating!.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (widget.status != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Text(
                  widget.status!.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Description / Synopsis
        if (widget.description != null && widget.description!.isNotEmpty) ...[
          Text(
            isRu ? 'Описание' : 'Synopsis',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            widget.description!,
            maxLines: _descriptionExpanded ? null : 3,
            overflow: _descriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          if (widget.description!.length > 150)
            GestureDetector(
              onTap: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _descriptionExpanded
                      ? (isRu ? 'Свернуть' : 'Show less')
                      : (isRu ? 'Развернуть...' : 'Read more...'),
                  style: const TextStyle(
                      color: Color(0xFFFF6740), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
