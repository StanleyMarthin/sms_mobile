/*
Tujuan: Mengunci payload approve/correct/reject Job Plan.
Caller: Flutter test runner.
Dependensi: RemoteJobPlanDataSource, CommandMetadata, fake Dio adapter.
Main Functions: main().
Side Effects: Tidak ada; HTTP ditangkap fake adapter in-memory.
*/

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/core/network/api_client.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/job_plan/data/datasources/remote_job_plan_datasource.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/domain/repositories/job_plan_repository.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_approval_page.dart';

class _MemoryStorage {
  final Map<String, String> values = {};
  Future<String?> read({required String key}) async => values[key];
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  Future<void> delete({required String key}) async => values.remove(key);
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
        'data': {'planId': 'plan-1', 'version': 6},
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

class _ConflictRepository implements JobPlanRepository {
  int listCalls = 0;

  @override
  Future<List<JobPlan>> listOperationalPlans({
    String view = "browse",
    int page = 1,
    int limit = 20,
    String? unitId,
    String? employeeId,
    String? date,
    String? divisionId,
    String? approvalState,
    String? executionState,
  }) async {
    listCalls++;
    return [_plan()];
  }

  @override
  Future<JobPlan> mutateApproval({
    required String planId,
    required String action,
    required CommandMetadata metadata,
    String? employeeId,
    String? taskDate,
    int? plannedStartMinute,
    int? plannedWorkMinutes,
    String? note,
    String? rejectReason,
  }) async {
    throw const ClientFailure(errorCode: 'ERR_STALE_PLAN');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('approval commands require commandId and expectedVersion', () async {
    final adapter = _CaptureAdapter();
    final session = SessionManager(storage: _MemoryStorage());
    await session.login(
      token: 'token',
      refreshToken: 'refresh',
      userId: 'ADV-1',
      employeeId: 'ADV-1',
      fullName: 'ADV',
      role: 'adv',
      divisionName: 'Interior',
      jabatan: 'ADV',
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

    await dataSource.mutateApproval(
      planId: 'plan-1',
      action: 'approve',
      metadata: const CommandMetadata(
        commandId: 'cmd-approve-1',
        expectedVersion: 5,
      ),
    );
    await dataSource.mutateApproval(
      planId: 'plan-1',
      action: 'correct',
      metadata: const CommandMetadata(
        commandId: 'cmd-correct-1',
        expectedVersion: 6,
      ),
      plannedStartMinute: 540,
      plannedWorkMinutes: 180,
    );
    await dataSource.mutateApproval(
      planId: 'plan-1',
      action: 'reject',
      metadata: const CommandMetadata(
        commandId: 'cmd-reject-1',
        expectedVersion: 7,
      ),
      rejectReason: 'Scope salah',
    );

    final approve = adapter.requests[0].data as Map<String, dynamic>;
    final correct = adapter.requests[1].data as Map<String, dynamic>;
    final reject = adapter.requests[2].data as Map<String, dynamic>;
    expect(
      adapter.requests[0].path.endsWith('/sm/job-plans/v2/plan-1'),
      isTrue,
    );
    expect(approve['action'], 'approve');
    expect(approve['commandId'], 'cmd-approve-1');
    expect(approve['expectedVersion'], 5);
    expect(correct['action'], 'correct');
    expect(correct['plannedStartMinute'], 540);
    expect(reject['action'], 'reject');
    expect(reject['rejectReason'], 'Scope salah');
  });

  testWidgets('approval conflict refreshes list from backend', (tester) async {
    final repo = _ConflictRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JobPlanApprovalPage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(repo.listCalls, 2);
    expect(
      find.text('Data Job Plan berubah. Memuat ulang data terbaru.'),
      findsOneWidget,
    );
  });
}

JobPlan _plan() {
  return JobPlan(
    planId: 'plan-1',
    coreId: 'core-1',
    carId: 'unit-1',
    sourceType: 'COUNTDOWN',
    sourceRefId: 'core-1',
    unitName: 'MB220S',
    panelName: 'Dashboard Wood',
    assignedDivision: 'Interior',
    assignedUserId: 'emp-1',
    assignedTo: 'Budi',
    description: 'Restore Dashboard',
    targetHours: 4,
    workDate: '2026-09-15',
    startTime: '08:00',
    finishTime: '12:00',
    isOvertime: false,
    deadline: '2026-09-15',
    status: 'DIVISION_REVIEW',
    note: '',
    approvalState: 'DIVISION_REVIEW',
    executionState: 'NOT_STARTED',
    ledgerState: 'UNMATERIALIZED',
    version: 1,
  );
}
