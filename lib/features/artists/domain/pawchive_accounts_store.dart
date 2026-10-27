import 'dart:async';
import 'dart:convert';

import 'package:gel_rule_app/core/security/credential_store.dart';
import 'package:gel_rule_app/core/utils/logger.dart';
import 'package:gel_rule_app/features/artists/models/pawchive_account.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';

/// Persists Pawchive account session cookies in the OS keychain.
///
/// Settings (and therefore Isar settings blobs and backup payloads) only
/// ever hold cookie-less account records; cookies are merged back in on
/// load. Plaintext cookies persisted before this store existed are migrated
/// to the keychain on first use — mirroring the provider-credentials flow
/// in ProviderRepository.
class PawchiveAccountsStore {
  PawchiveAccountsStore(this._settingsService,
      [CredentialStore? credentialStore])
      : _credentials = credentialStore ?? CredentialStore();

  static const _keyPrefix = 'prisma.pawchive.';

  final SettingsService _settingsService;
  final CredentialStore _credentials;

  /// Serializes accounts for persistence: session cookies stripped.
  static List<String> serialize(List<PawchiveAccount> accounts) => accounts
      .map((a) => jsonEncode(a.copyWith(sessionCookie: '').toJson()))
      .toList();

  /// Returns [account] with its session cookie merged in from the keychain.
  /// A cookie still present in the settings blob (legacy plaintext) is
  /// migrated to the keychain and stripped from settings, best-effort.
  Future<PawchiveAccount> resolveCookie(PawchiveAccount account) async {
    final key = '$_keyPrefix${account.id}';
    final secrets = await _credentials.read(key);
    var cookie = secrets['session'] ?? '';
    if (cookie.isEmpty && account.sessionCookie.isNotEmpty) {
      cookie = account.sessionCookie;
      final migrated = await _credentials.write(key, {'session': cookie});
      if (migrated) {
        unawaited(_rewriteStripped(account.id));
      }
    }
    return account.copyWith(sessionCookie: cookie);
  }

  /// Loads all accounts from [settings] with cookies merged in.
  Future<List<PawchiveAccount>> load(AppSettings settings) async {
    final result = <PawchiveAccount>[];
    for (final account in settings.parsedPawchiveAccounts) {
      result.add(await resolveCookie(account));
    }
    return result;
  }

  /// Persists the full account list: writes any present cookies to the
  /// keychain, drops keychain entries of removed accounts, and returns
  /// settings carrying cookie-less account records. When the keychain is
  /// unavailable, the cookie stays in the record (legacy plaintext path) so
  /// credentials are not silently lost.
  Future<AppSettings> persist(
    AppSettings settings,
    List<PawchiveAccount> accounts,
  ) async {
    final keepIds = <String>{};
    final records = <String>[];
    for (final account in accounts) {
      keepIds.add(account.id);
      var record = account;
      if (account.sessionCookie.isNotEmpty) {
        final storedSecurely = await _credentials.write(
            '$_keyPrefix${account.id}', {'session': account.sessionCookie});
        if (storedSecurely) {
          record = account.copyWith(sessionCookie: '');
        }
      }
      records.add(jsonEncode(record.toJson()));
    }
    for (final existing in settings.parsedPawchiveAccounts) {
      if (!keepIds.contains(existing.id)) {
        await _credentials.delete('$_keyPrefix${existing.id}');
      }
    }
    return settings.copyWith(pawchiveAccounts: records);
  }

  /// Moves a legacy plaintext cookie out of the settings blob once it is
  /// safely in the keychain. Best-effort, like ProviderRepository's legacy
  /// migration: must never block or fail the caller.
  Future<void> _rewriteStripped(String accountId) async {
    try {
      final result = await _settingsService.getSettings();
      if (result is! Success<AppSettings>) return;
      final settings = result.data;
      final hasPlaintext = settings.parsedPawchiveAccounts.any(
        (a) => a.id == accountId && a.sessionCookie.isNotEmpty,
      );
      if (!hasPlaintext) return;
      final stripped = settings.parsedPawchiveAccounts
          .map((a) => a.id == accountId ? a.copyWith(sessionCookie: '') : a)
          .toList();
      await _settingsService.updateSettings(
        settings.copyWith(pawchiveAccounts: serialize(stripped)),
      );
    } catch (e, st) {
      AppLogger.log('PawchiveAccountsStore: legacy migration failed', e, st);
    }
  }
}
