import 'package:flutter/material.dart';
import 'package:prisma_app/backend/backend.dart';

class TagSuggestionDropdown extends StatelessWidget {
  const TagSuggestionDropdown({
    super.key,
    required this.suggestions,
    required this.query,
    required this.onSelected,
  });

  final List<TagSuggestion> suggestions;
  final String query;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxDropdownHeight = (screenH * 0.55).clamp(180.0, 420.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 820, maxHeight: maxDropdownHeight),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: suggestions.length > 8 ? 8 : suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 52,
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return InkWell(
              onTap: () => onSelected(suggestion.name),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.tag_rounded,
                      color: _categoryAccentColor(suggestion.category, scheme),
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildHighlightedText(
                        context,
                        suggestion.name,
                        query,
                      ),
                    ),
                    const SizedBox(width: 10),
                    TagSuggestionBadge(
                      category: suggestion.category,
                      label: suggestion.categoryLabel,
                    ),
                    if (suggestion.postCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        _compactCount(suggestion.postCount),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String token,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final defaultStyle = theme.textTheme.bodyLarge ?? const TextStyle();

    final cleanToken = token.trim().toLowerCase();
    if (cleanToken.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: defaultStyle,
      );
    }

    final lowerText = text.toLowerCase();
    final matchIndex = lowerText.indexOf(cleanToken);

    if (matchIndex < 0) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: defaultStyle,
      );
    }

    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + cleanToken.length);
    final after = text.substring(matchIndex + cleanToken.length);

    return Text.rich(
      TextSpan(
        style: defaultStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: match,
            style: defaultStyle.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _categoryAccentColor(TagCategory category, ColorScheme scheme) {
    return switch (category) {
      TagCategory.artist => const Color(0xFFFF5252),
      TagCategory.character => const Color(0xFF66BB6A),
      TagCategory.copyright => const Color(0xFFBA68C8),
      TagCategory.species => const Color(0xFF4FC3F7),
      TagCategory.meta => const Color(0xFF90A4AE),
      TagCategory.general || TagCategory.unknown => scheme.primary,
    };
  }

  String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class TagSuggestionBadge extends StatelessWidget {
  const TagSuggestionBadge({
    super.key,
    required this.category,
    required this.label,
  });

  final TagCategory category;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bgColor, fgColor) = _badgeColors(scheme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  (Color, Color) _badgeColors(ColorScheme scheme) {
    return switch (category) {
      TagCategory.artist => (
          const Color(0xFFFF5252).withValues(alpha: 0.16),
          const Color(0xFFFF5252),
        ),
      TagCategory.character => (
          const Color(0xFF4CAF50).withValues(alpha: 0.16),
          const Color(0xFF43A047),
        ),
      TagCategory.copyright => (
          const Color(0xFFAB47BC).withValues(alpha: 0.16),
          const Color(0xFFAB47BC),
        ),
      TagCategory.species => (
          const Color(0xFF29B6F6).withValues(alpha: 0.16),
          const Color(0xFF0288D1),
        ),
      TagCategory.meta => (
          const Color(0xFF78909C).withValues(alpha: 0.16),
          const Color(0xFF607D8B),
        ),
      TagCategory.general || TagCategory.unknown => (
          scheme.primaryContainer.withValues(alpha: 0.55),
          scheme.onPrimaryContainer,
        ),
    };
  }
}


