import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ensures Flutter bindings are ready before attaching the ProviderScope.
///
/// Sets up:
/// - Global error handling (FlutterError.onError, PlatformDispatcher)
/// - Splash screen preservation
/// - Riverpod provider scope
/// - Stale cache cleanup
Future<void> bootstrap() async {
  await runWithGlobalErrorHandling(() async {
    // Preserve splash screen until we explicitly remove it
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);

    // Lock to portrait even though Info.plist declares all orientations
    // (required for iPad multitasking / TestFlight validation).
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    logger.info('App starting...', category: LogCategory.lifecycle);

    // Clean up very old cache on app start (older than 7 days)
    // Prevents unbounded growth; freshness is handled by background refresh
    try {
      await FeedCache.instance.clearStale(
        maxAge: const Duration(days: 7),
      );
    } catch (e) {
      logger.warning(
        'Failed to clear stale cache',
        category: LogCategory.app,
        error: e,
      );
    }

    runApp(
      const ProviderScope(
        child: BlipsApp(),
      ),
    );

    // Remove splash screen after app has started
    FlutterNativeSplash.remove();

    logger.info('App started successfully', category: LogCategory.lifecycle);
  });
}

/// Test-friendly bootstrap that allows overriding providers.
///
/// Production code should continue calling [bootstrap].
Future<void> bootstrapWithOverrides({
  List<Override> overrides = const [],
}) async {
  await runWithGlobalErrorHandling(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: binding);

    runApp(
      ProviderScope(
        overrides: overrides,
        child: const BlipsApp(),
      ),
    );

    FlutterNativeSplash.remove();
  });
}
