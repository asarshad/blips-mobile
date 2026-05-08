import 'package:shared_preferences/shared_preferences.dart';

/// Determines whether and when to show the soft update nudge dialog.
///
/// Version comparison uses semver ordering on the major.minor.patch parts
/// only; build numbers (the `+N` suffix) are ignored.
class UpdateNudgeService {
  static const _dismissedKey = 'update_nudge_dismissed_for';

  /// Returns true when [currentVersion] is below [minRecommendedVersion].
  ///
  /// Both strings may include a build number suffix (e.g. "1.0.3+15");
  /// only the semver part before `+` is compared.
  /// Returns false when [minRecommendedVersion] is null or empty.
  static bool shouldShowNudge({
    required String currentVersion,
    required String? minRecommendedVersion,
  }) {
    if (minRecommendedVersion == null || minRecommendedVersion.isEmpty) {
      return false;
    }
    return _compareVersions(currentVersion, minRecommendedVersion) < 0;
  }

  /// Returns true if the user already dismissed the nudge for [version].
  static Future<bool> wasDismissedFor(
    SharedPreferences prefs,
    String version,
  ) async {
    return prefs.getString(_dismissedKey) == version;
  }

  /// Records that the nudge for [version] was dismissed so it won't re-appear.
  static Future<void> markDismissed(
    SharedPreferences prefs,
    String version,
  ) async {
    await prefs.setString(_dismissedKey, version);
  }

  /// Negative = a < b, zero = equal, positive = a > b.
  static int _compareVersions(String a, String b) {
    final aParts = _semverParts(a);
    final bParts = _semverParts(b);
    for (var i = 0; i < 3; i++) {
      final cmp = aParts[i].compareTo(bParts[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  static List<int> _semverParts(String version) {
    var base = version.split('+').first; // drop build number (e.g. "+15")
    if (base.startsWith('v') || base.startsWith('V')) base = base.substring(1);
    final parts = base.split('.').map((s) {
      return int.tryParse(s.split('-').first) ?? 0; // drop pre-release (e.g. "-beta")
    }).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }
}
