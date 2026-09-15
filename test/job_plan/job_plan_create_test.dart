/*
Tujuan: Mengunci payload create Job Plan V2 dari Countdown.
Caller: Flutter test runner.
Dependensi: RemoteJobPlanDataSource, ApiClient, SessionManager, fake Dio adapter.
Main Functions: main().
Side Effects: Tidak ada; HTTP ditangkap fake adapter in-memory.
*/

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/network/api_client.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/job_plan/data/datasources/remote_job_plan_datasource.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan_v2_options.dart';
import 'package:sm_system/features/job_plan/domain/repositories/job_plan_repository.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_create_page.dart';

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
  test('createV2Plan posts Countdown-owned command to V2 endpoint', () async {
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

    await dataSource.createV2Plan(
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
    expect(payload['employeeId'], 'emp-1');
    expect(payload['plannedStartMinute'], 480);
    expect(payload['plannedWorkMinutes'], 240);
    expect(payload['commandId'], 'cmd-create-1');
    expect(payload.containsKey('panelId'), isFalse);
  });

  testWidgets('create page uses typed options instead of raw id fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPlanCreatePage(
            coreId: 'CORE-1',
            repository: _CreateRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Panel'), findsOneWidget);
    expect(find.text('Countdown'), findsOneWidget);
    expect(find.text('PIC'), findsOneWidget);
    expect(find.text('Core ID'), findsNothing);
    expect(find.text('PIC ID'), findsNothing);
  });
}

class _CreateRepository implements JobPlanRepository {
  @override
  Future<JobPlanV2Options> getV2Options({String? divisionId, String? unitId}) {
    return Future.value(
      const JobPlanV2Options(
        units: [JobPlanV2Option(id: 'UNIT-1', label: 'MB 220S')],
        panels: [JobPlanV2Option(id: 'PANEL-1', label: 'Door RH')],
        countdowns: [JobPlanV2Option(id: 'CORE-1', label: 'Painting Door RH')],
        employees: [JobPlanV2Option(id: 'EMP-1', label: 'Budi')],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
