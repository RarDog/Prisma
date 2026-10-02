import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/artists/presentation/widgets/pawchive_accounts_sheet.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class AccountsSettingsScreen extends ConsumerWidget {
  const AccountsSettingsScreen({super.key});

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
              // Pawchive Accounts Section
              SettingsCardGroup(
                title: isRu ? 'Pawchive (Авторы и художники)' : 'Pawchive Creators',
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

              // Booru Accounts & Providers
              SettingsCardGroup(
                title: isRu ? 'Аккаунты источников (Booru)' : 'Booru Provider Accounts',
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
                        ? 'Настройка API-ключей, логинов для e621, Danbooru, Gelbooru'
                        : 'Configure API keys, logins for e621, Danbooru, Gelbooru',
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.go('/providers'),
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
