import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/features/settings/presentation/settings_controller.dart';
import 'pawchive_account_card.dart';
import 'pawchive_add_account_card.dart';
import 'pawchive_bidirectional_sync_panel.dart';

class PawchiveAccountsSheet extends ConsumerStatefulWidget {
  const PawchiveAccountsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PawchiveAccountsSheet(),
    );
  }

  @override
  ConsumerState<PawchiveAccountsSheet> createState() =>
      _PawchiveAccountsSheetState();
}

class _PawchiveAccountsSheetState extends ConsumerState<PawchiveAccountsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _addTabController;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cookieController = TextEditingController();

  bool _isAdding = false;
  bool _obscurePassword = true;
  String? _syncingAccountId;
  String? _pushingAccountId;
  bool _syncingAll = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _addTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _addTabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _cookieController.dispose();
    super.dispose();
  }

  bool get _isRu =>
      mounted && (Localizations.maybeLocaleOf(context)?.languageCode == 'ru');

  /// Shared flow for both login paths: authenticate, activate the new
  /// account, run the initial favorites sync and persist the result.
  Future<void> _addAccount({
    required Future<PawchiveAccount> Function(PawchiveSyncService) login,
    required List<TextEditingController> fieldsToClear,
    required String Function(PawchiveAccount account) successMessage,
  }) async {
    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      final syncService = ref.read(pawchiveSyncServiceProvider);
      final account = await login(syncService);

      final settings =
          ref.read(appSettingsProvider).value ?? AppSettings.defaults;
      final existingAccounts = settings.parsedPawchiveAccounts
          .where((a) => a.id != account.id)
          .toList();
      // Set as active
      final updatedList = [
        account.copyWith(isActive: true),
        ...existingAccounts.map((a) => a.copyWith(isActive: false)),
      ];

      var newSettings = settings.copyWith(
        pawchiveAccounts:
            updatedList.map((a) => jsonEncode(a.toJson())).toList(),
      );

      // Perform initial sync
      final syncResult = await syncService.syncAccountFavorites(
        account: account,
        settings: newSettings,
      );
      if (syncResult.isSuccess) {
        newSettings = syncResult.updatedSettings;
      }

      await ref
          .read(settingsControllerProvider.notifier)
          .saveSettings(newSettings);

      for (final controller in fieldsToClear) {
        controller.clear();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage(account)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _handleLoginCredentials() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage =
          _isRu ? 'Введите логин и пароль' : 'Enter username and password');
      return;
    }

    await _addAccount(
      login: (syncService) => syncService.loginWithCredentials(
        username: username,
        password: password,
      ),
      fieldsToClear: [_usernameController, _passwordController],
      successMessage: (account) => _isRu
          ? 'Аккаунт @${account.username} добавлен! Синхронизировано ${account.syncedArtistsCount} авторов.'
          : 'Account @${account.username} added! Synced ${account.syncedArtistsCount} artists.',
    );
  }

  Future<void> _handleLoginCookie() async {
    final cookie = _cookieController.text.trim();
    final username = _usernameController.text.trim();
    if (cookie.isEmpty) {
      setState(() => _errorMessage =
          _isRu ? 'Введите сессионную куку' : 'Enter session cookie');
      return;
    }

    await _addAccount(
      login: (syncService) => syncService.loginWithSession(
        sessionCookie: cookie,
        username: username.isEmpty ? 'Pawchive User' : username,
      ),
      fieldsToClear: [_cookieController, _usernameController],
      successMessage: (account) => _isRu
          ? 'Кука сохранена! Синхронизировано ${account.syncedArtistsCount} авторов.'
          : 'Cookie saved! Synced ${account.syncedArtistsCount} artists.',
    );
  }

  void _showSnack(String message, {Color? background}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
      ),
    );
  }

  Future<void> _syncSingleAccount(PawchiveAccount account) async {
    setState(() => _syncingAccountId = account.id);
    try {
      final syncService = ref.read(pawchiveSyncServiceProvider);
      final settings =
          ref.read(appSettingsProvider).value ?? AppSettings.defaults;
      final result = await syncService.syncAccountFavorites(
        account: account,
        settings: settings,
      );

      if (result.isSuccess) {
        await ref
            .read(settingsControllerProvider.notifier)
            .saveSettings(result.updatedSettings);
        if (mounted) {
          final pushedMsg = result.pushedToRemoteCount > 0
              ? (_isRu
                  ? ', выгружено в Pawchive: +${result.pushedToRemoteCount}'
                  : ', pushed to Pawchive: +${result.pushedToRemoteCount}')
              : '';
          _showSnack(
            _isRu
                ? 'Синхронизировано: ${result.totalSyncedCount} авторов (+${result.newlyAddedToLocal} новых в приложении$pushedMsg)'
                : 'Synced: ${result.totalSyncedCount} artists (+${result.newlyAddedToLocal} new locally$pushedMsg)',
          );
        }
      } else {
        if (mounted) {
          _showSnack(
            '${_isRu ? "Ошибка синхронизации" : "Sync error"}: ${result.errorMessage}',
            background: Colors.red.shade700,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _syncingAccountId = null);
      }
    }
  }

  Future<void> _pushFavoritesToAccount(PawchiveAccount account) async {
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    final totalLocal = settings.favoriteArtists.length;
    if (totalLocal == 0) {
      _showSnack(
        _isRu
            ? 'В локальном избранном пока нет авторов'
            : 'No artists in local favorites yet',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isRu
              ? 'Выгрузить избранное в Pawchive?'
              : 'Push favorites to Pawchive?',
        ),
        content: Text(
          _isRu
              ? 'Все локальные авторы из приложения ($totalLocal) будут добавлены в избранное аккаунта @${account.username} на сервере Pawchive.'
              : 'All local artists from app ($totalLocal) will be added to favorites of account @${account.username} on Pawchive server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isRu ? 'Отмена' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cloud_upload_rounded),
            label: Text(_isRu ? 'Выгрузить' : 'Push'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _pushingAccountId = account.id);
    try {
      final syncService = ref.read(pawchiveSyncServiceProvider);
      final result = await syncService.pushLocalFavoritesToAccount(
        account: account,
        settings: settings,
      );

      if (result.isSuccess) {
        if (result.updatedSettings != null) {
          await ref
              .read(settingsControllerProvider.notifier)
              .saveSettings(result.updatedSettings!);
        }

        if (mounted) {
          if (result.pushedCount > 0) {
            _showSnack(
              _isRu
                  ? 'Выгружено ${result.pushedCount} авторов в @${account.username}! Всего в аккаунте: ${result.totalRemoteCount}.'
                  : 'Pushed ${result.pushedCount} artists to @${account.username}! Total in account: ${result.totalRemoteCount}.',
              background: Colors.green.shade700,
            );
          } else {
            _showSnack(
              _isRu
                  ? 'Все авторы (${result.totalLocalCandidates}) уже есть в аккаунте @${account.username}.'
                  : 'All artists (${result.totalLocalCandidates}) are already in @${account.username}.',
            );
          }
        }
      } else {
        if (mounted) {
          _showSnack(
            '${_isRu ? "Ошибка выгрузки" : "Push error"}: ${result.errorMessage}',
            background: Colors.red.shade700,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _pushingAccountId = null);
      }
    }
  }

  Future<void> _syncAllAccounts() async {
    setState(() => _syncingAll = true);
    try {
      final syncService = ref.read(pawchiveSyncServiceProvider);
      final settings =
          ref.read(appSettingsProvider).value ?? AppSettings.defaults;
      final result = await syncService.syncAllAccounts(settings: settings);

      if (result.isSuccess) {
        await ref
            .read(settingsControllerProvider.notifier)
            .saveSettings(result.updatedSettings);
        if (mounted) {
          final pushedMsg = result.pushedToRemoteCount > 0
              ? (_isRu
                  ? ', выгружено в Pawchive: +${result.pushedToRemoteCount}'
                  : ', pushed to Pawchive: +${result.pushedToRemoteCount}')
              : '';
          _showSnack(
            _isRu
                ? 'Все аккаунты синхронизированы! Всего: ${result.totalSyncedCount} (+${result.newlyAddedToLocal} новых в приложении$pushedMsg)'
                : 'All accounts synced! Total: ${result.totalSyncedCount} (+${result.newlyAddedToLocal} new locally$pushedMsg)',
            background: Colors.green.shade700,
          );
        }
      } else {
        if (mounted) {
          _showSnack(
              '${_isRu ? "Ошибка синхронизации" : "Sync error"}: ${result.errorMessage}',
              background: Colors.red.shade700,
            );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _syncingAll = false);
      }
    }
  }

  Future<void> _setActiveAccount(PawchiveAccount target) async {
    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    final updatedList = settings.parsedPawchiveAccounts.map((a) {
      return a.copyWith(isActive: a.id == target.id);
    }).toList();

    await ref.read(settingsControllerProvider.notifier).saveSettings(
          settings.copyWith(
            pawchiveAccounts:
                updatedList.map((a) => jsonEncode(a.toJson())).toList(),
          ),
        );
  }

  Future<void> _removeAccount(PawchiveAccount target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _isRu ? 'Удалить аккаунт Pawchive?' : 'Delete Pawchive account?',
        ),
        content: Text(
          _isRu
              ? 'Вы уверены, что хотите удалить аккаунт @${target.username}? Локальные авторы останутся в приложении.'
              : 'Are you sure you want to delete account @${target.username}? Local artists will remain in app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isRu ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_isRu ? 'Удалить' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final settings =
        ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    final filtered = settings.parsedPawchiveAccounts
        .where((a) => a.id != target.id)
        .toList();

    // If active was removed, make first remaining active
    if (filtered.isNotEmpty && !filtered.any((a) => a.isActive)) {
      filtered[0] = filtered[0].copyWith(isActive: true);
    }

    await ref.read(settingsControllerProvider.notifier).saveSettings(
          settings.copyWith(
            pawchiveAccounts:
                filtered.map((a) => jsonEncode(a.toJson())).toList(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final accounts = settings.parsedPawchiveAccounts;

    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final pushTarget =
        settings.activePawchiveAccount ?? (accounts.isNotEmpty
            ? accounts.first
            : null);

    return DraggableScrollableSheet(
      initialChildSize: accounts.isEmpty ? 0.8 : 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRu ? 'Аккаунты Pawchive' : 'Pawchive accounts',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isRu
                                ? 'Синхронизация авторов и избранного'
                                : 'Artist and favorites sync',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _syncingAll ? null : _syncAllAccounts,
                        icon: _syncingAll
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 20),
                        tooltip: isRu
                            ? 'Синхронизировать все аккаунты'
                            : 'Sync all accounts',
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),

              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding:
                      EdgeInsets.fromLTRB(16, 12, 16, 16 + keyboardPadding),
                  children: [
                    // Connected accounts section
                    if (accounts.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          isRu
                              ? 'ПОДКЛЮЧЁННЫЕ АККАУНТЫ (${accounts.length})'
                              : 'CONNECTED ACCOUNTS (${accounts.length})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...accounts.map(
                        (acc) => PawchiveAccountCard(
                          account: acc,
                          isSyncing: _syncingAccountId == acc.id,
                          isPushing: _pushingAccountId == acc.id,
                          isRu: isRu,
                          onPush: () => _pushFavoritesToAccount(acc),
                          onSync: () => _syncSingleAccount(acc),
                          onSetActive: () => _setActiveAccount(acc),
                          onDelete: () => _removeAccount(acc),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PawchiveBidirectionalSyncPanel(
                        bidirectionalSync: settings.pawchiveBidirectionalSync,
                        localFavoritesCount: settings.favoriteArtists.length,
                        targetUsername: pushTarget?.username ?? '',
                        busy: _syncingAll || _pushingAccountId != null,
                        pushing: _pushingAccountId != null,
                        isRu: isRu,
                        onToggleBidirectional: (val) async {
                          final newSettings = settings.copyWith(
                            pawchiveBidirectionalSync: val,
                          );
                          await ref
                              .read(settingsControllerProvider.notifier)
                              .saveSettings(newSettings);
                        },
                        onPush: () {
                          if (pushTarget == null) return;
                          _pushFavoritesToAccount(pushTarget);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    PawchiveAddAccountCard(
                      tabController: _addTabController,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      cookieController: _cookieController,
                      obscurePassword: _obscurePassword,
                      onToggleObscurePassword: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      isAdding: _isAdding,
                      errorMessage: _errorMessage,
                      isFirstAccount: accounts.isEmpty,
                      isRu: isRu,
                      onLoginCredentials: _handleLoginCredentials,
                      onLoginCookie: _handleLoginCookie,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
