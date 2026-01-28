/// Core theme configuration for the Blips app.
///
/// Centralizes all theme-related configuration including colors,
/// typography, and component themes.
library;

import 'package:blips_mobile/core/theme/typography.dart';
import 'package:flutter/material.dart';

/// Brand colors for the app.
abstract final class AppColors {
  /// Primary brand color - teal
  static const Color primary = Color(0xFF0E7490);

  /// Light theme scaffold background
  static const Color lightBackground = Color(0xFFF1F5F9);

  /// Light theme card color
  static const Color lightCard = Colors.white;

  /// Dark theme scaffold background
  static const Color darkBackground = Color(0xFF0F172A);

  /// Dark theme card color
  static const Color darkCard = Color(0xFF1E293B);

  /// Dark theme surface color
  static const Color darkSurface = Color(0xFF1E293B);
}

/// Creates themed ThemeData instances for the app.
abstract final class AppTheme {
  /// Creates the light theme.
  static ThemeData light() {
    const baseColor = AppColors.primary;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseColor,
      brightness: Brightness.light,
    );

    final textTheme = AppTypography.createTextTheme(
      onSurface: colorScheme.onSurface,
      onSurfaceVariant: colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightCard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightCard,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightBackground,
        selectedItemColor: baseColor,
        unselectedItemColor: Colors.grey,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
    );
  }

  /// Creates the dark theme.
  static ThemeData dark() {
    const baseColor = AppColors.primary;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseColor,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
    );

    final textTheme = AppTypography.createTextTheme(
      onSurface: colorScheme.onSurface,
      onSurfaceVariant: colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBackground,
        selectedItemColor: baseColor,
        unselectedItemColor: Colors.grey,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
      ),
    );
  }
}
