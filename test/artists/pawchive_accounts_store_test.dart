import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/security/credential_store.dart';
import 'package:gel_rule_app/features/artists/domain/pawchive_accounts_store.dart';
import 'package:gel_rule_app/features/artists/models/pawchive_account.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

class _FakeCredentialStore implements CredentialStore {
  final Map<String, Map<String, String>> vault = {};
  final bool available;

  _FakeCredentialStore({this.available = true});

  @override
  Future<Map<String, String>> read(String providerId) async =>
      vault[providerId] ?? const {};

  @override
  Future<bool> write(String providerId, Map<String, String> secrets) async {
    if (!available) return false;
    if (secrets.isEmpty) {
      vault.remove(providerId);
    } else {
      vault[providerId] = Map.of(secrets);
    }
    return true;
  }

  @override
  Future<bool> delete(String providerId) => write(providerId, const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsService extends Fake implements SettingsService {
  AppSettings current = AppSettings.defaults;

  @override
  Future<Result<AppSettings>> getSettings() async => Success(current);

  @override
  Future<Result<void>> updateSettings(AppSettings settings) async {
    current = settings;
    return const Success(null);
  }
}

PawchiveAccount account(String id, {String cookie = ''}) => PawchiveAccount(
      id: id,
      username: '@$id',
      sessionCookie: cookie,
      createdAt: DateTime(2024),
    );

void main() {
  test('persist routes the cookie into the keychain and strips settings',
      () async {
    final vault = _FakeCredentialStore();
    final store = PawchiveAccountsStore(_FakeSettingsService(), vault);

    final settings = await store.persist(
      AppSettings.defaults,
      [account('a1', cookie: 'secret-cookie')],
    );

    expect(vault.vault['prisma.pawchive.a1']?['session'], 'secret-cookie');
    expect(settings.parsedPawchiveAccounts.single.sessionCookie, isEmpty,
        reason: 'the settings blob must never hold the cookie');
  });

  test('resolveCookie merges the cookie back in', () async {
    final vault = _FakeCredentialStore();
    final store = PawchiveAccountsStore(_FakeSettingsService(), vault);
    await store.persist(
      AppSettings.defaults,
      [account('a1', cookie: 'secret-cookie')],
    );

    final strippedSettings = AppSettings.defaults.copyWith(
      pawchiveAccounts: PawchiveAccountsStore.serialize(
        [account('a1')],
      ),
    );
    final resolved = await store.load(strippedSettings);

    expect(resolved.single.sessionCookie, 'secret-cookie');
  });

  test('persist removes the keychain entry of deleted accounts', () async {
    final vault = _FakeCredentialStore();
    final settingsService = _FakeSettingsService();
    final store = PawchiveAccountsStore(settingsService, vault);
    var settings = await store.persist(
      AppSettings.defaults,
      [account('a1', cookie: 'c1'), account('a2', cookie: 'c2')],
    );
    settingsService.current = settings;

    settings = await store.persist(settings, [account('a1', cookie: 'c1')]);

    expect(vault.vault.containsKey('prisma.pawchive.a1'), isTrue);
    expect(vault.vault.containsKey('prisma.pawchive.a2'), isFalse);
  });

  test('persist keeps the cookie in settings when the keychain is unavailable',
      () async {
    final store = PawchiveAccountsStore(
      _FakeSettingsService(),
      _FakeCredentialStore(available: false),
    );

    final settings = await store.persist(
      AppSettings.defaults,
      [account('a1', cookie: 'secret-cookie')],
    );

    expect(settings.parsedPawchiveAccounts.single.sessionCookie,
        'secret-cookie',
        reason: 'graceful degradation: credentials must not be lost');
  });
}
