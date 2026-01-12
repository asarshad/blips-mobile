/// Application-wide configuration helpers.
class AppConfig {
  AppConfig._();

  /// Base URL used by HTTP clients when calling the backend.
  /// Using .local hostname for stable local development (works across network changes)
  static const backendBaseUrl = String.fromEnvironment(
    'BLIPS_BACKEND_URL',
    defaultValue: 'http://MacBook-Pro.local:8000/api/v1',
  );
}
