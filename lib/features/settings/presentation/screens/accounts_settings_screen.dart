import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/pawchive_accounts_sheet.dart';
import 'package:gel_rule_app/features/providers/presentation/providers_controller.dart';
import 'package:gel_rule_app/features/providers/presentation/providers_screen.dart';
import 'package:gel_rule_app/features/providers/presentation/widgets/e621_auth_dialog.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';

class AccountsSettingsScreen extends ConsumerWidget {
  const AccountsSettingsScreen({super.key});

  Future<void> _syncE621Blacklist(
    BuildContext context,
    WidgetRef ref,
    bool isRu,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      final providerInstance =
          await ref.read(providerManagerProvider).getProviderInstance('e621');
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
                    ? 'Сначала выполните вход в e621'
                    : 'Log in to e621 first',
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

      final res =
          await ref.read(settingsServiceProvider).importBlacklistFromE621(tags);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isRu ? "Ошибка" : "Error"}: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = ref.watch(appStringsProvider);
    final isRu = strings.ru;

    final providersState = ref.watch(providersControllerProvider);
    final providers = providersState.value ?? [];

    final e621Config = providers
        .where((p) => p.id.toLowerCase() == 'e621')
        .firstOrNull;
    final e926Config = providers
        .where((p) => p.id.toLowerCase() == 'e926')
        .firstOrNull;

    final effectiveE621 = e621Config ??
        ContentProviderConfig(
          id: 'e621',
          name: 'e621',
          baseUrl: 'https://e621.net',
          apiType: 'e621',
          enabled: true,
          priority: 5,
          timeoutSeconds: 20,
          customHeaders: {
            'User-Agent': AppHeaders.defaultUserAgent,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final effectiveE926 = e926Config ??
        ContentProviderConfig(
          id: 'e926',
          name: 'e926',
          baseUrl: 'https://e926.net',
          apiType: 'e621',
          enabled: true,
          priority: 6,
          timeoutSeconds: 20,
          customHeaders: {
            'User-Agent': AppHeaders.defaultUserAgent,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final e621Login = effectiveE621.customHeaders['query.login']?.trim() ?? '';
    final e621ApiKey =
        effectiveE621.customHeaders['query.api_key']?.trim() ?? '';
    final e621HasAuth = e621Login.isNotEmpty && e621ApiKey.isNotEmpty;

    final e926Login = effectiveE926.customHeaders['query.login']?.trim() ?? '';
    final e926ApiKey =
        effectiveE926.customHeaders['query.api_key']?.trim() ?? '';
    final e926HasAuth = e926Login.isNotEmpty && e926ApiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SettingsIconBadge(
              icon: Icons.cloud_sync_rounded,
              color: Color(0xFF0EA5E9),
              size: 30,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Text(
              isRu ? 'Аккаунты и синхронизация' : 'Accounts & Sync',
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
              // 1. Pawchive Accounts Section
              SettingsCardGroup(
                title: isRu
                    ? 'Pawchive (Авторы и художники)'
                    : 'Pawchive Creators',
                icon: Icons.person_search_rounded,
                accentColor: const Color(0xFF0EA5E9),
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.cloud_sync_rounded),
                    ),
                    title: Text(
                      isRu ? 'Аккаунты Pawchive' : 'Pawchive Accounts',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      settings.parsedPawchiveAccounts.isEmpty
                          ? (isRu
                              ? 'Вход для синхронизации подписок на авторов'
                              : 'Sign in to sync followed creator feeds')
                          : '${settings.parsedPawchiveAccounts.length} ${isRu ? "аккаунт(ов)" : "account(s)"}'
                              '${settings.activePawchiveAccount != null ? " • @${settings.activePawchiveAccount!.username}" : ""}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => PawchiveAccountsSheet.show(context),
                      child: Text(settings.parsedPawchiveAccounts.isEmpty
                          ? (isRu ? 'Войти' : 'Login')
                          : (isRu ? 'Управление' : 'Manage')),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. e621 & e926 Accounts & Synchronization
              SettingsCardGroup(
                title: isRu ? 'e621 и e926 (Furry Booru)' : 'e621 & e926 Furry Booru',
                icon: Icons.pets_rounded,
                accentColor: const Color(0xFF0055AA),
                children: [
                  // e621 Tile
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF0055AA),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.pets_rounded, size: 20),
                    ),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'e621',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: e621HasAuth
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: e621HasAuth
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            e621HasAuth
                                ? (isRu ? 'В сети' : 'Authorized')
                                : (isRu ? 'Гость' : 'Guest'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: e621HasAuth
                                  ? const Color(0xFF10B981)
                                  : Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      e621HasAuth
                          ? (isRu
                              ? 'Аккаунт: @$e621Login • Неограниченный поиск'
                              : 'Account: @$e621Login • Unrestricted tags')
                          : (isRu
                              ? 'Гостевой режим (лимит: 2 тега при поиске)'
                              : 'Guest mode (2 tags query limit)'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            E621AuthDialog.show(
                              context,
                              config: effectiveE621,
                              onSaved: (cfg) => ref
                                  .read(providersControllerProvider.notifier)
                                  .save(cfg),
                            );
                          },
                          child: Text(e621HasAuth
                              ? (isRu ? 'Аккаунт' : 'Account')
                              : (isRu ? 'Войти' : 'Login')),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: effectiveE621.enabled,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            ref
                                .read(providersControllerProvider.notifier)
                                .toggle(effectiveE621.id, val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SettingsDivider(),

                  // e926 Tile
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE5A823),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.shield_rounded, size: 20),
                    ),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'e926',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'SFW',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: e926HasAuth
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: e926HasAuth
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            e926HasAuth
                                ? (isRu ? 'В сети' : 'Authorized')
                                : (isRu ? 'Гость' : 'Guest'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: e926HasAuth
                                  ? const Color(0xFF10B981)
                                  : Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      e926HasAuth
                          ? (isRu
                              ? 'Аккаунт: @$e926Login • Безопасная версия (SFW)'
                              : 'Account: @$e926Login • Safe edition (SFW)')
                          : (isRu
                              ? 'Безопасная версия e621 (SFW) • Гостевой режим'
                              : 'Safe e621 edition (SFW) • Guest mode'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            E621AuthDialog.show(
                              context,
                              config: effectiveE926,
                              onSaved: (cfg) => ref
                                  .read(providersControllerProvider.notifier)
                                  .save(cfg),
                            );
                          },
                          child: Text(e926HasAuth
                              ? (isRu ? 'Аккаунт' : 'Account')
                              : (isRu ? 'Войти' : 'Login')),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: effectiveE926.enabled,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            ref
                                .read(providersControllerProvider.notifier)
                                .toggle(effectiveE926.id, val);
                          },
                        ),
                      ],
                    ),
                  ),

