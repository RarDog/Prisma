import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/shared/widgets/app_destination.dart';
import 'package:prisma_app/shared/widgets/liquid_glass_bottom_bar.dart';

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

  testWidgets(
      'LiquidGlassBottomBar and LiquidGlassSettingsButton position correctly on desktop',
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
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          floatingActionButton: LiquidGlassSettingsButton(
            ru: true,
            onTap: () {},
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: LiquidGlassBottomBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            items: items,
            ru: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final gearFinder = find.byIcon(Icons.settings_rounded);
    expect(gearFinder, findsOneWidget);
    final gearOffset = tester.getTopLeft(gearFinder);
    expect(gearOffset.dy, greaterThan(600));

    final barFinder = find.byType(LiquidGlassBottomBar);
    expect(barFinder, findsOneWidget);
    final barOffset = tester.getTopLeft(barFinder);
    expect(barOffset.dy, greaterThan(650));
  });
}
