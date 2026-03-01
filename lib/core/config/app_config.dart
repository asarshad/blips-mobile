/// Application-wide configuration helpers.
class AppConfig {
  AppConfig._();

  /// Base URL used by HTTP clients when calling the backend.
  static const backendBaseUrl = String.fromEnvironment(
    'BLIPS_BACKEND_URL',
    defaultValue: 'https://blips-api.onrender.com/api/v1',
  );
}
