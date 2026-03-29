import 'package:blips_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.validateBackendBaseUrl', () {
    test('accepts the production backend for release builds', () {
      expect(
        AppConfig.validateBackendBaseUrl(
          'https://api.blips.tech/api/v1',
          isReleaseBuild: true,
        ),
        'https://api.blips.tech/api/v1',
      );
    });

    test('rejects http backends for release builds', () {
      expect(
        () => AppConfig.validateBackendBaseUrl(
          'http://api.blips.tech/api/v1',
          isReleaseBuild: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects localhost for release builds', () {
      expect(
        () => AppConfig.validateBackendBaseUrl(
          'https://localhost:8000/api/v1',
          isReleaseBuild: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects private IPv4 hosts for release builds', () {
      expect(
        () => AppConfig.validateBackendBaseUrl(
          'https://192.168.1.20/api/v1',
          isReleaseBuild: true,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows local development backends outside release builds', () {
      expect(
        AppConfig.validateBackendBaseUrl(
          'http://localhost:8000/api/v1/',
          isReleaseBuild: false,
        ),
        'http://localhost:8000/api/v1',
      );
    });
  });
}
