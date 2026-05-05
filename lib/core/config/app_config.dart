/// Environment-aware application configuration.
///
/// Reads values from `--dart-define` at build time so that sensitive
/// values (API URLs, keys) are never committed to source control.
///
/// Usage (build):
/// ```bash
/// flutter run --dart-define=BASE_URL=http://108.136.189.225
/// ```
class AppConfig {
  AppConfig._();

  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://108.136.189.225',
  );

  static const androidStoreUrl = String.fromEnvironment(
    'ANDROID_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=com.stanleymarthin.workshop.sm_workshop',
  );

  static const iosStoreUrl = String.fromEnvironment(
    'IOS_STORE_URL',
    defaultValue: 'https://apps.apple.com/app/id0000000000',
  );

  static Uri get baseUri {
    final raw = baseUrl.trim();
    final normalized = raw.contains('://') ? raw : 'http://$raw';
    return Uri.parse(normalized);
  }

  static String serviceOrigin(int port) {
    final uri = baseUri;
    final host = uri.host.isEmpty ? uri.path : uri.host;
    return '${uri.scheme}://$host:$port';
  }
}
