import 'package:flutter/material.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/app/changelog.dart';

Future<void> showPrismaChangelogDialog({
  required BuildContext context,
  bool? isRu,
}) {
  final ru = isRu ?? (Localizations.maybeLocaleOf(context)?.languageCode == 'ru');
  return showDialog<void>(
    context: context,
    builder: (context) => PrismaChangelogDialog(isRu: ru),
  );
}

class PrismaChangelogDialog extends StatelessWidget {
  const PrismaChangelogDialog({
    this.isRu = true,
    this.changelog = prismaChangelog,
    super.key,
  });

  final bool isRu;
  final List<PrismaChange> changelog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.primary,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                          scheme.secondary.withValues(alpha: isDark ? 0.35 : 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/app_icon_rounded.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.auto_awesome_rounded,
                        size: 26,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu ? 'История изменений' : 'Version History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v$appDisplayVersion',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isRu ? '• Текущая версия' : '• Current version',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: isRu ? 'Закрыть' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),

              // Scrollable Timeline
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(right: 4, bottom: 8),
                  itemCount: changelog.length,
                  itemBuilder: (context, index) {
                    final item = changelog[index];
                    final isFirst = index == 0;
                    final isLast = index == changelog.length - 1;
                    final isCurrent = item.version == appDisplayVersion;
                    return _TimelineItem(
                      change: item,
                      isRu: isRu,
                      isFirst: isFirst,
                      isLast: isLast,
                      isCurrent: isCurrent,
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      isRu ? 'Закрыть' : 'Close',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.change,
    required this.isRu,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
  });

  final PrismaChange change;
  final bool isRu;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;

  bool get _isBeta =>
      change.version.toLowerCase().contains('beta') ||
      change.version.toLowerCase().contains('alpha');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left timeline node & line
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 14),
                // Timeline node indicator
                Container(
                  width: isCurrent ? 14 : 10,
                  height: isCurrent ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.7),
                    border: Border.all(
                      color: isCurrent
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.surface,
                      width: isCurrent ? 3 : 1.5,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.45),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                // Line below
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right card container
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isCurrent
                      ? scheme.primaryContainer.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        )
                      : (isDark
                          ? const Color(0xFF161616)
                          : scheme.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCurrent
                        ? scheme.primary.withValues(alpha: isDark ? 0.4 : 0.25)
                        : scheme.outlineVariant.withValues(
                            alpha: isDark ? 0.25 : 0.4,
                          ),
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Version badges row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.onSurfaceVariant.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            change.version,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 11,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isRu ? 'Текущая' : 'Current',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: _isBeta
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isBeta ? 'Beta' : 'Release',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isBeta
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      change.localizedTitle(isRu),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bullets list
                    for (final bullet in change.localizedBullets(isRu)) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 8),
                              child: _BulletIcon(bulletText: bullet),
                            ),
                            Expanded(
                              child: Text(
                                bullet,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.88),
                                  height: 1.35,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _BulletIcon extends StatelessWidget {
  const _BulletIcon({required this.bulletText});

  final String bulletText;

  @override
  Widget build(BuildContext context) {
    final lower = bulletText.toLowerCase();

    // Fixes / bug patches
    if (lower.contains('исправл') ||
        lower.contains('фикс') ||
        lower.contains('fix') ||
        lower.contains('ошибк') ||
        lower.contains('сбо')) {
      return const Icon(
        Icons.build_circle_rounded,
        size: 14,
        color: Color(0xFFF59E0B), // Amber
      );
    }

    // New features / capabilities
    if (lower.contains('нов') ||
        lower.contains('добавлен') ||
        lower.contains('интеграц') ||
        lower.contains('поддержк') ||
        lower.contains('плеер') ||
        lower.contains('new') ||
        lower.contains('add') ||
        lower.contains('support')) {
      return const Icon(
        Icons.rocket_launch_rounded,
        size: 14,
        color: Color(0xFF10B981), // Emerald
      );
    }

    // Optimizations / Speed / Performance
    if (lower.contains('оптимиз') ||
        lower.contains('ускорен') ||
        lower.contains('предзагрузк') ||
        lower.contains('буфериз') ||
        lower.contains('производит') ||
        lower.contains('speed') ||
        lower.contains('perf') ||
        lower.contains('fast')) {
      return const Icon(
        Icons.bolt_rounded,
        size: 14,
        color: Color(0xFF0EA5E9), // Cyan / Light Blue
      );
    }

    // Default bullet icon
    return Icon(
      Icons.check_circle_outline_rounded,
      size: 14,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
    );
  }
}
