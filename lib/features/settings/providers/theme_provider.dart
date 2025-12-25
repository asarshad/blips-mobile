import 'package:flutter/material.dart';import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom theme variants beyond system light/dark
enum AppThemeVariant {
  system,
  light,
  dark,
  neon,
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Provider for the current theme variant (includes neon)
final themeVariantProvider =
    StateNotifierProvider<ThemeVariantNotifier, AppThemeVariant>((ref) {
  return ThemeVariantNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  static const _key = 'theme_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.toString() == saved,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.toString());
  }
}

class ThemeVariantNotifier extends StateNotifier<AppThemeVariant> {
  ThemeVariantNotifier() : super(AppThemeVariant.system) {
    _loadVariant();
  }

  static const _key = 'theme_variant';

  Future<void> _loadVariant() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = AppThemeVariant.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeVariant.system,
      );
    }
  }

  Future<void> setVariant(AppThemeVariant variant) async {
    state = variant;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, variant.name);
    
    // Update app icon based on theme (iOS only)
    await _updateAppIcon(variant);
  }
  
  Future<void> _updateAppIcon(AppThemeVariant variant) async {
    try {
      // Check if alternate icons are supported (iOS only, not simulator)
      final supportsAlternateIcons = await FlutterDynamicIcon.supportsAlternateIcons;
      if (!supportsAlternateIcons) {
        debugPrint('Alternate icons not supported on this device');
        return;
      }
      
      // Map theme variant to icon name
      // null = default icon, "Neon" = neon icon (must match Info.plist key)
      final iconName = variant == AppThemeVariant.neon ? 'Neon' : null;
      
      await FlutterDynamicIcon.setAlternateIconName(iconName);
      debugPrint('App icon changed to: ${iconName ?? 'default'}');
    } catch (e) {
      debugPrint('Failed to change app icon: $e');
    }
  }
}
