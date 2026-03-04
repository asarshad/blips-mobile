import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:blips_mobile/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Root widget that wires navigation, theming, and global providers.
class BlipsApp extends ConsumerWidget {
  /// Creates the root widget.
  const BlipsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
