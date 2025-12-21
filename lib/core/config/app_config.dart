/// Application-wide configuration helpers.
class AppConfig {
  AppConfig._();

  /// Base URL used by HTTP clients when calling the backend.
  static const backendBaseUrl = String.fromEnvironment(
    'BLIPS_BACKEND_URL',
    defaultValue: 'http://192.168.1.94:8000/api/v1',
  );
}
