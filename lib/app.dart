import 'dart:async';

import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/ads/domain/ads_config.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:blips_mobile/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Root widget that wires navigation, theming, and global providers.
class BlipsApp extends ConsumerStatefulWidget {
  /// Creates the root widget.
  const BlipsApp({super.key});

  @override
  ConsumerState<BlipsApp> createState() => _BlipsAppState();
}

class _BlipsAppState extends ConsumerState<BlipsApp> {
  ProviderSubscription<AsyncValue<AdsConfig>>? _adsConfigSubscription;

  @override
  void initState() {
    super.initState();
    _adsConfigSubscription = ref.listenManual<AsyncValue<AdsConfig>>(
      adsConfigProvider,
      (
        previous,
        next,
      ) {
        final adsConfig = next.valueOrNull;
        if (adsConfig == null) {
          return;
        }
        unawaited(
          ref.read(adMobInitializerProvider).ensureInitialized(
                runtimeConfig: ref.read(adsRuntimeConfigProvider),
                adsConfig: adsConfig,
              ),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _adsConfigSubscription?.close();
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
    );
  }
}
