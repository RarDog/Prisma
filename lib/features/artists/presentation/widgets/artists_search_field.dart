import 'package:flutter/material.dart';

/// Frosted-glass artist search field with a clear button and a submit pill.
class ArtistsSearchField extends StatelessWidget {
  const ArtistsSearchField({
    super.key,
    required this.searchController,
    required this.onSearch,
    required this.isRu,
  });

  final TextEditingController searchController;
  final VoidCallback onSearch;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: isRu ? 'Поиск авторов...' : 'Search artists...',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : const Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.cancel_rounded, size: 18),
                color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: isRu ? 'Очистить' : 'Clear',
                onPressed: () {
                  searchController.clear();
                  onSearch();
                },
              );
            },
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onSearch,
              child: Container(
                margin: const EdgeInsets.only(right: 5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRu ? 'Найти' : 'Search',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color:
                          isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
