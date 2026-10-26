import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for provider credentials (API keys, session cookies,
/// Basic auth values).
///
/// Secrets are keyed per provider and stored in the OS keychain so that
/// Isar database dumps, diagnostics and config exports never contain them.
///
/// Graceful degradation: on platforms where the OS keychain is unavailable
/// (e.g. headless Linux without libsecret, or Flutter test bindings) the
/// write methods report failure instead of throwing, and the repository
/// keeps the legacy plaintext persistence path so credentials are not lost.
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'prisma.provider.';

  /// Header keys that must never be persisted to the database.
  ///
  /// Covers the e621 Basic-auth pair (`query.login`/`query.api_key`), the
  /// Pixiv session cookie (`phpsessid`), and generic API-key/token/auth
  /// headers used by custom providers and onboarding.
  static const secretHeaderKeys = {
    'query.login',
    'query.api_key',
    'query.key',
    'query.token',
    'phpsessid',
    'api_key',
    'apikey',
    'token',
    'authorization',
    'cookie',
  };

  static bool isSecretKey(String key) =>
      secretHeaderKeys.contains(key.toLowerCase());

  /// Returns [headers] without the secret entries (safe to persist).
  static Map<String, String> stripSecrets(Map<String, String> headers) =>
      Map.fromEntries(headers.entries.where((e) => !isSecretKey(e.key)));

  /// Returns only the secret entries of [headers].
  static Map<String, String> extractSecrets(Map<String, String> headers) =>
      Map.fromEntries(headers.entries.where((e) => isSecretKey(e.key)));

  static bool hasSecrets(Map<String, String> headers) =>
      headers.keys.any(isSecretKey);

  final FlutterSecureStorage _storage;

  /// Reads stored credentials for [providerId]. Returns an empty map when
  /// nothing is stored or the keychain is unavailable.
  Future<Map<String, String>> read(String providerId) async {
    try {
      final raw = await _storage.read(key: '$_keyPrefix$providerId');
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded
          .map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return const {};
    }
  }

  /// Stores [secrets] for [providerId]. Returns false when the keychain is
  /// unavailable so callers can fall back to legacy persistence.
  Future<bool> write(String providerId, Map<String, String> secrets) async {
    try {
      if (secrets.isEmpty) {
        await _storage.delete(key: '$_keyPrefix$providerId');
      } else {
        await _storage.write(
          key: '$_keyPrefix$providerId',
          value: jsonEncode(secrets),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes stored credentials for [providerId].
  Future<bool> delete(String providerId) => write(providerId, const {});
}
