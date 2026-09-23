/*
Tujuan: Mengunci timeout auth agar login/device-init tidak ikut timeout pendek data feature.
Caller: Flutter test runner.
Dependensi: RemoteAuthDataSource, ApiClient, SessionManager, Dio fake adapter.
Main Functions: main().
Side Effects: Tidak ada; HTTP ditangkap fake adapter in-memory.
*/

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/di/injection.dart';
import 'package:sm_system/core/network/api_client.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/auth/data/datasources/remote_auth_datasource.dart';

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

class _CaptureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': options.path.contains('/device-init')
            ? {'versionStatus': 'LATEST', 'tempToken': 'temp'}
            : {
                'token': 'token',
                'refreshToken': 'refresh',
                'user': {'id': 'KD-1', 'employeeId': 'KD-1'},
              },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(sl.reset);

  test(
    'auth requests use auth timeout instead of feature data timeout',
    () async {
      final adapter = _CaptureAdapter();
      final session = SessionManager(storage: _MemoryStorage());
      sl.registerSingleton<SessionManager>(session);
      final datasource = RemoteAuthDataSource(
        apiClient: ApiClient(
          sessionManager: session,
          dio: Dio()..httpClientAdapter = adapter,
        ),
      );

      await datasource.deviceInit(const {'deviceId': 'device-1'});
      await datasource.login(employeeId: 'KD-1', password: 'secret');

    expect(ApiClient.requestTimeout, const Duration(seconds: 5));
      expect(adapter.requests, hasLength(2));
      for (final request in adapter.requests) {
        expect(request.connectTimeout, ApiClient.authTimeout);
        expect(request.receiveTimeout, ApiClient.authTimeout);
        expect(request.sendTimeout, ApiClient.authTimeout);
      }
    },
  );
}
