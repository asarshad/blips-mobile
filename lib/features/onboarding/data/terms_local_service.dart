/// Local persistence for the Terms of Use acceptance gate.
///
/// Apple requires apps with user-generated content (including AI chat
/// input) to obtain explicit user agreement to terms that prohibit
/// objectionable content. We store a single bool flag in SharedPreferences
/// — once set, the gate never shows again.
library;

import 'package:shared_preferences/shared_preferences.dart';

class TermsLocalService {
  /// Bumped to v2 if the Terms text materially changes and we need
  /// existing users to re-accept.
  static const _termsAcceptedKey = 'blips_terms_accepted_v1';

  /// Returns true if the user has accepted the current Terms revision.
  Future<bool> isAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_termsAcceptedKey) ?? false;
    } catch (_) {
      // If we can't read, treat as not accepted so the gate shows.
      return false;
    }
  }

  /// Records the user's acceptance.
  Future<void> markAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_termsAcceptedKey, true);
    } catch (_) {
      // Non-critical: gate may show again on next launch, which is
      // acceptable failure mode.
    }
  }
}
