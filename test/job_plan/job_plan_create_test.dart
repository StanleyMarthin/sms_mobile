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
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    requests.add(options);
    final isApprovalMutation =
        options.method == 'PUT' && options.path.contains('/sm/job-plans/v2/');
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': isApprovalMutation
            ? {
                'planId': 'plan-v2-1',
                'version': 2,
                'approvalState': 'DIVISION_REVIEW',
              }
            : {'planId': 'plan-v2-1', 'coreId': 'core-1', 'version': 1},
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

class _ApprovalQueueAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isV2 = options.path.endsWith('/sm/job-plans/v2');
    final items = isV2
        ? [
            {
              'planId': 'plan-v2-approval-1',
              'coreId': 'core-1',
              'carId': 'car-1',
              'unitName': 'JAGUAR XK120',
              'panelId': 7,
              'panelName': 'SPAREPART',
              'divisionId': 12,
              'employeeId': 'SM-11.004',
              'employeeName': 'AGUS RUSMAWAN',
              'taskDate': '2026-09-29',
              'planned_start_minute': 480,
              'planned_work_minutes': 99,
              'approvalState': 'DIVISION_REVIEW',
              'executionState': 'NOT_STARTED',
              'ledgerState': 'UNMATERIALIZED',
              'jobdescription': 'REPAIR',
              'note': 'REPAIR part',
              'createdBy': 'KD-1',
              'version': 2,
              'source': 'V2_REDIS',
            },
          ]
        : <Map<String, dynamic>>[];
    final type = options.queryParameters['unitId'] == null
        ? 'units'
        : options.queryParameters['divisionId'] == null
        ? 'divisions'
        : 'plans';
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'items': items, 'type': type, 'count': items.length},
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

  test(
    'submitDraft sends Countdown draft items to operational V2 endpoint',
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

      final createdIds = await dataSource.submitDraft(
        userId: 'KD-1',
        sourceType: 'COUNTDOWN',
        items: [
          {
            'draftItemId': 'draft-1',
            'sourceType': 'COUNTDOWN',
            'coreId': 'core-1',
            'assignedUserId': 'emp-1',
            'taskDate': '2026-09-29',
            'startTime': '08:00',
            'targetHours': 1.65,
            'jobDescription': 'Repair',
            'note': 'Repair part',
            'isOvertime': false,
          },
        ],
      );

      final createPayload = adapter.requests[0].data as Map<String, dynamic>;
      final submitPayload = adapter.requests[1].data as Map<String, dynamic>;
      expect(createdIds, ['plan-v2-1']);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].path.endsWith('/sm/job-plans/v2'), isTrue);
      expect(createPayload['action'], isNull);
      expect(createPayload['userId'], 'KD-1');
      expect(createPayload['coreId'], 'core-1');
      expect(createPayload['employeeId'], 'emp-1');
      expect(createPayload['plannedStartMinute'], 480);
      expect(createPayload['plannedWorkMinutes'], 99);
      expect(createPayload['jobDescription'], 'Repair');
      expect(createPayload['note'], 'Repair part');
      expect(createPayload['commandId'], 'mobile-create-KD-1-draft-1');
      expect(adapter.requests[1].method, 'PUT');
      expect(
        adapter.requests[1].path.endsWith('/sm/job-plans/v2/plan-v2-1'),
        isTrue,
      );
      expect(submitPayload['action'], 'submit');
      expect(submitPayload['userId'], 'KD-1');
      expect(submitPayload['expectedVersion'], 1);
      expect(submitPayload['commandId'], 'mobile-submit-KD-1-draft-1');
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

  test('approval queue includes submitted V2 draft for tracking', () async {
    final adapter = _ApprovalQueueAdapter();
    final session = SessionManager(storage: _MemoryStorage());
    await session.login(
      token: 'token',
      refreshToken: 'refresh',
      userId: 'KD-1',
      employeeId: 'KD-1',
      fullName: 'KD',
      role: 'kd',
      divisionName: 'INTERIOR',
      jabatan: 'KD',
      divisionId: 12,
      permissions: const [],
    );
    final dataSource = RemoteJobPlanDataSource(
      apiClient: ApiClient(
        sessionManager: session,
        dio: Dio()..httpClientAdapter = adapter,
      ),
      sessionManager: session,
    );

    final units = await dataSource.getApprovalRaw(taskDate: '2026-09-29');
    final divisions = await dataSource.getApprovalRaw(
      unitId: 'car-1',
      taskDate: '2026-09-29',
    );
    final plans = await dataSource.getApprovalQueue(
      unitId: 'car-1',
      divisionId: '12',
      taskDate: '2026-09-29',
    );

    expect((units['items'] as List).single['unitName'], 'JAGUAR XK120');
    expect((divisions['items'] as List).single['divisionName'], 'INTERIOR');
    expect(plans.single['planId'], 'plan-v2-approval-1');
    expect(plans.single['status'], 'PENDING_ADV');
    expect(plans.single['startTime'], '08:00');
    expect(plans.single['finishTime'], '09:39');
    expect(plans.single['targetHours'], closeTo(1.65, 0.001));
    expect(plans.single['approvalState'], 'DIVISION_REVIEW');
    expect(plans.single['createdBy'], 'KD-1');
    expect(plans.single['version'], 2);
  });
}
