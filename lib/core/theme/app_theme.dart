library;

import 'package:flutter/material.dart';

import 'app_spacing.dart';

abstract final class AppTheme {
  static const Color _seed = Color(0xFF24292F);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static TextTheme _textTheme(ColorScheme scheme) => TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      height: 1.12,
      letterSpacing: -0.25,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      height: 1.16,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      height: 1.22,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.29,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.33,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.27,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.5,
      letterSpacing: 0.15,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.43,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.43,
      letterSpacing: 0.25,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.33,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.43,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w500,
      color: scheme.onSurface,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.33,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.45,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    ),
  );

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final TextTheme text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
