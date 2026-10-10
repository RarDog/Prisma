import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/filters_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets(
      'SettingsScreen renders category quick nav and sections without overflow',
      (tester) async {
    // Test on typical mobile viewport: 390x844
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = AppSettings.defaults.copyWith(
      languageCode: 'ru',
      themeMode: 'dark',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(settings),
          ),
          // The screens read their strings through `appStringsProvider`,
          // which resolves the language from the settings blob.
          appSettingsProvider.overrideWith((ref) => settings),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Settings Hub category cards render
    expect(find.text('Основное'), findsWidgets);
    expect(find.text('Внешний вид'), findsWidgets);
    expect(find.text('Лента и сетка'), findsWidgets);

    // Verify Quick Theme mode segment buttons on Hub
    expect(find.text('Темная'), findsOneWidget);
    expect(find.text('Светлая'), findsOneWidget);
    expect(find.text('Авто'), findsOneWidget);

    // Tap 'Основное' to navigate into GeneralSettingsScreen
    await tester.tap(find.text('Основное').first);
    await tester.pumpAndSettle();

    // Verify language segment is visible in GeneralSettingsScreen
    expect(find.text('🇷🇺 Русский'), findsOneWidget);
    expect(find.text('🇬🇧 English'), findsOneWidget);

    // Tap English to test selection
    await tester.tap(find.text('🇬🇧 English'));
    await tester.pumpAndSettle();

    // Test back button popping back to Settings Hub
    final backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.text('General'), findsWidgets);
    }
  });

  testWidgets(
      'FiltersSettingsScreen renders blacklisted tags and smart rules properly',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = AppSettings.defaults.copyWith(
      languageCode: 'ru',
      blacklistedTags: ['solo_dragon', 'feral'],
      smartBlacklistRules: ['score:<10', 'rating:explicit'],
      whitelistedTags: ['favorite_art'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettingsController(settings),
          ),
          // The screens read their strings through `appStringsProvider`,
          // which resolves the language from the settings blob.
          appSettingsProvider.overrideWith((ref) => settings),
        ],
        child: const MaterialApp(
          home: FiltersSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify blacklist tags section & chips
    expect(find.text('Чёрный список тегов'), findsWidgets);
    expect(find.text('solo_dragon'), findsOneWidget);
    expect(find.text('feral'), findsOneWidget);

    // Verify smart blacklist section & chips
    expect(find.text('Умный blacklist'), findsWidgets);
    expect(find.text('score:<10'), findsOneWidget);
    expect(find.text('rating:explicit'), findsOneWidget);

    // Verify whitelist section & chips
    expect(find.text('Whitelist тегов'), findsWidgets);
    expect(find.text('favorite_art'), findsOneWidget);
  });
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
