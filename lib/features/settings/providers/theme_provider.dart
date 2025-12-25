import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
  }
}
