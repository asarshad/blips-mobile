import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings surface for feature toggles and account controls.
class SettingsPage extends ConsumerWidget {
  /// Creates the settings placeholder.
  const SettingsPage({super.key});

  /// Router path for settings.
  static const path = '/settings';

  /// Router name for settings.
  static const name = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: const [
          _SettingsTile(title: 'Theme', value: 'System default'),
          Divider(),
          _SettingsTile(title: 'Notifications', value: 'Enabled'),
          Divider(),
          _SettingsTile(title: 'Account', value: 'Signed in via Supabase'),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
