/// Centralized typography system for consistent text styling across the app.
///
/// Design decisions:
/// - Uses base font sizes that are consistent across platforms
/// - Relies on Flutter's built-in text scaling for accessibility
/// - Uses consistent line heights to prevent clipping
/// - Applies TextHeightBehavior to eliminate platform font metric differences
library;

import 'package:flutter/material.dart';

/// Typography scale tokens.
///
/// These base sizes are used to construct the TextTheme.
/// Text automatically scales based on user accessibility settings.
abstract final class AppTypography {
  // Font family - using system defaults for platform-native feel
  // iOS: SF Pro, Android: Roboto
  static const String? fontFamily = null;

  // ═══════════════════════════════════════════════════════════════════════════
  // BASE FONT SIZES (in logical pixels)
  // These are the base sizes before any system scaling is applied.
  // ═══════════════════════════════════════════════════════════════════════════

  /// 32.0 - Display large (hero text)
  static const double displayLarge = 32.0;

  /// 28.0 - Display medium (page titles)
  static const double displayMedium = 28.0;

  /// 24.0 - Display small (section headers)
  static const double displaySmall = 24.0;

  /// 22.0 - Headline large
  static const double headlineLarge = 22.0;

  /// 20.0 - Headline medium
  static const double headlineMedium = 20.0;

  /// 18.0 - Headline small
  static const double headlineSmall = 18.0;

  /// 16.0 - Title large (card titles)
  static const double titleLarge = 16.0;

  /// 14.0 - Title medium
  static const double titleMedium = 14.0;

  /// 13.0 - Title small
  static const double titleSmall = 13.0;

  /// 15.0 - Body large (primary content)
  static const double bodyLarge = 15.0;

  /// 14.0 - Body medium (secondary content)
  static const double bodyMedium = 14.0;

  /// 13.0 - Body small (summaries, descriptions)
  static const double bodySmall = 13.0;

  /// 14.0 - Label large (buttons)
  static const double labelLarge = 14.0;

  /// 12.0 - Label medium (badges)
  static const double labelMedium = 12.0;

  /// 11.0 - Label small (captions, timestamps)
  static const double labelSmall = 11.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // LINE HEIGHTS
  // Consistent line heights prevent cross-platform rendering differences.
  // ═══════════════════════════════════════════════════════════════════════════

  /// 1.2 - Tight line height for display text
  static const double lineHeightTight = 1.2;

  /// 1.35 - Normal line height for body text (cross-platform consistent)
  static const double lineHeightNormal = 1.35;

  /// 1.5 - Relaxed line height for long-form content
  static const double lineHeightRelaxed = 1.5;

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT HEIGHT BEHAVIOR
  // Forces consistent text bounds across iOS and Android.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Standard text height behavior for cross-platform consistency.
  static const TextHeightBehavior textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Creates the app's TextTheme.
  static TextTheme createTextTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: displayLarge,
        fontWeight: FontWeight.bold,
        height: lineHeightTight,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: displayMedium,
        fontWeight: FontWeight.bold,
        height: lineHeightTight,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: displaySmall,
        fontWeight: FontWeight.w600,
        height: lineHeightTight,
        color: onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: headlineLarge,
        fontWeight: FontWeight.w600,
        height: lineHeightNormal,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: headlineMedium,
        fontWeight: FontWeight.w600,
        height: lineHeightNormal,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: headlineSmall,
        fontWeight: FontWeight.w600,
        height: lineHeightNormal,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: titleLarge,
        fontWeight: FontWeight.w600,
        height: lineHeightNormal,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: titleMedium,
        fontWeight: FontWeight.w500,
        height: lineHeightNormal,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: titleSmall,
        fontWeight: FontWeight.w500,
        height: lineHeightNormal,
        color: onSurfaceVariant,
      ),
      bodyLarge: TextStyle(
        fontSize: bodyLarge,
        fontWeight: FontWeight.normal,
        height: lineHeightRelaxed,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: bodyMedium,
        fontWeight: FontWeight.normal,
        height: lineHeightNormal,
        color: onSurfaceVariant,
      ),
      bodySmall: TextStyle(
        fontSize: bodySmall,
        fontWeight: FontWeight.normal,
        height: lineHeightNormal,
        color: onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: labelLarge,
        fontWeight: FontWeight.w500,
        height: lineHeightNormal,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: labelMedium,
        fontWeight: FontWeight.w500,
        height: lineHeightNormal,
        letterSpacing: 0.5,
        color: onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: labelSmall,
        fontWeight: FontWeight.normal,
        height: lineHeightNormal,
        color: onSurfaceVariant,
      ),
    );
  }
}

/// Extension methods for common text style modifications.
extension TextStyleExtensions on TextStyle {
  /// Makes the text bold (w700).
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Makes the text semi-bold (w600).
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Makes the text medium weight (w500).
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
}
