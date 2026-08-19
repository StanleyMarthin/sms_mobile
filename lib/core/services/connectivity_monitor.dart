/*
Tujuan: Memantau status koneksi global aplikasi (online/offline/server mati)
        dan menjadi sumber kebenaran untuk popup opsi Keluar/Coba Lagi.
Caller: ConnectivityGuard (overlay global), ApiClient (lapor server down),
        main.dart (init).
Dependensi: connectivity_plus, flutter foundation (ValueNotifier).
Main Functions: init(), recheck(), reportServerDown(), status.
Side Effects: Listen stream koneksi OS; membaca konektivitas perangkat.
*/

library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Status koneksi global.
///
/// - [online]: device punya koneksi (belum tentu server hidup).
/// - [offline]: device tidak punya akses internet.
/// - [serverDown]: device online tapi server tidak merespons (network/timeout/5xx).
enum ConnectionStatus { online, offline, serverDown }

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();
typedef ConnectivityChanges = Stream<List<ConnectivityResult>> Function();

Future<List<ConnectivityResult>> _defaultCheck() =>
    Connectivity().checkConnectivity();

Stream<List<ConnectivityResult>> _defaultChanges() =>
    Connectivity().onConnectivityChanged;

/// Global connectivity monitor. Inject [check]/[changes] saat unit test.
class ConnectivityMonitor {
  ConnectivityMonitor({ConnectivityCheck? check, ConnectivityChanges? changes})
    : _check = check ?? _defaultCheck,
      _changes = changes ?? _defaultChanges;

  final ConnectivityCheck _check;
  final ConnectivityChanges _changes;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Status saat ini. Dengarkan untuk reaksi UI global.
  final ValueNotifier<ConnectionStatus> status = ValueNotifier(
    ConnectionStatus.online,
  );

  /// Baca konektivitas awal + subscribe perubahan OS.
  Future<void> init() async {
    await checkConnectivity();
    _sub = _changes().listen((results) async {
      if (_hasConnection(results)) {
        if (status.value == ConnectionStatus.offline) {
          status.value = ConnectionStatus.online;
        }
      } else if (status.value != ConnectionStatus.serverDown) {
        status.value = ConnectionStatus.offline;
      }
    });
  }

  /// Device online tapi request gagal (network error/timeout/HTTP >=500).
  void reportServerDown() {
    if (status.value != ConnectionStatus.offline) {
      status.value = ConnectionStatus.serverDown;
    }
  }

  /// Cek ulang status perangkat; dipanggil dari aksi "Coba Lagi".
  Future<void> recheck() async {
    final results = await _check();
    status.value = _hasConnection(results)
        ? ConnectionStatus.online
        : ConnectionStatus.offline;
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Baca konektivitas perangkat sekarang.
  Future<void> checkConnectivity() async {
    final results = await _check();
    if (!_hasConnection(results)) {
      status.value = ConnectionStatus.offline;
    }
  }

  void dispose() {
    _sub?.cancel();
    status.dispose();
  }
}
