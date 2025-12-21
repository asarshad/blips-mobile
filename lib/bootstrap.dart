import 'package:blips_mobile/app.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Ensures Flutter bindings are ready before attaching the ProviderScope.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: BlipsApp(),
    ),
  );
}
