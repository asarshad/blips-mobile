import 'package:blips_mobile/core/database/database_helper.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:dio/dio.dart';
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
        padding: AppSpacing.allLg,
        children: [
          _SectionHeader(title: 'APPEARANCE'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
              side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _ThemeRadioTile(
                  title: 'System Default',
                  value: AppThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _ThemeRadioTile(
                  title: 'Light Mode',
                  value: AppThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _ThemeRadioTile(
                  title: 'Dark Mode',
                  value: AppThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _ThemeRadioTile(
                  title: 'Neon',
                  value: AppThemeMode.neon,
                  groupValue: themeMode,
                  onChanged: (val) =>
                      ref.read(themeModeProvider.notifier).setThemeMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(title: 'DATA & STORAGE'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
              side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _SettingsTile(
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
                            style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error),
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
                Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _SettingsTile(
                  title: 'Delete My Data',
                  subtitle: 'Delete usage quota & preferences from our servers',
                  icon: Icons.delete_forever,
                  iconColor: colorScheme.error,
                  onTap: () => _confirmDeleteMyData(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(title: 'LEGAL'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderLg,
              side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => _launchUrl('https://husniconsulting.ca/privacy'),
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _SettingsTile(
                  title: 'Terms of Service',
                  icon: Icons.description_outlined,
                  onTap: () => _launchUrl('https://husniconsulting.ca/terms'),
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                _SettingsTile(
                  title: 'Support',
                  subtitle: 'info@husniconsulting.ca',
                  icon: Icons.help_outline,
                  onTap: () => _launchUrl('https://husniconsulting.ca/support'),
                ),
              ],
            ),
          ),

          // About section - only visible in dev/debug mode
          if (kIsDevMode) ...[
            const SizedBox(height: AppSpacing.xl),
            _SectionHeader(title: 'ABOUT (DEV)'),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderLg,
                side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _AboutTile(
                    title: 'App Version',
                    value: '1.0.0 (Dev Build)',
                    icon: Icons.info_outline,
                  ),
                  Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Author',
                    value: 'Asif Arshad',
                    icon: Icons.person_outline,
                  ),
                  Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Framework',
                    value: 'Flutter 3.x',
                    icon: Icons.flutter_dash,
                  ),
                  Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'State Management',
                    value: 'Riverpod + Hooks',
                    icon: Icons.account_tree_outlined,
                  ),
                  Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Backend',
                    value: 'FastAPI + PostgreSQL',
                    icon: Icons.cloud_outlined,
                  ),
                  Divider(
                      height: 1,
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _AboutTile(
                    title: 'Video Player',
                    value: 'youtube_player_flutter (iframe)',
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

  Future<void> _confirmDeleteMyData(BuildContext context, WidgetRef ref) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete My Data?'),
        content: const Text(
          'This will permanently delete your usage quota and AI preferences '
          'from our servers, and clear all local chat conversations. '
          'Chat transcripts are stored only on this device — they are never '
          'sent to or saved on our servers. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // 1. Call the server deletion endpoint
      final dio = ref.read(dioProvider);
      await dio.delete('/session/data');

      // 2. Clear local SQLite chat history
      await DatabaseHelper.instance.deleteAllChats();

      // 3. Reset the persisted device ID so a fresh one is generated
      await resetDeviceId();
      ref.invalidate(deviceIdProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully')),
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        final status = e.response?.statusCode;
        final msg = status == 429
            ? 'Too many requests. Please wait a moment and try again.'
            : 'Failed to delete server data. Please try again later.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding:
          const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.lg),
      child: Text(
        title,
        style: textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxs,
      ),
      leading: Icon(
        icon,
        color: iconColor ?? colorScheme.onSurfaceVariant,
        size: AppSizes.iconMd,
      ),
      title: Text(
        title,
        style: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: AppSizes.iconSm,
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
  final AppThemeMode value;
  final AppThemeMode groupValue;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: colorScheme.primary,
                size: AppSizes.iconSm,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary.withValues(alpha: 0.7),
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
