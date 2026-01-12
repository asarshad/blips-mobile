import 'package:blips_mobile/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ensures Flutter bindings are ready before attaching the ProviderScope.
Future<void> bootstrap() async {
  // Preserve splash screen until we explicitly remove it
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  runApp(
    const ProviderScope(
      child: BlipsApp(),
    ),
  );

  // Remove splash screen after app has started
  FlutterNativeSplash.remove();
}
