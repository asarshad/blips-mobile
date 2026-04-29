import 'package:blips_mobile/bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry DSN — set via --dart-define=SENTRY_DSN=... at build time.
/// Left empty in debug builds to avoid noisy development reports.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isNotEmpty && !kDebugMode) {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = _sentryDsn
          ..tracesSampleRate = 0.02
          ..environment = kReleaseMode ? 'production' : 'staging';
      },
      appRunner: bootstrap,
    );
  } else {
    await bootstrap();
  }
}
