import 'package:blips_mobile/core/database/database_helper.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Check if running in debug/dev mode
const bool kIsDevMode = !kReleaseMode;

/// Settings surface for feature toggles and account controls.
class SettingsPage extends ConsumerWidget {
  /// Creates the settings page.
  const SettingsPage({super.key});

  /// Router path for settings.
  static const path = '/settings';

  /// Router name for settings.
  static const name = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'APPEARANCE'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _ThemeRadioTile(
                  title: 'System Default',
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _ThemeRadioTile(
                  title: 'Light Mode',
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _ThemeRadioTile(
                  title: 'Dark Mode',
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'DATA & STORAGE'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: _SettingsTile(
              title: 'Clear Chat History',
              subtitle: 'Delete all local conversations',
              icon: Icons.delete_outline,
              iconColor: colorScheme.error,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text(
                      'This will permanently delete all your chat conversations from this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await DatabaseHelper.instance.deleteAllChats();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chat history cleared')),
                    );
                  }
                }
              },
            ),
          ),

          // About section - only visible in dev/debug mode
          if (kIsDevMode) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: 'ABOUT (DEV)'),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _AboutTile(
                    title: 'App Version',
                    value: '1.0.0 (Dev Build)',
                    icon: Icons.info_outline,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Author',
                    value: 'Asif Arshad',
                    icon: Icons.person_outline,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Framework',
                    value: 'Flutter 3.x',
                    icon: Icons.flutter_dash,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'State Management',
                    value: 'Riverpod + Hooks',
                    icon: Icons.account_tree_outlined,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Backend',
                    value: 'FastAPI + PostgreSQL',
                    icon: Icons.cloud_outlined,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Video Player',
                    value: 'video_player + youtube_explode',
                    icon: Icons.play_circle_outline,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        icon,
        color: iconColor ?? colorScheme.onSurfaceVariant,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _ThemeRadioTile extends StatelessWidget {
  const _ThemeRadioTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
