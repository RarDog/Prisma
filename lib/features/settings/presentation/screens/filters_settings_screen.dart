import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class FiltersSettingsScreen extends ConsumerWidget {
  const FiltersSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, AppSettings settings) {
    return ref.read(settingsControllerProvider.notifier).saveSettings(settings);
  }

  Future<void> _syncE621Blacklist(BuildContext context, WidgetRef ref, AppSettings settings) async {
    final isRu = settings.languageCode == 'ru';
    HapticFeedback.mediumImpact();

    try {
      final providerInstance = await ref
          .read(providerManagerProvider)
          .getProviderInstance('e621');
      if (providerInstance is! E621Provider) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRu ? 'Провайдер e621 не найден' : 'e621 provider not found',
              ),
            ),
          );
        }
        return;
      }

      final login = providerInstance.login?.trim();
      if (login == null || login.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRu
                    ? 'Укажите логин e621 в настройках источников'
                    : 'Configure e621 login in provider settings first',
              ),
            ),
          );
        }
        return;
      }

      final tags = await providerInstance.fetchAccountBlacklist();
      if (!context.mounted) return;
      if (tags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'В аккаунте e621 нет заблокированных тегов'
                  : 'No blacklisted tags found on e621 account',
            ),
          ),
        );
        return;
      }

      final res = await ref
          .read(settingsServiceProvider)
          .importBlacklistFromE621(tags);
      ref.invalidate(settingsControllerProvider);
      ref.invalidate(appSettingsProvider);

      if (context.mounted) {
        res.fold(
          onSuccess: (count) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  count > 0
                      ? (isRu
                          ? 'Синхронизировано $count новых тегов/правил из e621!'
                          : 'Imported $count new rules/tags from e621!')
                      : (isRu
                          ? 'Черный список уже синхронизирован (нет новых тегов)'
                          : 'Blacklist already up to date'),
                ),
              ),
            );
          },
          onError: (fail) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${isRu ? "Ошибка" : "Error"}: ${fail.message}'),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${isRu ? "Ошибка синхронизации" : "Sync error"}: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = AppStrings(settings.languageCode);
    final isRu = strings.ru;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SettingsIconBadge(
              icon: Icons.filter_alt_rounded,
              color: Color(0xFFF59E0B),
              size: 30,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Text(
              strings.filters,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              120 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              // Content Rating & NSFW Toggles
              SettingsCardGroup(
                title: isRu ? 'Рейтинги и цензура' : 'Content Ratings',
                icon: Icons.shield_rounded,
                accentColor: const Color(0xFFEF4444),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.explicit_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: strings.allowNsfw,
                    subtitle: isRu
                        ? 'Отображать контент с рейтингом Questionable и Explicit'
                        : 'Show Questionable and Explicit rated media',
                    value: settings.nsfwEnabled,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(nsfwEnabled: val)),
                  ),
                  const SettingsDivider(),
                  SettingsSwitchTile(
                    icon: Icons.blur_on_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: strings.blurSensitive,
                    subtitle: isRu
                        ? 'Мягко размывать превью откровенных постов в ленте'
                        : 'Blur sensitive thumbnails in feed grid',
                    value: settings.blurExplicitContent,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(blurExplicitContent: val)),
                  ),
                ],
              ),

              // Smart Blacklist
              SettingsCardGroup(
                title: strings.smartBlacklist,
                icon: Icons.block_rounded,
                accentColor: const Color(0xFFEF4444),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: TagListEditor(
                      title: strings.smartBlacklist,
                      icon: Icons.block_rounded,
                      accentColor: const Color(0xFFEF4444),
                      tags: settings.smartBlacklistRules,
                      helper: isRu
                          ? 'Примеры: tag, tag_a tag_b, provider:e621, rating:explicit, type:video, score:<10, artist:name'
                          : 'Examples: tag, tag_a tag_b, provider:e621, rating:explicit, type:video, score:<10, artist:name',
                      onChanged: (tags) => _update(
                        ref,
                        settings.copyWith(smartBlacklistRules: tags),
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsTile(
                    icon: Icons.sync_rounded,
                    iconColor: const Color(0xFF0055AA),
                    title: isRu
                        ? 'Синхронизация черного списка e621'
                        : 'Sync e621 Blacklist',
                    subtitle: isRu
                        ? 'Загрузить заблокированные теги из аккаунта e621'
                        : 'Import blacklisted tags from e621 account',
                    trailing: const Icon(Icons.download_rounded, size: 20),
                    onTap: () => _syncE621Blacklist(context, ref, settings),
                  ),
                ],
              ),

              // Whitelist
              SettingsCardGroup(
                title: strings.whitelistedTags,
                icon: Icons.verified_rounded,
                accentColor: const Color(0xFF10B981),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: TagListEditor(
                      title: strings.whitelistedTags,
                      icon: Icons.verified_rounded,
                      accentColor: const Color(0xFF10B981),
                      tags: settings.whitelistedTags,
                      helper: isRu
                          ? 'Теги, которые никогда не будут скрываться черным списком'
                          : 'Tags that will bypass blacklist rules',
                      onChanged: (tags) => _update(
                        ref,
                        settings.copyWith(whitelistedTags: tags),
                      ),
                    ),
                  ),
                ],
              ),

              // Hidden Posts Management
              SettingsCardGroup(
                title: isRu ? 'Скрытые посты' : 'Hidden Posts',
                icon: Icons.visibility_off_rounded,
                accentColor: const Color(0xFF6366F1),
                children: [
                  SettingsTile(
                    icon: Icons.restore_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: isRu ? 'Управление скрытыми постами' : 'Manage hidden posts',
                    subtitle: isRu
                        ? 'Скрыто вручную: ${settings.hiddenPostKeys.length} постов'
                        : 'Manually hidden: ${settings.hiddenPostKeys.length} posts',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.go('/settings/hidden'),
                  ),
                  if (settings.hiddenPostKeys.isNotEmpty) ...[
                    const SettingsDivider(),
                    SettingsTile(
                      icon: Icons.delete_sweep_rounded,
                      iconColor: const Color(0xFFEF4444),
                      title: isRu ? 'Очистить скрытые посты' : 'Clear hidden posts',
                      subtitle: isRu
                          ? 'Сбросить весь список вручную скрытых постов'
                          : 'Un-hide all manually hidden posts',
                      onTap: () async {
                        await ref
                            .read(settingsControllerProvider.notifier)
                            .clearHiddenPosts();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isRu
                                    ? 'Список скрытых постов очищен'
                                    : 'Hidden posts cleared',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
