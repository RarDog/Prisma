import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/shared/widgets/app_destination.dart';
import 'package:gel_rule_app/shared/widgets/liquid_glass_bottom_bar.dart';

void main() {
  testWidgets('LiquidGlassSettingsButton renders gear icon in light mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Center(
            child: LiquidGlassSettingsButton(
              ru: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('LiquidGlassSettingsButton renders gear icon in dark mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: LiquidGlassSettingsButton(
              ru: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('LiquidGlassSettingsButton renders gear icon in amoled mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF000000),
          colorScheme: const ColorScheme.dark().copyWith(
            surface: const Color(0xFF000000),
          ),
        ),
        home: Scaffold(
          body: Center(
            child: LiquidGlassSettingsButton(
              ru: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('bar settings tab opens via reveal callback, not navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const items = [
      AppDestination('feed', 'Feed', Icons.feed_rounded, '/'),
      AppDestination('search', 'Search', Icons.search_rounded, '/search'),
      AppDestination(
        'settings',
        'Settings',
        Icons.settings_outlined,
        '/settings',
      ),
    ];

    var navigated = 0;
    var revealRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: LiquidGlassBottomBar(
            selectedIndex: 0,
            onDestinationSelected: (_) => navigated++,
            items: items,
            ru: true,
            settingsIndex: 2,
            onSettingsTap: (_) => revealRequested = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The gear lives inside the bar, at the bottom of the screen.
    final gearFinder = find.byIcon(Icons.settings_outlined);
    expect(gearFinder, findsOneWidget);
    expect(tester.getTopLeft(gearFinder).dy, greaterThan(600));

    // Tapping the gear triggers the reveal callback, not a branch switch.
    await tester.tap(gearFinder);
    await tester.pumpAndSettle();
    expect(revealRequested, isTrue);
    expect(navigated, 0);
  });
}
