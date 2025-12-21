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

    const baseColor = Color(0xFF0E7490);
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
      ),
    );
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'Blips',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
