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
          ..environment = kReleaseMode ? 'production' : 'staging'
          ..beforeSend = _beforeSend;
      },
      appRunner: bootstrap,
    );
  } else {
    await bootstrap();
  }
}

/// Filters out known-noisy events that don't represent real bugs.
SentryEvent? _beforeSend(SentryEvent event, Hint hint) {
  // ignore: omit_local_variable_types — explicit type prevents dynamic inference
  for (final SentryException ex
      in event.exceptions ?? const <SentryException>[]) {
    final type = ex.type ?? '';
    final value = ex.value ?? '';

    // AdMob no-fill — not a bug, just no inventory.
    if (type.contains('LoadAdError')) return null;

    // iOS keychain locked while device screen is off (-25308).
    // Background network requests routinely hit this; it's expected.
    if (value.contains('-25308') ||
        value.contains('errSecInteractionNotAllowed') ||
        value.contains('User interaction is not allowed')) {
      return null;
    }

    // flutter_inappwebview plugin race on cold start — one-off, not actionable.
    if (type.contains('MissingPluginException') &&
        value.contains('flutter_inappwebview')) {
      return null;
    }
  }
  return event;
}
