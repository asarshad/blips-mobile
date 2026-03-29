/// Application-wide configuration helpers.
class AppConfig {
  AppConfig._();

  static const _defaultBackendBaseUrl = 'https://api.blips.tech/api/v1';

  /// Base URL used by HTTP clients when calling the backend.
  static final backendBaseUrl = validateBackendBaseUrl(
    const String.fromEnvironment(
      'BLIPS_BACKEND_URL',
      defaultValue: _defaultBackendBaseUrl,
    ),
    isReleaseBuild: const bool.fromEnvironment('dart.vm.product'),
  );

  /// Validates and normalizes the configured backend URL.
  static String validateBackendBaseUrl(
    String rawUrl, {
    required bool isReleaseBuild,
  }) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      throw StateError('Invalid BLIPS_BACKEND_URL: $rawUrl');
    }

    if (isReleaseBuild) {
      if (uri.scheme != 'https') {
        throw StateError('Release builds require an HTTPS BLIPS_BACKEND_URL');
      }
      if (_isDisallowedReleaseHost(uri.host)) {
        throw StateError(
          'Release builds cannot target localhost or private-network backends',
        );
      }
    }

    final normalizedPath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: normalizedPath).toString();
  }

  static bool _isDisallowedReleaseHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '0.0.0.0' ||
        normalized == '::1' ||
        normalized.endsWith('.localhost')) {
      return true;
    }

    final segments = normalized.split('.');
    if (segments.length != 4) {
      return false;
    }

    final octets = segments.map(int.tryParse).toList(growable: false);
    if (octets.any((value) => value == null)) {
      return false;
    }

    final first = octets[0]!;
    final second = octets[1]!;

    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}
