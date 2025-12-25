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
    final themeVariant = ref.watch(themeVariantProvider);

    const baseColor = Color(0xFF0E7490);

    // IDE-inspired Neon Theme (Dracula + Synthwave vibes)
    // Background tones
    const neonBg = Color(0xFF0D0D0D); // Deep black background
    const neonSurface = Color(0xFF1A1A2E); // Card/surface background
    const neonSurfaceLight = Color(0xFF252540); // Elevated surfaces

    // Syntax-inspired colors (like IDE highlighting)
    const neonCyan = Color(0xFF80FFEA); // Variables/properties - softer cyan
    const neonPink = Color(0xFFFF79C6); // Keywords/functions
    const neonGreen = Color(0xFF50FA7B); // Strings/success
    const neonPurple = Color(0xFFBD93F9); // Classes/types
    const neonOrange = Color(0xFFFFB86C); // Numbers/warnings
    const neonYellow = Color(0xFFF1FA8C); // Comments/secondary text
    const neonRed = Color(0xFFFF5555); // Errors/destructive

    // Text hierarchy
    const neonTextPrimary = Color(0xFFF8F8F2); // Main text (light off-white)
    const neonTextSecondary = Color(0xFFB4B4B4); // Secondary text
    const neonTextMuted = Color(0xFF6272A4); // Muted/comments

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

    // Neon developer theme - IDE-inspired cyberpunk aesthetic
    // Inspired by Dracula, One Dark, Synthwave themes
    final neonTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: neonPink, // Primary actions (like function keywords)
        secondary: neonPurple, // Secondary elements (like types)
        tertiary: neonGreen, // Success/tertiary (like strings)
        surface: neonSurface,
        onPrimary: neonBg,
        onSecondary: neonBg,
        onSurface: neonTextPrimary,
        outline: neonPurple.withValues(alpha: 0.3),
        error: neonRed,
        onError: neonBg,
      ),
      scaffoldBackgroundColor: neonBg,
      cardColor: neonSurface,
      cardTheme: CardThemeData(
        color: neonSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: neonPurple.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: neonBg,
        foregroundColor: neonTextPrimary,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: neonPink, // Title in pink like function names
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: neonSurface,
        selectedItemColor: neonPink, // Selected = pink (active)
        unselectedItemColor: neonTextMuted,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: const TextTheme(
        // Headlines - use pink/cyan for emphasis
        headlineLarge: TextStyle(
          color: neonTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: neonCyan, // Cyan for article titles (like variables)
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: neonTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        // Body text - readable off-white
        bodyLarge: TextStyle(color: neonTextPrimary),
        bodyMedium: TextStyle(color: neonTextSecondary),
        bodySmall: TextStyle(color: neonTextMuted),
        // Labels - muted colors
        labelLarge: TextStyle(color: neonYellow), // Labels in yellow
        labelMedium: TextStyle(color: neonTextSecondary),
        labelSmall: TextStyle(color: neonTextMuted),
      ),
      iconTheme: const IconThemeData(color: neonPurple), // Icons in purple
      dividerTheme: DividerThemeData(
        color: neonPurple.withValues(alpha: 0.15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonPink,
          foregroundColor: neonBg,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonCyan,
          side: const BorderSide(color: neonCyan),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neonSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: neonPurple.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: neonPurple.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: neonPink, width: 2),
        ),
        labelStyle: const TextStyle(color: neonTextMuted),
        hintStyle: const TextStyle(color: neonTextMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neonSurfaceLight,
        contentTextStyle: const TextStyle(color: neonTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: neonGreen.withValues(alpha: 0.5)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: neonSurfaceLight,
        labelStyle: const TextStyle(color: neonOrange), // Chips in orange
        side: BorderSide(color: neonOrange.withValues(alpha: 0.3)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: neonPink,
      ),
      // List tiles for settings
      listTileTheme: ListTileThemeData(
        iconColor: neonPurple,
        textColor: neonTextPrimary,
        subtitleTextStyle: const TextStyle(color: neonTextMuted, fontSize: 12),
      ),
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return neonGreen;
          return neonTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return neonGreen.withValues(alpha: 0.3);
          }
          return neonSurfaceLight;
        }),
      ),
    );

    // Determine which theme to use based on variant
    ThemeMode effectiveThemeMode;

    switch (themeVariant) {
      case AppThemeVariant.light:
        effectiveThemeMode = ThemeMode.light;
      case AppThemeVariant.dark:
        effectiveThemeMode = ThemeMode.dark;
      case AppThemeVariant.neon:
        effectiveThemeMode = ThemeMode.dark;
      case AppThemeVariant.system:
        effectiveThemeMode = ThemeMode.system;
    }

    return MaterialApp.router(
      title: 'Blips',
      debugShowCheckedModeBanner: false,
      theme: themeVariant == AppThemeVariant.neon ? neonTheme : lightTheme,
      darkTheme: themeVariant == AppThemeVariant.neon ? neonTheme : darkTheme,
      themeMode: effectiveThemeMode,
      routerConfig: router,
    );
  }
}
