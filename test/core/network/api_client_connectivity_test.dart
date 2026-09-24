/*
Tujuan: Mengunci integrasi ApiClient dengan ConnectivityMonitor agar status
        serverDown tidak stale setelah server kembali merespons.
Caller: Flutter test runner.
Dependensi: ApiClient, ConnectivityMonitor, SessionManager, Dio fake adapter.
Main Functions: main().
Side Effects: Tidak ada; HTTP ditangkap fake adapter in-memory.
*/

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/network/api_client.dart';
import 'package:sm_system/core/network/api_endpoints.dart';
import 'package:sm_system/core/services/connectivity_monitor.dart';
import 'package:sm_system/core/session/session_manager.dart';

class _MemoryStorage {
  final Map<String, String> values = {};

  Future<String?> read({required String key}) async => values[key];

  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, this.statusCode);

  final Map<String, dynamic> body;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('successful HTTP response clears stale serverDown status', () async {
    final monitor = ConnectivityMonitor(changes: () => const Stream.empty());
    monitor.reportServerDown();
    final client = ApiClient(
      sessionManager: SessionManager(storage: _MemoryStorage()),
      connectivityMonitor: monitor,
      dio: Dio()
        ..httpClientAdapter = _Adapter({
          'success': true,
          'data': {'ok': true},
        }, 200),
    );

    await client.get('https://api.test/ping');

    expect(monitor.status.value, ConnectionStatus.online);
    monitor.dispose();
  });

  test('structured API error response still clears stale serverDown', () async {
    final monitor = ConnectivityMonitor(changes: () => const Stream.empty());
    monitor.reportServerDown();
    final client = ApiClient(
      sessionManager: SessionManager(storage: _MemoryStorage()),
      connectivityMonitor: monitor,
      dio: Dio()
        ..httpClientAdapter = _Adapter({
          'success': false,
          'message': 'Token sesi tidak valid.',
          'errorCode': 'MISSING_TOKEN',
        }, 401),
    );

    try {
      await client.post('https://api.test/login');
    } on DioException {
      // Expected: this test only cares that the server answered.
    }

    expect(monitor.status.value, ConnectionStatus.online);
    monitor.dispose();
  });

  test('login auth error keeps device attestation for retry', () async {
    final storage = _MemoryStorage();
    final session = SessionManager(storage: storage);
    await session.setDeviceAttestation(
      tempToken: 'temp-token',
      deviceId: 'device-1',
    );
    final client = ApiClient(
      sessionManager: session,
      dio: Dio()
        ..httpClientAdapter = _Adapter({
          'success': false,
          'message': 'Credential salah.',
          'errorCode': 'INVALID_CREDENTIALS',
        }, 401),
    );

    try {
      await client.post(ApiEndpoints.login);
    } on DioException {
      // Expected: login failed, but device attestation must remain retryable.
    }

    expect(session.tempToken, 'temp-token');
    expect(session.deviceId, 'device-1');
    expect(storage.values[SessionManager.keyTempToken], 'temp-token');
    expect(storage.values[SessionManager.keyDeviceId], 'device-1');
  });
}
