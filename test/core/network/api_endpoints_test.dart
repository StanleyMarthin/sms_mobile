/*
Tujuan: Memverifikasi konfigurasi endpoint mobile production dan fallback legacy.
Caller: Flutter test suite untuk core network.
Dependensi: AppConfig, ApiEndpoints, flutter_test.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/config/app_config.dart';
import 'package:sm_system/core/network/api_endpoints.dart';

void main() {
  group('ApiEndpoints default gateway', () {
    test('uses the public HTTPS gateway without legacy ports', () {
      expect(AppConfig.baseUrl, 'https://api.stanleymarthin.com');
      expect(AppConfig.usesGatewayBaseUrl, isTrue);

      expect(
        ApiEndpoints.deviceInit,
        'https://api.stanleymarthin.com/sm/auth/device-init',
      );
      expect(
        ApiEndpoints.login,
        'https://api.stanleymarthin.com/api/v1/auth/login',
      );
      expect(ApiEndpoints.tasks, 'https://api.stanleymarthin.com/sm/tasks');
      expect(
        ApiEndpoints.jobPlans,
        'https://api.stanleymarthin.com/sm/job-plans',
      );
      expect(
        ApiEndpoints.warehouse,
        'https://api.stanleymarthin.com/sm/warehouse',
      );
      expect(
        ApiEndpoints.catalogComponents,
        'https://api.stanleymarthin.com/sm/catalog/components',
      );
      expect(
        ApiEndpoints.unitCatalogOpenPanel('220S'),
        'https://api.stanleymarthin.com/sm/units/220S/catalog',
      );
      expect(
        ApiEndpoints.unitCatalogPanelItemsBatch('220S', 91),
        'https://api.stanleymarthin.com/sm/units/220S/catalog/91/items',
      );
      expect(
        ApiEndpoints.masterPanelTracking('220S'),
        'https://api.stanleymarthin.com/sm/units/220S/master-panels/tracking',
      );
      expect(
        ApiEndpoints.masterPanelCountdownOptions('220S'),
        'https://api.stanleymarthin.com/sm/units/220S/master-panels/countdown-options',
      );
    });
  });

  group('AppConfig.serviceOrigin', () {
    test('keeps explicit legacy HTTP origins port-based', () {
      final origin = AppConfig.serviceOriginFor(
        Uri.parse('http://108.136.189.225'),
        8085,
      );

      expect(origin, 'http://108.136.189.225:8085');
    });

    test('keeps explicit gateway HTTPS origins unmodified', () {
      final origin = AppConfig.serviceOriginFor(
        Uri.parse('https://api.stanleymarthin.com'),
        8085,
      );

      expect(origin, 'https://api.stanleymarthin.com');
    });
  });
}
