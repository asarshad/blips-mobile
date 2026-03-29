import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/core/database/database_helper.dart';
import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/core/services/device_id_service.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/ads/domain/ads_runtime_config.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:blips_mobile/features/notifications/providers/push_notification_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Check if running in debug/dev mode
const bool kIsDevMode = !kReleaseMode;
const _privacyUrl = 'https://blips.tech/privacy.html';
const _termsUrl = 'https://blips.tech/terms.html';
const _supportUrl = 'https://blips.tech/support.html';

bool _isAndroidUi(BuildContext context) =>
    !kIsWeb && Theme.of(context).platform == TargetPlatform.android;

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
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final adsRuntimeConfig = ref.watch(adsRuntimeConfigProvider);
    final diagnostics = ref.watch(appDiagnosticsProvider);
    final diagnosticsConfig = ref.watch(appDiagnosticsConfigProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isAndroidUi = _isAndroidUi(context);
    final listView = ListView(
      padding: EdgeInsets.fromLTRB(
        isAndroidUi ? AppSpacing.md : AppSpacing.lg,
        isAndroidUi ? AppSpacing.md : AppSpacing.lg,
        isAndroidUi ? AppSpacing.md : AppSpacing.lg,
        isAndroidUi ? AppSpacing.lg : AppSpacing.xl,
      ),
      children: [
        _SettingsHero(
          selectedMode: themeMode,
          platformBrightness: platformBrightness,
          onModeSelected: themeModeNotifier.setThemeMode,
        ),
        SizedBox(height: isAndroidUi ? AppSpacing.lg : AppSpacing.xl),
        _SettingsSectionCard(
          title: 'Storage & privacy',
          subtitle: 'Control what lives on this device and what gets reset '
              'on our servers.',
          child: Column(
            children: [
              _SettingsActionTile(
                title: 'Clear Chat History',
                subtitle: 'Delete all local conversations',
                icon: Icons.delete_outline,
                accentColor: Theme.of(context).colorScheme.error,
                onTap: () async {
                  final colorScheme = Theme.of(context).colorScheme;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear History?'),
                      content: const Text(
                        'This will permanently delete all your chat '
                        'conversations from this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed ?? false) {
                    await DatabaseHelper.instance.deleteAllChats();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat history cleared')),
                      );
                    }
                  }
                },
              ),
              const _SectionDivider(),
              _SettingsActionTile(
                title: 'Delete My Data',
                subtitle: 'Delete usage quota & preferences from our servers',
                icon: Icons.delete_forever,
                accentColor: Theme.of(context).colorScheme.error,
                onTap: () => _confirmDeleteMyData(context, ref),
              ),
            ],
          ),
        ),
        SizedBox(height: isAndroidUi ? AppSpacing.lg : AppSpacing.xl),
        _SettingsSectionCard(
          title: 'Policies & support',
          subtitle: 'Open the public pages and support routes hosted '
              'on blips.tech.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 360 ? 3 : 2;
              final itemWidth =
                  (constraints.maxWidth - (AppSpacing.md * (columns - 1))) /
                      columns;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SettingsShortcutCard(
                      title: 'Privacy',
                      subtitle: 'Data handling',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () => _launchUrl(_privacyUrl),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SettingsShortcutCard(
                      title: 'Terms',
                      subtitle: 'Usage rules',
                      icon: Icons.description_outlined,
                      onTap: () => _launchUrl(_termsUrl),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SettingsShortcutCard(
                      title: 'Support',
                      subtitle: 'Get help',
                      icon: Icons.support_agent_rounded,
                      onTap: () => _launchUrl(_supportUrl),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (adsRuntimeConfig.showTestingTools) ...[
          SizedBox(height: isAndroidUi ? AppSpacing.lg : AppSpacing.xl),
          _SettingsSectionCard(
            title: 'Ads testing',
            subtitle: 'This build is configured for local ad validation.',
            child: Column(
              children: [
                _SettingsActionTile(
                  title: 'Ads mode',
                  subtitle:
                      '${adsRuntimeConfig.displayName}${adsRuntimeConfig.shouldForceFeedAds ? ' · forced slots' : ''}',
                  icon: adsRuntimeConfig.usesMockAds
                      ? Icons.draw_outlined
                      : Icons.verified_outlined,
                  onTap: null,
                ),
                if (adsRuntimeConfig.mode == AdsMode.admobTest) ...[
                  const _SectionDivider(),
                  _SettingsActionTile(
                    title: 'Open Ad Inspector',
                    subtitle: adsRuntimeConfig.testDeviceIds.isEmpty
                        ? 'Launch the Google inspector if this device is registered as a test device.'
                        : 'Launch the Google inspector for this registered test device.',
                    icon: Icons.ad_units_rounded,
                    onTap: () => _openAdInspector(context),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (diagnosticsConfig.enabled) ...[
          SizedBox(height: isAndroidUi ? AppSpacing.lg : AppSpacing.xl),
          _SettingsSectionCard(
            title: 'Diagnostics',
            subtitle: 'Structured app traces for refresh, pagination, and '
                'feed recovery.',
            child: Column(
              children: [
                _SettingsActionTile(
                  title: 'Diagnostics status',
                  subtitle:
                      '${diagnostics.count} events buffered${diagnostics.latest == null ? '' : ' · latest ${diagnostics.latest!.action}/${diagnostics.latest!.stage}'}',
                  icon: Icons.bug_report_outlined,
                  onTap: null,
                ),
                const _SectionDivider(),
                _SettingsActionTile(
                  title: 'Copy diagnostics log',
                  subtitle:
                      'Copies the latest app trace lines for sharing or review.',
                  icon: Icons.copy_all_outlined,
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: diagnostics.exportText(limit: 120),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Diagnostics copied to clipboard'),
                        ),
                      );
                    }
                  },
                ),
                const _SectionDivider(),
                _SettingsActionTile(
                  title: 'Clear diagnostics',
                  subtitle: 'Clears the in-memory diagnostics buffer.',
                  icon: Icons.delete_sweep_outlined,
                  onTap: () {
                    diagnostics.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Diagnostics cleared'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
        if (kIsDevMode) ...[
          SizedBox(height: isAndroidUi ? AppSpacing.lg : AppSpacing.xl),
          _SettingsSectionCard(
            title: 'Build info',
            subtitle: 'Debug-only details for local testing.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 360 ? 2 : 1;
                final itemWidth =
                    (constraints.maxWidth - (AppSpacing.md * (columns - 1))) /
                        columns;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: const _InfoCard(
                        title: 'App Version',
                        value: '1.0.0 (Dev Build)',
                        icon: Icons.info_outline,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: const _InfoCard(
                        title: 'Author',
                        value: 'Asif Arshad',
                        icon: Icons.person_outline,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: const _InfoCard(
                        title: 'Framework',
                        value: 'Flutter 3.x',
                        icon: Icons.flutter_dash,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: const _InfoCard(
                        title: 'State',
                        value: 'Riverpod + Hooks',
                        icon: Icons.account_tree_outlined,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: const _InfoCard(
                        title: 'Backend',
                        value: 'FastAPI + PostgreSQL',
                        icon: Icons.cloud_outlined,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: const _InfoCard(
                        title: 'Video Player',
                        value: 'youtube iframe',
                        icon: Icons.play_circle_outline,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: isAndroidUi
          ? MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1, child: listView)
          : listView,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openAdInspector(BuildContext context) async {
    MobileAds.instance.openAdInspector((error) {
      if (!context.mounted || error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ad Inspector failed: ${error.message}')),
      );
    });
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
      await ref
          .read(pushNotificationsControllerProvider)
          .unregisterCurrentSubscription();

      // 1. Call the server deletion endpoint
      final dio = ref.read(dioProvider);
      await dio.delete<void>('/session/data');

      // 2. Clear local SQLite chat history
      await DatabaseHelper.instance.deleteAllChats();

      // 3. Reset the persisted device ID so a fresh one is generated
      await resetDeviceId();
      ref.invalidate(deviceIdProvider);
      ref.invalidate(deviceAuthBundleProvider);

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

class _ThemeModeMeta {
  const _ThemeModeMeta({
    required this.title,
    required this.summary,
    required this.description,
    required this.icon,
  });

  factory _ThemeModeMeta.from(
    AppThemeMode value,
    Brightness platformBrightness,
  ) {
    return switch (value) {
      AppThemeMode.system => _ThemeModeMeta(
          title: 'System',
          summary: platformBrightness == Brightness.dark
              ? 'Auto · dark now'
              : 'Auto · light now',
          description: 'Matches the phone setting and flips automatically '
              'as the OS changes.',
          icon: Icons.brightness_auto_rounded,
        ),
      AppThemeMode.light => const _ThemeModeMeta(
          title: 'Light',
          summary: 'Bright feed',
          description: 'Crisp cards and open surfaces for daytime reading '
              'and browsing.',
          icon: Icons.wb_sunny_rounded,
        ),
      AppThemeMode.dark => const _ThemeModeMeta(
          title: 'Dark',
          summary: 'Editorial night',
          description: 'Navy surfaces that stay comfortable in low light '
              'without losing contrast.',
          icon: Icons.dark_mode_rounded,
        ),
      AppThemeMode.neon => const _ThemeModeMeta(
          title: 'Neon',
          summary: 'Signal mode',
          description: 'Charcoal with electric accents for a sharper, '
              'higher-signal look.',
          icon: Icons.bolt_rounded,
        ),
    };
  }

  final String title;
  final String summary;
  final String description;
  final IconData icon;
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({
    required this.selectedMode,
    required this.platformBrightness,
    required this.onModeSelected,
  });

  final AppThemeMode selectedMode;
  final Brightness platformBrightness;
  final ValueChanged<AppThemeMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final isAndroidUi = _isAndroidUi(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding:
          isAndroidUi ? const EdgeInsets.all(AppSpacing.md) : AppSpacing.allLg,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(isAndroidUi ? 22 : 26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Appearance',
                style:
                    (isAndroidUi ? textTheme.titleMedium : textTheme.titleLarge)
                        ?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: isAndroidUi ? AppSpacing.sm : AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 280 ? 4 : 2;
              final tileGap = isAndroidUi ? AppSpacing.xs : AppSpacing.sm;
              final itemWidth =
                  (constraints.maxWidth - (tileGap * (columns - 1))) / columns;
              return Wrap(
                spacing: tileGap,
                runSpacing: tileGap,
                children: [
                  for (final mode in AppThemeMode.values)
                    SizedBox(
                      width: itemWidth,
                      child: _ThemeModeChoiceCard(
                        value: mode,
                        isSelected: mode == selectedMode,
                        platformBrightness: platformBrightness,
                        onTap: () => onModeSelected(mode),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAndroidUi = _isAndroidUi(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Container(
      padding:
          isAndroidUi ? const EdgeInsets.all(AppSpacing.md) : AppSpacing.allLg,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(isAndroidUi ? 22 : 26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: (isAndroidUi ? textTheme.titleMedium : textTheme.titleLarge)
                ?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: (isAndroidUi ? textTheme.bodySmall : textTheme.bodyMedium)
                ?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          SizedBox(height: isAndroidUi ? AppSpacing.md : AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Divider(
        height: 1,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isAndroidUi = _isAndroidUi(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accent = accentColor ?? colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: isAndroidUi ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: isAndroidUi ? 40 : 46,
                height: isAndroidUi ? 40 : 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (isAndroidUi
                              ? textTheme.bodyMedium
                              : textTheme.titleMedium)
                          ?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (onTap != null)
                Icon(
                  Icons.arrow_outward_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                  size: AppSizes.iconSm,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsShortcutCard extends StatelessWidget {
  const _SettingsShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAndroidUi = _isAndroidUi(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(isAndroidUi ? AppSpacing.sm : AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isAndroidUi ? 34 : 38,
                height: isAndroidUi ? 34 : 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.primary,
                  size: AppSizes.iconSm,
                ),
              ),
              SizedBox(height: isAndroidUi ? AppSpacing.sm : AppSpacing.md),
              Text(
                title,
                style:
                    (isAndroidUi ? textTheme.bodySmall : textTheme.titleSmall)
                        ?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeChoiceCard extends StatelessWidget {
  const _ThemeModeChoiceCard({
    required this.value,
    required this.isSelected,
    required this.platformBrightness,
    required this.onTap,
  });

  final AppThemeMode value;
  final bool isSelected;
  final Brightness platformBrightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAndroidUi = _isAndroidUi(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final meta = _ThemeModeMeta.from(value, platformBrightness);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${meta.title} theme',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isAndroidUi ? 16 : 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.fromLTRB(
              isAndroidUi ? 6 : AppSpacing.xs,
              isAndroidUi ? 6 : AppSpacing.xs,
              isAndroidUi ? 6 : AppSpacing.xs,
              isAndroidUi ? 6 : AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : theme.cardColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(isAndroidUi ? 16 : 18),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.45),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: isAndroidUi ? 44 : 54,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isAndroidUi ? 10 : 12),
                    child: IgnorePointer(
                      child: _ThemeModeTilePreview(
                        value: value,
                        platformBrightness: platformBrightness,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isAndroidUi ? AppSpacing.xs : AppSpacing.sm),
                Text(
                  meta.title,
                  textAlign: TextAlign.center,
                  style: (isAndroidUi
                          ? textTheme.labelLarge
                          : textTheme.titleSmall)
                      ?.copyWith(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeTilePreview extends StatelessWidget {
  const _ThemeModeTilePreview({
    required this.value,
    required this.platformBrightness,
  });

  final AppThemeMode value;
  final Brightness platformBrightness;

  @override
  Widget build(BuildContext context) {
    if (value == AppThemeMode.system) {
      return const _SystemThemeTilePreview();
    }

    final palette = switch (value) {
      AppThemeMode.light => _ThemePreviewPalette.fromTheme(AppTheme.light()),
      AppThemeMode.dark => _ThemePreviewPalette.fromTheme(AppTheme.dark()),
      AppThemeMode.neon => _ThemePreviewPalette.fromTheme(AppTheme.neon()),
      AppThemeMode.system => throw UnimplementedError(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final outerPadding = constraints.maxHeight < 50 ? 4.0 : 6.0;
        final headerHeight = constraints.maxHeight < 50 ? 5.0 : 7.0;
        final headerGap = constraints.maxHeight < 50 ? 4.0 : 6.0;
        final innerPadding = constraints.maxHeight < 50 ? 4.0 : 6.0;
        final lineHeight = constraints.maxHeight < 50 ? 3.0 : 4.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Column(
              children: [
                Container(
                  height: headerHeight,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: palette.border.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                SizedBox(height: headerGap),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(innerPadding),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: palette.border.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 18,
                            height: lineHeight,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: lineHeight,
                                decoration: BoxDecoration(
                                  color: palette.surfaceAlt,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                              ),
                              SizedBox(height: lineHeight - 1),
                              FractionallySizedBox(
                                widthFactor: 0.58,
                                child: Container(
                                  height: lineHeight,
                                  decoration: BoxDecoration(
                                    color: palette.textMuted
                                        .withValues(alpha: 0.32),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SystemThemeTilePreview extends StatelessWidget {
  const _SystemThemeTilePreview();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Stack(
          children: [
            Positioned(
              top: 1,
              left: 1,
              right: 18,
              bottom: 15,
              child: Transform.rotate(
                angle: -0.04,
                child: const _SystemMiniCard(isDark: false),
              ),
            ),
            Positioned(
              top: 14,
              left: 16,
              right: 1,
              bottom: 1,
              child: Transform.rotate(
                angle: 0.04,
                child: const _SystemMiniCard(isDark: true),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.brightness_auto_rounded,
                  size: 9,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMiniCard extends StatelessWidget {
  const _SystemMiniCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final background = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFD5DEE8);
    final strong = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted =
        isDark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFF94A3B8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxHeight < 28 ? 3.0 : 4.0;
        final headerHeight = constraints.maxHeight < 28 ? 4.0 : 5.0;
        final gap = constraints.maxHeight < 28 ? 3.0 : 4.0;
        final lineHeight = constraints.maxHeight < 28 ? 2.0 : 3.0;

        return Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              Container(
                height: headerHeight,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: EdgeInsets.all(padding),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          width: 12,
                          height: lineHeight,
                          decoration: BoxDecoration(
                            color: strong,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          height: lineHeight,
                          decoration: BoxDecoration(
                            color: muted,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemePreviewPalette {
  const _ThemePreviewPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.textMuted,
    required this.border,
  });

  factory _ThemePreviewPalette.fromTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return _ThemePreviewPalette(
      background: theme.scaffoldBackgroundColor,
      surface: theme.cardColor,
      surfaceAlt: colorScheme.surfaceContainerHighest,
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      text: colorScheme.onSurface,
      textMuted: colorScheme.onSurfaceVariant,
      border: colorScheme.outlineVariant,
    );
  }

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color textMuted;
  final Color border;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isAndroidUi = _isAndroidUi(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Container(
      padding: EdgeInsets.all(isAndroidUi ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isAndroidUi ? 32 : 36,
            height: isAndroidUi ? 32 : 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: AppSizes.iconSm,
            ),
          ),
          SizedBox(height: isAndroidUi ? AppSpacing.sm : AppSpacing.md),
          Text(
            title,
            style: (isAndroidUi ? textTheme.labelSmall : textTheme.bodySmall)
                ?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
