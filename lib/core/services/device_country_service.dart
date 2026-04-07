import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:hooks_riverpod/hooks_riverpod.dart';

final _countryCodePattern = RegExp(r'^[A-Z]{2}$');

/// Provides a coarse, permission-free country signal from the device locale.
///
/// This reflects the device's configured region rather than GPS location.
final deviceCountryCodeProvider = Provider<String?>((ref) {
  return loadDeviceCountryCode();
});

/// Resolves a normalized ISO 3166-1 alpha-2 country code when available.
String? loadDeviceCountryCode({
  Locale? locale,
  String? languageTag,
}) {
  final resolvedLocale = locale ?? PlatformDispatcher.instance.locale;
  final directCountry = normalizeCountryCode(resolvedLocale.countryCode);
  if (directCountry != null) {
    return directCountry;
  }

  return _countryCodeFromLanguageTag(
    languageTag ?? resolvedLocale.toLanguageTag(),
  );
}

/// Normalizes a country code to uppercase when it looks like `US` or `CA`.
String? normalizeCountryCode(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.trim().toUpperCase();
  if (!_countryCodePattern.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

String? _countryCodeFromLanguageTag(String tag) {
  if (tag.isEmpty) {
    return null;
  }

  final segments = tag.split(RegExp('[-_]'));
  for (var index = segments.length - 1; index >= 0; index--) {
    if (segments.length > 1 && index == 0) {
      continue;
    }
    final segment = segments[index];
    final normalized = normalizeCountryCode(segment);
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}
