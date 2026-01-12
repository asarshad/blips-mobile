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
    final themeMode = ref.watch(themeModeProvider);

    const baseColor = Color(0xFF0E7490);
    
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFF1F5F9),
        selectedItemColor: baseColor,
        unselectedItemColor: Colors.grey,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardColor: const Color(0xFF1E293B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        selectedItemColor: baseColor,
        unselectedItemColor: Colors.grey,
      ),
    );

    return MaterialApp.router(
      title: 'Blips',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
