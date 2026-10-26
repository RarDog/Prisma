import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/security/credential_store.dart';

void main() {
  group('CredentialStore secret-key classification', () {
    test('identifies all credential header keys', () {
      expect(CredentialStore.isSecretKey('query.login'), isTrue);
      expect(CredentialStore.isSecretKey('query.api_key'), isTrue);
      expect(CredentialStore.isSecretKey('query.key'), isTrue);
      expect(CredentialStore.isSecretKey('query.token'), isTrue);
      expect(CredentialStore.isSecretKey('phpsessid'), isTrue);
      expect(CredentialStore.isSecretKey('PHPSESSID'), isTrue);
      expect(CredentialStore.isSecretKey('api_key'), isTrue);
      expect(CredentialStore.isSecretKey('apikey'), isTrue);
      expect(CredentialStore.isSecretKey('token'), isTrue);
      expect(CredentialStore.isSecretKey('Authorization'), isTrue);
      expect(CredentialStore.isSecretKey('cookie'), isTrue);
    });

    test('does not flag ordinary headers or non-secret query params', () {
      expect(CredentialStore.isSecretKey('User-Agent'), isFalse);
      expect(CredentialStore.isSecretKey('Referer'), isFalse);
      expect(CredentialStore.isSecretKey('query.user_id'), isFalse);
      expect(CredentialStore.isSecretKey('query.limit'), isFalse);
    });

    test('stripSecrets keeps only persistable headers', () {
      final stripped = CredentialStore.stripSecrets({
        'User-Agent': 'Prisma',
        'query.login': 'user',
        'query.api_key': 'secret',
        'Referer': 'https://e621.net/',
      });

      expect(stripped, {
        'User-Agent': 'Prisma',
        'Referer': 'https://e621.net/',
      });
    });

    test('extractSecrets returns only credential entries', () {
      final secrets = CredentialStore.extractSecrets({
        'User-Agent': 'Prisma',
        'phpsessid': 'session-cookie',
        'Authorization': 'Basic dXNlcjprZXk=',
      });

      expect(secrets, {
        'phpsessid': 'session-cookie',
        'Authorization': 'Basic dXNlcjprZXk=',
      });
    });

    test('hasSecrets detects credentials in a header map', () {
      expect(
        CredentialStore.hasSecrets({'query.api_key': 'abc'}),
        isTrue,
      );
      expect(
        CredentialStore.hasSecrets({'User-Agent': 'Prisma'}),
        isFalse,
      );
      expect(CredentialStore.hasSecrets(const {}), isFalse);
    });

    test('strip + extract round-trip preserves the full map', () {
      final headers = {
        'User-Agent': 'Prisma',
        'query.login': 'user',
        'query.api_key': 'secret',
      };

      final restored = {
        ...CredentialStore.stripSecrets(headers),
        ...CredentialStore.extractSecrets(headers),
      };

      expect(restored, headers);
    });
  });
}
