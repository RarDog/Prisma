import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PostActionBar extends StatelessWidget {
  const PostActionBar({
    required this.onFavorite,
    required this.onCollection,
    required this.onOpen,
    required this.onCopy,
    required this.isFavorite,
    this.onOpenSource,
    this.onDownload,
    this.onSaveAs,
    this.onDeleteLocalFile,
    this.onShare,
    this.downloaded = false,
    this.isDownloading = false,
    this.labels,
    this.onSimilar,
    this.onHide,
    super.key,
  });

  final VoidCallback onFavorite;
  final VoidCallback onCollection;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onOpenSource;
  final bool isFavorite;
  final VoidCallback? onDownload;
  final VoidCallback? onSaveAs;
  final VoidCallback? onDeleteLocalFile;
  final VoidCallback? onShare;
  final VoidCallback? onSimilar;
  final VoidCallback? onHide;
  final bool downloaded;
  final bool isDownloading;
  final PostActionLabels? labels;

  void _showMoreActions(BuildContext context, PostActionLabels text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark ? const Color(0xF2181A22) : scheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation & Links Group
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    // Copy Link
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.copy_rounded,
                            size: 20, color: scheme.primary),
                      ),
                      title: Text(
                        text.copyLink,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(sheetContext);
                        onCopy();
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    // Open Original in Browser
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scheme.tertiary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.open_in_new_rounded,
                            size: 20, color: scheme.tertiary),
                      ),
                      title: Text(
                        text.openOriginal,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(sheetContext);
                        onOpen();
                      },
                    ),
                    // Open Source Page (if available)
                    if (onOpenSource != null) ...[
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.article_rounded,
                              size: 20, color: scheme.secondary),
                        ),
                        title: Text(
                          text.openSource,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetContext);
                          onOpenSource!();
                        },
                      ),
                    ],
                    // Find Similar
                    if (onSimilar != null) ...[
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                      ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(20)),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 20,
                            color: Color(0xFFA78BFA),
                          ),
                        ),
                        title: Text(
                          text.similar,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetContext);
                          onSimilar!();
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Storage & Management Group
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    // Save As (Desktop / Custom Directory)
                    if (onSaveAs != null) ...[
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(20),
                            bottom: (downloaded && onDeleteLocalFile != null) ||
                                    onHide != null
                                ? Radius.zero
                                : const Radius.circular(20),
                          ),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.save_as_rounded, size: 20),
                        ),
                        title: Text(
                          text.saveAs,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetContext);
                          onSaveAs!();
                        },
                      ),
                      if ((downloaded && onDeleteLocalFile != null) ||
                          onHide != null)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                    ],
                    // Delete Local File (if downloaded)
                    if (downloaded && onDeleteLocalFile != null) ...[
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        title: Text(
                          text.deleteLocalFile,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(sheetContext);
                          onDeleteLocalFile!();
                        },
                      ),
                      if (onHide != null)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                    ],
                    // Hide Post Locally
                    if (onHide != null)
                      ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(20)),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.visibility_off_rounded,
                            size: 20,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        title: Text(
                          text.hidePost,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetContext);
                          onHide!();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final text = labels ?? const PostActionLabels();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xD91A1D24)
                : scheme.surfaceContainerLow.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Favorite / Like Button (Capsule with animated bounce and glow)
              Expanded(
                flex: 3,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onFavorite();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: isFavorite
                            ? const LinearGradient(
                                colors: [
                                  Color(0x38FF3B30),
                                  Color(0x22FF1744),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isFavorite
                            ? null
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : scheme.secondaryContainer
                                    .withValues(alpha: 0.45)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFavorite
                              ? const Color(0x66FF3B30)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : scheme.outlineVariant
                                      .withValues(alpha: 0.2)),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isFavorite ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.elasticOut,
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: isFavorite
                                  ? const Color(0xFFFF3B30)
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isFavorite ? text.unfavorite : text.favorite,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isFavorite
                                    ? const Color(0xFFFF453A)
                                    : scheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Download Button with Live State & Haptics
              if (onDownload != null) ...[
                _ActionButton(
                  tooltip: downloaded ? text.downloaded : text.download,
                  backgroundColor: downloaded
                      ? const Color(0x2810B981)
                      : (isDownloading
                          ? scheme.primary.withValues(alpha: 0.15)
                          : null),
                  borderColor: downloaded
                      ? const Color(0x5510B981)
                      : (isDownloading
                          ? scheme.primary.withValues(alpha: 0.4)
                          : null),
                  icon: isDownloading
                      ? SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(
                          downloaded
                              ? Icons.offline_pin_rounded
                              : Icons.download_rounded,
                          color: downloaded
                              ? const Color(0xFF10B981)
                              : scheme.onSurface,
                          size: 21,
                        ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDownload!();
                  },
                  onLongPress: onSaveAs != null
                      ? () {
                          HapticFeedback.selectionClick();
                          onSaveAs!();
                        }
                      : null,
                ),
                const SizedBox(width: 6),
              ],

              // Add to Collection
              _ActionButton(
                tooltip: text.collection,
                icon: Icon(
                  Icons.bookmark_add_rounded,
                  size: 21,
                  color: scheme.onSurface,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCollection();
                },
              ),
              const SizedBox(width: 6),

              // Share
              if (onShare != null) ...[
                _ActionButton(
                  tooltip: text.share,
                  icon: Icon(
                    Icons.share_rounded,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onShare!();
                  },
                ),
                const SizedBox(width: 6),
              ],

              // More Options
              _ActionButton(
                tooltip: text.more,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 22,
                  color: scheme.onSurface,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showMoreActions(context, text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.borderColor,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : scheme.secondaryContainer.withValues(alpha: 0.40);
    final defaultBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant.withValues(alpha: 0.20);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor ?? defaultBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor ?? defaultBorder,
                width: 1.1,
              ),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class PostActionLabels {
  const PostActionLabels({
    this.favorite = 'Favorite',
    this.unfavorite = 'Saved',
    this.collection = 'Collection',
    this.similar = 'Similar',
    this.openOriginal = 'Open original',
    this.openSource = 'Open source/page',
    this.saveAs = 'Save as...',
    this.copyLink = 'Copy link',
    this.download = 'Download',
    this.downloaded = 'Downloaded',
    this.deleteLocalFile = 'Delete local file',
    this.hidePost = 'Hide post locally',
    this.share = 'Share',
    this.more = 'More',
  });

  final String favorite;
  final String unfavorite;
  final String collection;
  final String similar;
  final String openOriginal;
  final String openSource;
  final String saveAs;
  final String copyLink;
  final String download;
  final String downloaded;
  final String deleteLocalFile;
  final String hidePost;
  final String share;
  final String more;
}
