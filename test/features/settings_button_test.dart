import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
