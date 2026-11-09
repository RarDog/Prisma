import 'package:flutter/material.dart';

import 'package:gel_rule_app/core/models/post.dart';

/// Wraps [child] with layered cards effect to visually indicate multi-page posts.
class MultiPageStackContainer extends StatelessWidget {
  const MultiPageStackContainer({
    required this.post,
    required this.child,
    super.key,
  });

  final Post post;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!post.isMultiPage) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor =
        isDark ? const Color(0xFF1E2024) : const Color(0xFFF1F3F5);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);
    final count = post.pageCount;
    final showThirdSheet = count >= 3;

    return Padding(
      padding: EdgeInsets.only(
        top: showThirdSheet ? 5.0 : 3.5,
        right: showThirdSheet ? 5.0 : 3.5,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Third sheet (bottom-most, visible if 3+ pages)
          if (showThirdSheet)
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(5.0, -5.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.7),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 4,
                        offset: const Offset(1, -1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Second sheet (middle, visible if 2+ pages)
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(2.5, -2.5),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 5,
                      offset: const Offset(1, -1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Foreground card
          child,
        ],
      ),
    );
  }
}
