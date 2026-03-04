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

  // ─── Neon (Charcoal Base) Tokens ─────────────────────────────────────────
  // A high-signal, intelligence-forward palette. Neon used as controlled
  // accent only — never as background. WCAG AA contrast maintained
  // throughout (cyan #00D9F5 achieves ~7:1 on #121212).

  /// Neon scaffold background — deep charcoal. Matches app icon.
  /// RGB: 18, 18, 18
  static const Color neonBackground = Color(0xFF121212);

  /// Neon secondary background — slightly elevated surface.
  /// RGB: 26, 26, 26
  static const Color neonSecondaryBg = Color(0xFF1A1A1A);

  /// Neon card / surface background.
  /// RGB: 30, 30, 33
  static const Color neonCard = Color(0xFF1E1E21);

  /// Neon divider — subtle warm-dark separator line.
  /// RGB: 44, 44, 50
  static const Color neonDivider = Color(0xFF2C2C32);

  /// Neon primary text — near-white with a faint cool tint.
  /// RGB: 240, 240, 245
  static const Color neonTextPrimary = Color(0xFFF0F0F5);

  /// Neon secondary text — muted cool-grey. Used for metadata.
  /// RGB: 136, 136, 160
  static const Color neonTextSecondary = Color(0xFF8888A0);

  /// Neon disabled text.
  /// RGB: 68, 68, 74
  static const Color neonTextDisabled = Color(0xFF44444A);

  // ─── Neon Accents ─────────────────────────────────────────────────────────
  // Use accents sparingly: active indicators, CTAs, tags.
  // Never use as backgrounds. Max ~10–15% of any screen surface.

  /// Primary neon accent — electric cyan.
  /// Use: active nav tab, tappable links, article category badge,
  ///      video progress fill, AI indicator dot.
  /// RGB: 0, 217, 245  |  Contrast vs #121212: ~7.2:1  ✓ WCAG AA
  static const Color neonPrimary = Color(0xFF00D9F5);

  /// Secondary neon accent — vivid warm orange.
  /// Use: CTA buttons (Read More), breaking news tag, swipe action.
  /// Matches icon pill accent. RGB: 255, 107, 53
  static const Color neonSecondary = Color(0xFFFF6B35);

  /// AI / intelligence accent — restrained electric violet.
  /// Use: AI chat bubble border, AI summary indicator, "Ask AI" affordance.
  /// RGB: 192, 132, 252
  static const Color neonAI = Color(0xFFC084FC);

  /// Warning / alert neon — amber.
  /// Use: breaking news label, feed staleness warning, time-critical tags.
  /// RGB: 255, 184, 0
  static const Color neonWarning = Color(0xFFFFB800);
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

  /// Creates the Neon theme — charcoal base with controlled electric accents.
  ///
  /// Design principles:
  /// - Deep charcoal backgrounds (#121212) for calm, premium feel.
  /// - Electric cyan (#00D9F5) as the primary signal accent, WCAG AA.
  /// - Vivid orange (#FF6B35) as CTA / highlight accent.
  /// - Soft violet (#C084FC) exclusively for AI/intelligence affordances.
  /// - Neon never used as backgrounds. Max ~15% of screen surface area.
  static ThemeData neon() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.neonPrimary,
      brightness: Brightness.dark,
      surface: AppColors.neonCard,
    );

    final colorScheme = base.copyWith(
      primary: AppColors.neonPrimary,
      onPrimary: const Color(0xFF001F27),
      primaryContainer: const Color(0xFF003640),
      onPrimaryContainer: AppColors.neonPrimary,
      secondary: AppColors.neonSecondary,
      onSecondary: const Color(0xFF200D00),
      secondaryContainer: const Color(0xFF3A1800),
      onSecondaryContainer: AppColors.neonSecondary,
      tertiary: AppColors.neonAI,
      onTertiary: const Color(0xFF1A0030),
      tertiaryContainer: const Color(0xFF2D0050),
      onTertiaryContainer: AppColors.neonAI,
      surface: AppColors.neonCard,
      onSurface: AppColors.neonTextPrimary,
      onSurfaceVariant: AppColors.neonTextSecondary,
      outline: const Color(0xFF3A3A45),
      outlineVariant: AppColors.neonDivider,
    );

    final textTheme = AppTypography.createTextTheme(
      onSurface: AppColors.neonTextPrimary,
      onSurfaceVariant: AppColors.neonTextSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.neonBackground,
      cardColor: AppColors.neonCard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neonBackground,
        foregroundColor: AppColors.neonTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.neonTextPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.neonBackground,
        selectedItemColor: AppColors.neonPrimary,
        unselectedItemColor: AppColors.neonTextDisabled,
      ),
      cardTheme: CardThemeData(
        color: AppColors.neonCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.neonDivider,
        thickness: 1,
      ),
    );
  }
}

/// Extended theme mode that adds a [neon] option alongside Flutter's
/// built-in light/dark/system modes.
enum AppThemeMode {
  /// Follows the OS appearance setting.
  system,

  /// Always light.
  light,

  /// Always dark (navy base — existing brand dark theme).
  dark,

  /// Neon — charcoal base with controlled electric cyan/orange accents.
  neon;

  /// Maps to Flutter's [ThemeMode].
  /// Both [dark] and [neon] resolve to [ThemeMode.dark]; the app root
  /// selects the appropriate [ThemeData] based on this enum value.
  ThemeMode get materialMode => switch (this) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.dark || AppThemeMode.neon => ThemeMode.dark,
      };
}
