/// Environment-aware application configuration.
///
/// Reads values from `--dart-define` at build time so that sensitive
/// values (API URLs, keys) are never committed to source control.
///
/// Usage (build):
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
/// ```
///
/// Usage (code):
/// ```dart
/// final baseUrl = AppConfig.apiBaseUrl;
/// ```
class AppConfig {
  AppConfig._();

  /// API Host — override via `--dart-define=API_HOST=108.136.189.225`.
  /// Default is 10.0.2.2 for Android Emulator local testing.
  static const apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '108.136.189.225',
  );
}
