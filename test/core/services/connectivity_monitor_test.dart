/*
Tujuan: Memverifikasi logika transisi status koneksi ConnectivityMonitor
        (online/offline/serverDown) dan perilaku recheck.
Caller: Flutter test suite untuk core services.
Dependensi: ConnectivityMonitor, connectivity_plus (ConnectivityResult), flutter_test.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/services/connectivity_monitor.dart';

void main() {
  group('ConnectivityMonitor', () {
    test('initial status is online', () {
      final monitor = ConnectivityMonitor();
      expect(monitor.status.value, ConnectionStatus.online);
      monitor.dispose();
    });

    test('reportServerDown sets status serverDown', () {
      final monitor = ConnectivityMonitor();
      monitor.reportServerDown();
      expect(monitor.status.value, ConnectionStatus.serverDown);
      monitor.dispose();
    });

    test('checkConnectivity marks offline when no connection', () async {
      final monitor = ConnectivityMonitor(
        check: () async => [ConnectivityResult.none],
        changes: () => const Stream.empty(),
      );
      await monitor.init();
      expect(monitor.status.value, ConnectionStatus.offline);
      monitor.dispose();
    });

    test('recheck restores online when connection returns', () async {
      final monitor = ConnectivityMonitor(
        check: () async => [ConnectivityResult.wifi],
        changes: () => const Stream.empty(),
      );
      await monitor.init();
      monitor.reportServerDown();
      await monitor.recheck();
      expect(monitor.status.value, ConnectionStatus.online);
      monitor.dispose();
    });

    test('recheck marks offline when still no connection', () async {
      final monitor = ConnectivityMonitor(
        check: () async => [ConnectivityResult.none],
        changes: () => const Stream.empty(),
      );
      await monitor.init();
      monitor.reportServerDown();
      await monitor.recheck();
      expect(monitor.status.value, ConnectionStatus.offline);
      monitor.dispose();
    });

    test('connectivity restored while offline sets online', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      final monitor = ConnectivityMonitor(
        check: () async => [ConnectivityResult.none],
        changes: () => controller.stream,
      );
      await monitor.init();
      expect(monitor.status.value, ConnectionStatus.offline);

      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.status.value, ConnectionStatus.online);

      await controller.close();
      monitor.dispose();
    });
  });
}
