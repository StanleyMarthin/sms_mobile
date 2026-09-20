/*
Tujuan: Mengunci payload dan tampilan final validation Job Plan.
Caller: Flutter test runner.
Dependensi: RemoteJobPlanDataSource, JobPlanValidationPage, fake Dio adapter.
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
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_validation_page.dart';

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
        'data': {
          'planId': 'plan-1',
          'executionState': 'VALIDATED',
          'ledgerState': 'FINALIZED',
          'version': 14,
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
  test('validatePlan posts final validation command', () async {
    final adapter = _CaptureAdapter();
    final session = SessionManager(storage: _MemoryStorage());
    await session.login(
      token: 'token',
      refreshToken: 'refresh',
      userId: 'QA-1',
      employeeId: 'QA-1',
      fullName: 'QA',
      role: 'qa',
      divisionName: 'Interior',
      jabatan: 'QA',
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

    await dataSource.validatePlan(
      planId: 'plan-1',
      metadata: const CommandMetadata(
        commandId: 'cmd-validate-1',
        expectedVersion: 13,
      ),
      verifiedTotalMinutes: 600,
      progressSeen: 100,
      note: 'Final OK',
    );

    final payload = adapter.request!.data as Map<String, dynamic>;
    expect(
      adapter.request!.path.endsWith('/sm/job-plans/v2/plan-1/validate'),
      isTrue,
    );
    expect(payload['commandId'], 'cmd-validate-1');
    expect(payload['expectedVersion'], 13);
    expect(payload['verifiedTotalMinutes'], 600);
    expect(payload['progressSeen'], 100);
    expect(payload['note'], 'Final OK');
  });

  testWidgets('validation page exposes PASS only and no rework action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobPlanValidationPage(
          initialPlans: [
            JobPlan(
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
              targetHours: 10,
              workDate: '2026-09-15',
              startTime: '08:00',
              finishTime: '12:00',
              isOvertime: false,
              deadline: '2026-09-15',
              status: 'APPROVED',
              note: '',
              approvalState: 'APPROVED',
              executionState: 'FINISHED_PENDING_VALIDATION',
              ledgerState: 'MATERIALIZED',
              version: 13,
              accumulatedMinutes: 600,
              verifiedMinutes: 600,
              unverifiedMinutes: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting Validation'), findsOneWidget);
    expect(find.text('PASS'), findsOneWidget);
    expect(find.text('REWORK'), findsNothing);
  });
}
