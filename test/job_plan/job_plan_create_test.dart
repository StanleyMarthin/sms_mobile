/*
Tujuan: Mengunci payload create Job Plan dari Countdown.
Caller: Flutter test runner.
Dependensi: RemoteJobPlanDataSource, ApiClient, SessionManager, fake Dio adapter.
Main Functions: main().
Side Effects: Tidak ada; HTTP ditangkap fake adapter in-memory.
*/

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/network/api_client.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/job_plan/data/datasources/remote_job_plan_datasource.dart';

class _MemoryStorage {
  final Map<String, String> values = {};
  Future<String?> read({required String key}) async => values[key];
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  Future<void> delete({required String key}) async => values.remove(key);
}

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'planId': 'plan-v2-1', 'coreId': 'core-1'},
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
  test(
    'createCountdownPlan posts Countdown-owned command to operational endpoint',
    () async {
      final adapter = _CaptureAdapter();
      final session = SessionManager(storage: _MemoryStorage());
      await session.login(
        token: 'token',
        refreshToken: 'refresh',
        userId: 'KD-1',
        employeeId: 'KD-1',
        fullName: 'KD',
        role: 'kd',
        divisionName: 'Interior',
        jabatan: 'KD',
        divisionId: 1,
        permissions: const [],
      );
      final dataSource = RemoteJobPlanDataSource(
        apiClient: ApiClient(
          sessionManager: session,
          dio: Dio()..httpClientAdapter = adapter,
        ),
        sessionManager: session,
      );

      await dataSource.createCountdownPlan(
        coreId: 'core-1',
        employeeId: 'emp-1',
        taskDate: '2026-09-15',
        plannedStartMinute: 480,
        plannedWorkMinutes: 240,
        jobDescription: 'Restore Dashboard',
        commandId: 'cmd-create-1',
        isPriority: true,
        isRework: false,
      );

      final payload = adapter.request!.data as Map<String, dynamic>;
      expect(adapter.request!.method, 'POST');
      expect(adapter.request!.path.endsWith('/sm/job-plans/v2'), isTrue);
      expect(payload['coreId'], 'core-1');
      expect(payload['userId'], 'KD-1');
      expect(payload['employeeId'], 'emp-1');
      expect(payload['plannedStartMinute'], 480);
      expect(payload['plannedWorkMinutes'], 240);
      expect(payload['commandId'], 'cmd-create-1');
      expect(payload.containsKey('panelId'), isFalse);
    },
  );

  test('operational detail request carries the current actor', () async {
    final adapter = _CaptureAdapter();
    final session = SessionManager(storage: _MemoryStorage());
    await session.login(
      token: 'token',
      refreshToken: 'refresh',
      userId: 'KD-1',
      employeeId: 'KD-1',
      fullName: 'KD',
      role: 'kd',
      divisionName: 'Interior',
      jabatan: 'KD',
      divisionId: 1,
      permissions: const [],
    );
    final dataSource = RemoteJobPlanDataSource(
      apiClient: ApiClient(
        sessionManager: session,
        dio: Dio()..httpClientAdapter = adapter,
      ),
      sessionManager: session,
    );

    await dataSource.getOperationalPlan('plan-1');

    expect(adapter.request!.queryParameters['userId'], 'KD-1');
  });
}
