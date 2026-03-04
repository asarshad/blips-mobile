/// Local persistence for user category interests.
///
/// Stores two keys in SharedPreferences:
///   - [_interestsKey]: JSON-encoded list of selected category IDs.
///   - [_onboardingDoneKey]: bool flag – true once the user has seen and
///     dismissed (or completed) the interest selection screen.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Manages local persistence of the user's selected categories.
class InterestsLocalService {
  static const _interestsKey = 'blips_interests_v1';
  static const _onboardingDoneKey = 'blips_onboarding_done';

  // ─── Interests ────────────────────────────────────────────────────────────

  /// Returns the persisted list of category IDs, or an empty list.
  Future<List<String>> loadSelectedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_interestsKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Persists [categories] to local storage.
  Future<void> saveSelectedCategories(List<String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_interestsKey, jsonEncode(categories));
    } catch (_) {
      // Swallow — local write failure is non-critical.
    }
  }

  // ─── Onboarding gate ──────────────────────────────────────────────────────

  /// Returns true if the user has already seen the onboarding screen.
  Future<bool> isOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingDoneKey) ?? false;
    } catch (_) {
      // If we can't read, show onboarding rather than silently skipping it.
      return false;
    }
  }

  /// Marks onboarding as completed so the screen is never shown again.
  Future<void> markOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingDoneKey, true);
    } catch (_) {
      // Non-critical.
    }
  }
}
