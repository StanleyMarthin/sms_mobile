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
}
