import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/feed/data/feed_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

    await _initializeAdMob();

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

    // Record start time for minimum splash duration
    final splashStart = DateTime.now();

    runApp(
      const ProviderScope(
        child: BlipsApp(),
      ),
    );

    // Remove splash after first frame AND a minimum 1 second total duration.
    // This prevents the brief blank-frame flash and ensures the splash is
    // visible long enough to be perceived.
    binding.addPostFrameCallback((_) async {
      final elapsed = DateTime.now().difference(splashStart);
      const minDuration = Duration(seconds: 1);
      if (elapsed < minDuration) {
        await Future<void>.delayed(minDuration - elapsed);
      }
      FlutterNativeSplash.remove();
    });

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

    await _initializeAdMob();

    runApp(
      ProviderScope(
        overrides: overrides,
        child: const BlipsApp(),
      ),
    );

    FlutterNativeSplash.remove();
  });
}

Future<void> _initializeAdMob() async {
  try {
    await MobileAds.instance.initialize();
    logger.info('AdMob initialized', category: LogCategory.lifecycle);
  } catch (e, stackTrace) {
    logger.warning(
      'AdMob initialization failed',
      category: LogCategory.app,
      error: e,
      stackTrace: stackTrace,
    );
  }
}
