import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/onboarding/presentation/widgets/onboarding_shared_widgets.dart';
import 'package:gel_rule_app/features/providers/presentation/providers_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';

class OnboardingSourcesStep extends ConsumerWidget {
  const OnboardingSourcesStep({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  IconData _getProviderIcon(String id) {
    switch (id) {
      case 'safebooru':
      case 'e926':
        return Icons.verified_user_rounded;
      case 'rule34':
      case 'realbooru':
        return Icons.explicit_rounded;
      case 'e621':
        return Icons.pets_rounded;
      case 'danbooru':
      case 'gelbooru':
        return Icons.auto_awesome_rounded;
      case 'pixiv':
        return Icons.palette_rounded;
      case 'mangadex':
        return Icons.menu_book_rounded;
      default:
        return Icons.collections_rounded;
    }
  }

  Color _getProviderColor(String id, ThemeData theme) {
    switch (id) {
      case 'safebooru':
      case 'e926':
        return const Color(0xFF10B981);
      case 'rule34':
      case 'realbooru':
        return const Color(0xFFEF4444);
      case 'danbooru':
        return const Color(0xFF3B82F6);
      case 'gelbooru':
        return const Color(0xFF0EA5E9);
      case 'e621':
        return const Color(0xFFF59E0B);
      case 'pixiv':
        return const Color(0xFF6366F1);
      case 'mangadex':
        return const Color(0xFFEC4899);
      default:
        return theme.colorScheme.primary;
    }
  }

  Widget _buildProviderBadge(String id, bool isRu) {
    if (id == 'safebooru' || id == 'e926') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'SAFE',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    }
    if (id == 'rule34' || id == 'realbooru') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '18+',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';
    final providersAsync = ref.watch(providersControllerProvider);
    final allProviders = providersAsync.value ?? [];
    final providers = allProviders
        .where((p) => p.apiType != 'fapello' && p.id != 'fapello')
        .toList();
    final activeCount = providers.where((p) => p.enabled).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          const PulsingIconBadge(
            icon: Icons.hub_rounded,
            gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            size: 46,
          ),
          const SizedBox(height: 18),
          Text(
            isRu ? 'Источники и безопасность' : 'Sources & Safety',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isRu
                ? 'Настройте фильтрацию контента и выберите активные базы артов'
                : 'Configure content filtering and choose active booru sources',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Content Safety Group
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 20,
                          color: settings.nsfwEnabled
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isRu ? 'Фильтрация контента' : 'Content Filtering',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (settings.nsfwEnabled
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            settings.nsfwEnabled
                                ? (isRu ? '18+ РАЗРЕШЁН' : 'NSFW ALLOWED')
                                : (isRu ? 'SAFE MODE ВКЛ' : 'SAFE MODE ON'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: settings.nsfwEnabled
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.explicit_rounded,
                        size: 20,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    title: Text(
                      isRu
                          ? 'Разрешить 18+ (NSFW контент)'
                          : 'Allow 18+ (NSFW content)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isRu
                          ? 'Отображать арты с рейтингами Questionable и Explicit'
                          : 'Display posts with Questionable and Explicit ratings',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: settings.nsfwEnabled,
                    onChanged: (val) async {
                      unawaited(HapticFeedback.selectionClick());
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .saveSettings(settings.copyWith(nsfwEnabled: val));
                      if (!val) {
                        final currentProviders =
                            ref.read(providersControllerProvider).value ?? [];
                        for (final p in currentProviders) {
                          if ((p.id == 'rule34' || p.id == 'realbooru') &&
                              p.enabled) {
                            await ref
                                .read(providersControllerProvider.notifier)
                                .toggle(p.id, false);
                          }
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.blur_on_rounded,
                        size: 20,
                        color: Color(0xFFEC4899),
                      ),
                    ),
                    title: Text(
                      isRu
                          ? 'Размывать NSFW превью в ленте'
                          : 'Blur sensitive thumbnails',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      isRu
                          ? 'Скрывать откровенные посты под мягким блюром'
                          : 'Keep explicit media blurred until tapped',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: settings.blurExplicitContent,
                    onChanged: (val) {
                      unawaited(HapticFeedback.selectionClick());
                      ref
                          .read(settingsControllerProvider.notifier)
                          .saveSettings(
                              settings.copyWith(blurExplicitContent: val));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Preinstalled Sources Header & Actions
          Row(
            children: [
              Icon(
                Icons.hub_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isRu ? 'Источники' : 'Sources',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount/${providers.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  unawaited(HapticFeedback.selectionClick());
                  final currentProviders =
                      ref.read(providersControllerProvider).value ?? [];
                  for (final p in currentProviders) {
                    final shouldEnable = settings.nsfwEnabled ||
                        (p.id != 'rule34' && p.id != 'realbooru');
                    if (p.enabled != shouldEnable) {
                      await ref
                          .read(providersControllerProvider.notifier)
                          .toggle(p.id, shouldEnable);
                    }
                  }
                },
                child: Text(
                  isRu ? 'Все' : 'All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  unawaited(HapticFeedback.selectionClick());
                  final currentProviders =
                      ref.read(providersControllerProvider).value ?? [];
                  for (final p in currentProviders) {
                    final isSafe = p.id == 'safebooru' ||
                        p.id == 'e926' ||
                        p.id == 'danbooru' ||
                        p.id == 'pixiv';
                    if (p.enabled != isSafe) {
                      await ref
                          .read(providersControllerProvider.notifier)
                          .toggle(p.id, isSafe);
                    }
                  }
                },
                child: const Text(
                  'Safe',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List of Sources
          if (providers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            for (final config in providers) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: config.enabled
                      ? theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: config.enabled
                        ? theme.colorScheme.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: config.enabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _getProviderColor(config.id, theme)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _getProviderIcon(config.id),
                          size: 20,
                          color: _getProviderColor(config.id, theme),
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            config.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildProviderBadge(config.id, isRu),
                      ],
                    ),
                    subtitle: Text(
                      config.baseUrl
                          .replaceAll('https://', '')
                          .replaceAll('http://', ''),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (val) {
                      if (val == null) return;
                      HapticFeedback.selectionClick();
                      ref
                          .read(providersControllerProvider.notifier)
                          .toggle(config.id, val);
                    },
                  ),
                ),
              ),
            ],

          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              isRu ? 'Настроить API ключи' : 'Configure API Keys',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
