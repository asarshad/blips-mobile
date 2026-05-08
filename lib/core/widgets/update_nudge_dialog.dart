import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Soft update nudge shown when the running version is below the server's
/// recommended minimum.  The user can dismiss it ("Not Now") or tap "Update"
/// to open the appropriate store listing.
class UpdateNudgeDialog extends StatelessWidget {
  const UpdateNudgeDialog({super.key, this.storeUrl});

  /// App Store / Play Store URL to open when the user taps "Update".
  /// When null or empty, the Update button is omitted and the user can only
  /// dismiss.
  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    final hasStoreUrl = storeUrl != null && storeUrl!.isNotEmpty;

    return AlertDialog(
      title: const Text('Update Available'),
      content: const Text(
        'A new version of Blips is available with the latest features and bug fixes.',
      ),
      actions: [
        TextButton(
          // true = user explicitly dismissed; caller uses this to suppress
          // future nudges for this version.
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Not Now'),
        ),
        if (hasStoreUrl)
          FilledButton(
            // false = user is going to update; don't suppress future nudges
            // in case they return without actually updating.
            onPressed: () => _openStore(context),
            child: const Text('Update'),
          ),
      ],
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.tryParse(storeUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.of(context).pop(false);
  }
}
