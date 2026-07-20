import 'package:flutter/material.dart';

abstract final class CrocColors {
  static const forest = Color(0xFF12382C);
  static const forestBright = Color(0xFF1C5945);
  static const lime = Color(0xFFC8F169);
  static const cream = Color(0xFFF4F1E8);
  static const paper = Color(0xFFFFFDF7);
  static const ink = Color(0xFF18221E);
  static const muted = Color(0xFF65716A);
  static const line = Color(0xFFD9DED7);
  static const coral = Color(0xFFE66A4E);
}

ThemeData buildCrocTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CrocColors.forest,
    brightness: Brightness.light,
    primary: CrocColors.forest,
    secondary: CrocColors.lime,
    surface: CrocColors.paper,
    error: CrocColors.coral,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CrocColors.cream,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: CrocColors.ink,
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
      ),
      headlineMedium: TextStyle(
        color: CrocColors.ink,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        color: CrocColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      bodyLarge: TextStyle(color: CrocColors.ink, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(
        color: CrocColors.muted,
        fontSize: 14,
        height: 1.45,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    cardTheme: const CardThemeData(
      color: CrocColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: CrocColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CrocColors.paper,
      hintStyle: const TextStyle(color: CrocColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CrocColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CrocColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CrocColors.forest, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CrocColors.forest,
        foregroundColor: Colors.white,
        disabledBackgroundColor: CrocColors.line,
        disabledForegroundColor: CrocColors.muted,
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CrocColors.forest,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: CrocColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: CrocColors.forest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: CrocColors.paper,
      indicatorColor: CrocColors.lime,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
