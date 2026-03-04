/// Centralized size tokens for consistent dimensions across the app.
///
/// Use these values instead of hardcoded numbers for icon sizes,
/// component dimensions, and other fixed measurements.
library;

/// Standard size tokens for consistent component dimensions.
///
/// Usage:
/// ```dart
/// Icon(Icons.home, size: AppSizes.iconMd)
/// SizedBox(height: AppSizes.bottomNavHeight)
/// ```
abstract final class AppSizes {
  // Icon sizes

  /// 16.0 - Extra small icons
  static const double iconXs = 16.0;

  /// 20.0 - Small icons
  static const double iconSm = 20.0;

  /// 24.0 - Standard icons (Material default)
  static const double iconMd = 24.0;

  /// 28.0 - Large icons
  static const double iconLg = 28.0;

  /// 32.0 - Extra large icons
  static const double iconXl = 32.0;

  /// 48.0 - Hero icons
  static const double iconXxl = 48.0;

  // Touch targets (minimum 48dp for accessibility)

  /// 44.0 - Minimum touch target (iOS HIG)
  static const double touchTargetMin = 44.0;

  /// 48.0 - Standard touch target (Material)
  static const double touchTarget = 48.0;

  // Component heights

  /// 56.0 - Standard bottom navigation height
  static const double bottomNavHeight = 44.0;

  /// 56.0 - Standard app bar height
  static const double appBarHeight = 56.0;

  /// 48.0 - Standard button height
  static const double buttonHeight = 48.0;

  /// 40.0 - Small button height
  static const double buttonHeightSm = 40.0;

  /// 56.0 - Large button height
  static const double buttonHeightLg = 56.0;

  /// 48.0 - Standard input field height
  static const double inputHeight = 48.0;

  // Card and media sizes

  /// 60.0 - Small thumbnail size
  static const double thumbnailSm = 60.0;

  /// 80.0 - Medium thumbnail size
  static const double thumbnailMd = 80.0;

  /// 120.0 - Large thumbnail size
  static const double thumbnailLg = 120.0;

  // Avatar sizes

  /// 32.0 - Small avatar
  static const double avatarSm = 32.0;

  /// 40.0 - Medium avatar
  static const double avatarMd = 40.0;

  /// 56.0 - Large avatar
  static const double avatarLg = 56.0;

  // Misc

  /// 1.0 - Hairline divider
  static const double dividerHeight = 1.0;

  /// 4.0 - Badge indicator size
  static const double badgeSize = 4.0;
}
