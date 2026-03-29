import 'package:url_launcher/url_launcher.dart';

/// Utility for launching external URLs in the system browser.
class ExternalUrlLauncher {
  const ExternalUrlLauncher._();

  /// Launches [uri] in an external application (e.g. Safari).
  /// Returns `true` if the URL was successfully launched.
  static Future<bool> launchUri(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
