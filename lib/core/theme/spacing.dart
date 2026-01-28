/// Centralized spacing tokens for consistent layout across the app.
///
/// Use these values instead of hardcoded numbers for padding, margins, and gaps.
/// This ensures visual consistency and makes global adjustments easy.
library;

import 'package:flutter/widgets.dart';

/// Spacing tokens following a consistent scale.
///
/// Usage:
/// ```dart
/// Padding(padding: EdgeInsets.all(AppSpacing.md))
/// SizedBox(height: AppSpacing.lg)
/// ```
abstract final class AppSpacing {
  /// 2.0 - Micro spacing for tight layouts
  static const double xxs = 2.0;
  
  /// 4.0 - Extra small spacing
  static const double xs = 4.0;
  
  /// 8.0 - Small spacing between related elements
  static const double sm = 8.0;
  
  /// 12.0 - Medium spacing for moderate separation
  static const double md = 12.0;
  
  /// 16.0 - Standard padding and large gaps
  static const double lg = 16.0;
  
  /// 24.0 - Extra large spacing between sections
  static const double xl = 24.0;
  
  /// 32.0 - Double extra large for major sections
  static const double xxl = 32.0;
  
  /// 48.0 - Triple extra large for page-level spacing
  static const double xxxl = 48.0;

  // Common EdgeInsets presets
  
  /// Zero padding
  static const EdgeInsets zero = EdgeInsets.zero;
  
  /// All sides: xs (4)
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  
  /// All sides: sm (8)
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  
  /// All sides: md (12)
  static const EdgeInsets allMd = EdgeInsets.all(md);
  
  /// All sides: lg (16)
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  
  /// All sides: xl (24)
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  
  /// Horizontal: lg (16)
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  
  /// Horizontal: md (12)
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  
  /// Vertical: sm (8)
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  
  /// Vertical: md (12)
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  
  /// Card content padding: horizontal lg, vertical md
  static const EdgeInsets cardContent = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  
  /// List item padding
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
}

/// Border radius tokens for consistent corner rounding.
///
/// Usage:
/// ```dart
/// BorderRadius.circular(AppRadius.md)
/// ```
abstract final class AppRadius {
  /// 0.0 - Sharp corners
  static const double none = 0.0;
  
  /// 4.0 - Subtle rounding
  static const double sm = 4.0;
  
  /// 8.0 - Standard rounding for cards
  static const double md = 8.0;
  
  /// 12.0 - Prominent rounding
  static const double lg = 12.0;
  
  /// 16.0 - Large rounding for modals
  static const double xl = 16.0;
  
  /// 24.0 - Extra large rounding
  static const double xxl = 24.0;
  
  /// 999.0 - Full rounding (pills, circles)
  static const double full = 999.0;

  // Common BorderRadius presets
  
  /// Small border radius (4)
  static BorderRadius get borderSm => BorderRadius.circular(sm);
  
  /// Medium border radius (8)
  static BorderRadius get borderMd => BorderRadius.circular(md);
  
  /// Large border radius (12)
  static BorderRadius get borderLg => BorderRadius.circular(lg);
  
  /// Extra large border radius (16)
  static BorderRadius get borderXl => BorderRadius.circular(xl);
  
  /// Top only large radius - for bottom sheets
  static BorderRadius get topLg => const BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}