                  if (e621HasAuth && !e926HasAuth) ...[
                    const SettingsDivider(),
                    SettingsTile(
                      icon: Icons.copy_rounded,
                      iconColor: const Color(0xFF0055AA),
                      title: isRu
                          ? 'Использовать аккаунт e621 для e926'
                          : 'Use e621 credentials for e926',
                      subtitle: isRu
                          ? 'Скопировать логин @$e621Login и API-ключ в e926'
                          : 'Copy login @$e621Login and API key to e926',
                      trailing:
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                      onTap: () async {
                        unawaited(HapticFeedback.lightImpact());
                        final headers =
                            Map<String, String>.from(effectiveE926.customHeaders)
                              ..['query.login'] = e621Login
                              ..['query.api_key'] = e621ApiKey;
                        await ref
                            .read(providersControllerProvider.notifier)
                            .save(
                              effectiveE926.copyWith(
                                customHeaders: headers,
                                updatedAt: DateTime.now(),
                              ),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isRu
                                    ? 'Аккаунт e621 успешно применен к e926!'
                                    : 'e621 credentials applied to e926!',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],

                  if (e621HasAuth) ...[
                    const SettingsDivider(),
                    SettingsTile(
                      icon: Icons.sync_rounded,
                      iconColor: const Color(0xFF0055AA),
                      title: isRu
                          ? 'Синхронизация черного списка e621'
                          : 'Sync e621 Blacklist',
                      subtitle: isRu
                          ? 'Импортировать правила блокировок из аккаунта e621'
                          : 'Import blacklisted tags from e621 account',
                      trailing: const Icon(Icons.download_rounded, size: 20),
                      onTap: () => unawaited(_syncE621Blacklist(context, ref, isRu)),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // 3. Booru Accounts & Providers
              SettingsCardGroup(
                title: isRu
                    ? 'Остальные источники (Booru)'
                    : 'Other Booru Providers',
                icon: Icons.hub_rounded,
                accentColor: const Color(0xFF6366F1),
                children: [
                  SettingsTile(
                    icon: Icons.hub_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: isRu
                        ? 'Управление источниками и авторизацией'
                        : 'Manage Booru Providers & API Keys',
                    subtitle: isRu
                        ? 'Настройка API-ключей, логинов для Danbooru, Gelbooru, TBIB и др.'
                        : 'Configure API keys, logins for Danbooru, Gelbooru, TBIB and others',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProvidersScreen(),
                      ),
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
