import 'dart:async';
import 'dart:io';

import 'package:blips_mobile/core/config/remote_app_config.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/services/update_nudge_service.dart';
import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/core/widgets/update_nudge_dialog.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:blips_mobile/routes/app_router.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root widget that wires navigation, theming, and global providers.
class BlipsApp extends ConsumerStatefulWidget {
  /// Creates the root widget.
  const BlipsApp({super.key});

  @override
  ConsumerState<BlipsApp> createState() => _BlipsAppState();
}

class _BlipsAppState extends ConsumerState<BlipsApp> {
  ProviderSubscription<AsyncValue<AdsConfig>>? _adsConfigSubscription;
  ProviderSubscription<AsyncValue<RemoteAppConfig>>? _remoteConfigSubscription;

  /// Guards against duplicate dialogs when the provider emits multiple times
  /// (cache hit → network refresh → invalidate) before the async work finishes.
  bool _nudgeScheduled = false;

  @override
  void initState() {
    super.initState();
    _adsConfigSubscription = ref.listenManual<AsyncValue<AdsConfig>>(
      adsConfigProvider,
      (previous, next) {
        final adsConfig = next.valueOrNull;
        if (adsConfig == null) return;
        unawaited(
          ref.read(adMobInitializerProvider).ensureInitialized(
                runtimeConfig: ref.read(adsRuntimeConfigProvider),
                adsConfig: adsConfig,
              ),
        );
      },
      fireImmediately: true,
    );

    _remoteConfigSubscription = ref.listenManual<AsyncValue<RemoteAppConfig>>(
      remoteAppConfigProvider,
      (previous, next) {
        final config = next.valueOrNull;
        if (config == null) return;
        _scheduleUpdateNudgeIfNeeded(config);
      },
      fireImmediately: true,
    );
  }

  /// Defers the version check until after the first frame so the navigator is
  /// fully initialised.  The [_nudgeScheduled] guard ensures at most one dialog
  /// per session even when [remoteAppConfigProvider] emits several times.
  void _scheduleUpdateNudgeIfNeeded(RemoteAppConfig config) {
    final minVersion = config.minRecommendedVersion;
    if (minVersion == null || _nudgeScheduled) return;
    _nudgeScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final packageInfo = await PackageInfo.fromPlatform();
      if (!UpdateNudgeService.shouldShowNudge(
        currentVersion: packageInfo.version,
        minRecommendedVersion: minVersion,
      )) return;

      final prefs = await SharedPreferences.getInstance();
      if (await UpdateNudgeService.wasDismissedFor(prefs, minVersion)) return;

      // Use the router's navigator key so we have a context that is inside the
      // Navigator tree.  _BlipsAppState's own context is above MaterialApp.router
      // and has no Navigator ancestor.
      final navContext =
          ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;

      final storeUrl =
          Platform.isIOS ? config.iosAppStoreUrl : config.androidPlayStoreUrl;

      final dismissed = await showDialog<bool>(
        context: navContext,
        barrierDismissible: true,
        builder: (_) => UpdateNudgeDialog(storeUrl: storeUrl),
      );

      // Only suppress future nudges for this version when the user explicitly
      // tapped "Not Now".  If they tapped "Update" (or dismissed via barrier)
      // we leave the flag unset so the nudge reappears on the next launch if
      // they return without actually updating.
      if (dismissed == true) {
        try {
          await UpdateNudgeService.markDismissed(prefs, minVersion);
        } catch (e, stack) {
          logger.warning(
            'Failed to persist update nudge dismissal',
            category: LogCategory.app,
            error: e,
            stackTrace: stack,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _adsConfigSubscription?.close();
    _remoteConfigSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final router = ref.watch(appRouterProvider);
    final appThemeMode = ref.watch(themeModeProvider);

    // Neon mode: uses ThemeMode.dark but supplies the neon ThemeData.
    final darkTheme =
        appThemeMode == AppThemeMode.neon ? AppTheme.neon() : AppTheme.dark();

    return MaterialApp.router(
      title: 'Blips News',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: darkTheme,
      themeMode: appThemeMode.materialMode,
      routerConfig: router,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
