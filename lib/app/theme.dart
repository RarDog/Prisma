import 'package:flutter/material.dart';

ThemeData buildTheme(
  Brightness brightness, {
  int seedColor = 0xFFE84D8A,
  bool amoled = false,
  ColorScheme? dynamicColorScheme,
}) {
  final dark = brightness == Brightness.dark;
  final scheme = dynamicColorScheme ??
      ColorScheme.fromSeed(
        seedColor: Color(seedColor),
        brightness: brightness,
      );

  final scaffoldBg = amoled && dark
      ? const Color(0xFF000000)
      : dark
          ? const Color(0xFF101114)
          : const Color(0xFFF8F8FA);
  final cardBg = amoled && dark
      ? const Color(0xFF0A0A0A)
      : dark
          ? const Color(0xFF191B20)
          : Colors.white;
  final navBg = amoled && dark
      ? const Color(0xFF000000)
      : dark
          ? const Color(0xFF15161A)
          : Colors.white;
  final appBarBg = amoled && dark
      ? const Color(0xFF000000)
      : dark
          ? const Color(0xFF101114)
          : const Color(0xFFF8F8FA);

  final dialogBg = amoled && dark
      ? const Color(0xFF101014)
      : dark
          ? const Color(0xFF1C1E24)
          : Colors.white;
  final sheetBg = amoled && dark
      ? const Color(0xFF0D0D11)
      : dark
          ? const Color(0xFF181A20)
          : Colors.white;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,
    cardColor: cardBg,
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: navBg,
      selectedIconTheme: IconThemeData(color: scheme.primary),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: appBarBg,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: dark
            ? BorderSide(color: Colors.white.withValues(alpha: 0.07), width: 0.8)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.28), width: 0.8),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 8,
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: dark
            ? BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.25), width: 0.8),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 12,
      showDragHandle: true,
      dragHandleColor: dark ? Colors.white24 : Colors.black26,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      backgroundColor: dark ? const Color(0xFF282A30) : const Color(0xFF1E2024),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      elevation: 6,
      color: dark ? (amoled ? const Color(0xFF141418) : const Color(0xFF22242B)) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: dark
            ? BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8)
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.25), width: 0.8),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2E313A) : const Color(0xFF32343A),
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? (amoled ? const Color(0xFF121316) : const Color(0xFF1E2026))
          : const Color(0xFFF0F1F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.8), width: 1.5),
      ),
    ),
  );
}

ThemeMode parseThemeMode(String value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}
