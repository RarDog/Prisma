import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:gel_rule_app/features/providers/presentation/providers_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this._initial);
  final AppSettings _initial;

  @override
  Future<AppSettings> build() async => _initial;

  @override
  Future<void> saveSettings(AppSettings updated) async {
    state = AsyncData(updated);
  }
}

class _FakeProvidersController extends ProvidersController {
  _FakeProvidersController(this._initial);
  final List<ContentProviderConfig> _initial;

  @override
  Future<List<ContentProviderConfig>> build() async => _initial;

  @override
  Future<void> toggle(String id, bool enabled) async {
    state = AsyncData(
      (state.value ?? _initial).map((p) {
        if (p.id == id) {
          return p.copyWith(enabled: enabled);
        }
        return p;
      }).toList(),
    );
  }

  @override
  Future<void> save(ContentProviderConfig config) async {
    final current = state.value ?? _initial;
    final idx = current.indexWhere((p) => p.id == config.id);
    if (idx >= 0) {
      final updated = List<ContentProviderConfig>.from(current);
      updated[idx] = config;
      state = AsyncData(updated);
    } else {
      state = AsyncData([...current, config]);
    }
  }
}

void main() {
  testWidgets(
      'OnboardingScreen renders modular steps and transitions correctly',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = AppSettings.defaults.copyWith(
      languageCode: 'ru',
      themeMode: 'dark',
    );

    final providers = [
      ContentProviderConfig(
        id: 'safebooru',
        name: 'Safebooru',
        baseUrl: 'https://safebooru.org',
        apiType: 'gelbooru',
        enabled: true,
        priority: 1,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ContentProviderConfig(
        id: 'rule34',
        name: 'Rule34',
        baseUrl: 'https://rule34.xxx',
        apiType: 'gelbooru',
        enabled: false,
        priority: 2,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
            () => _FakeProvidersController(providers),
          ),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // STEP 1: Language selection is rendered
    expect(find.text('Добро пожаловать в Prizma!'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Восстановить из копии'), findsOneWidget);

    // Tap Continue to go to Step 2
    await tester.ensureVisible(find.text('Продолжить'));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    // STEP 2: Theme & Appearance
    expect(find.text('Оформление и стиль'), findsOneWidget);
    expect(find.text('Живое превью'), findsOneWidget);
    expect(find.text('Глубокий чёрный (AMOLED)'), findsOneWidget);

    // Tap Continue to go to Step 3
    await tester.ensureVisible(find.text('Продолжить'));
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    // STEP 3: Sources & Safety
    expect(find.text('Источники и безопасность'), findsOneWidget);
    expect(find.text('Фильтрация контента'), findsOneWidget);
    expect(find.text('Safebooru'), findsOneWidget);
    expect(find.text('SAFE'), findsOneWidget);

    // Tap to go to Step 4
    await tester.ensureVisible(find.text('Настроить API ключи'));
    await tester.tap(find.text('Настроить API ключи'));
    await tester.pumpAndSettle();

    // STEP 4: API Credentials
    expect(find.text('Учетные данные и API'), findsOneWidget);
    expect(find.text('Gelbooru'), findsOneWidget);
    expect(find.text('Danbooru'), findsOneWidget);

    // Tap Skip keys to go to Step 5
    await tester.ensureVisible(find.text('Пропустить ввод ключей'));
    await tester.tap(find.text('Пропустить ввод ключей'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // STEP 5: Completion
    expect(find.text('Всё готово!'), findsOneWidget);
    expect(find.text('Начать путешествие'), findsOneWidget);
    expect(find.text('Активные источники'), findsOneWidget);
  });
}
