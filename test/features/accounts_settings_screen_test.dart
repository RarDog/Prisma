import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/features/providers/presentation/providers_controller.dart';
import 'package:prisma_app/features/settings/presentation/screens/accounts_settings_screen.dart';
import 'package:prisma_app/features/settings/presentation/settings_controller.dart';

ContentProviderConfig _sampleConfig({
  required String id,
  required String name,
  String apiType = 'e621',
  String baseUrl = 'https://e621.net',
  bool enabled = true,
  Map<String, String> customHeaders = const {},
}) {
  return ContentProviderConfig(
    id: id,
    name: name,
    baseUrl: baseUrl,
    apiType: apiType,
    enabled: enabled,
    priority: 5,
    timeoutSeconds: 20,
    customHeaders: customHeaders,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

class _FakeProvidersController extends ProvidersController {
  _FakeProvidersController(this._items);
  final List<ContentProviderConfig> _items;

  @override
  Future<List<ContentProviderConfig>> build() async => _items;
}

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._initial);

  final AppSettings _initial;

  @override
  Future<AppSettings> build() async => _initial;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    state = AsyncData(settings);
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
      'AccountsSettingsScreen renders e621 and e926 tiles with account info',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = AppSettings.defaults.copyWith(
      languageCode: 'ru',
    );

    final sampleProviders = [
      _sampleConfig(
        id: 'e621',
        name: 'e621',
        customHeaders: {
          'query.login': 'test_furry',
          'query.api_key': 'secret_key',
        },
      ),
      _sampleConfig(
        id: 'e926',
        name: 'e926',
        baseUrl: 'https://e926.net',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(settings),
          ),
          appSettingsProvider.overrideWith((ref) => settings),
          providersControllerProvider.overrideWith(
            () => _FakeProvidersController(sampleProviders),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          home: AccountsSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Аккаунты и синхронизация'), findsWidgets);
    expect(find.text('Pawchive (Авторы и художники)'), findsOneWidget);
    expect(find.text('e621 и e926 (Furry Booru)'), findsOneWidget);
    expect(find.text('e621'), findsOneWidget);
    expect(find.text('e926'), findsOneWidget);
    expect(find.text('В сети'), findsOneWidget);
    expect(find.text('Гость'), findsOneWidget);
    expect(find.text('SFW'), findsOneWidget);
    expect(find.textContaining('test_furry'), findsNWidgets(2));
    expect(find.text('Использовать аккаунт e621 для e926'), findsOneWidget);
    expect(find.text('Синхронизация черного списка e621'), findsOneWidget);
  });
}
