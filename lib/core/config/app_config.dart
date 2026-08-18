/*
Tujuan: Konfigurasi environment aplikasi mobile dari dart-define.
Caller: ApiEndpoints dan kode runtime yang butuh URL/store config.
Dependensi: Dart compile-time environment (`String.fromEnvironment`).
Main Functions: AppConfig.baseUrl, AppConfig.baseUri, AppConfig.serviceOrigin().
Side Effects: Tidak ada.
*/

class AppConfig {
  AppConfig._();

  static final baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.stanleymarthin.com',
  );

  static final androidStoreUrl = String.fromEnvironment(
    'ANDROID_STORE_URL',
    defaultValue:
        'https://play.google.com/store/apps/details?id=com.stanleymarthin.workshop.sm_workshop',
  );

  static final iosStoreUrl = String.fromEnvironment(
    'IOS_STORE_URL',
    defaultValue: 'https://apps.apple.com/app/id0000000000',
  );

  static Uri get baseUri {
    final raw = baseUrl.trim();
    final normalized = raw.contains('://') ? raw : 'https://$raw';
    return Uri.parse(normalized);
  }

  static bool get usesGatewayBaseUrl => _isGatewayOrigin(baseUri);

  static String serviceOrigin(int port) {
    return serviceOriginFor(baseUri, port);
  }

  static String serviceOriginFor(Uri uri, int port) {
    final host = uri.host.isEmpty ? uri.path : uri.host;
    if (_isGatewayOrigin(uri)) {
      return '${uri.scheme}://$host';
    }
    return '${uri.scheme}://$host:$port';
  }

  static bool _isGatewayOrigin(Uri uri) {
    return uri.scheme == 'https' && !uri.hasPort;
  }
}
