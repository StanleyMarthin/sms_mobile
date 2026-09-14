/*
Tujuan: Mengunci kontrak mobile Task Execution untuk Job Plan V2.
Caller: Flutter test runner.
Dependensi: ApiTaskDataSource, TaskModel, SessionManager, Dio fake adapter.
Main Functions: main.
Side Effects: Tidak ada; HTTP ditangkap fake adapter in-memory.
*/
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/network/api_client.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/task_execution/data/datasources/api_task_datasource.dart';
import 'package:sm_system/features/task_execution/data/models/task_model.dart';
import 'package:sm_system/features/task_execution/domain/entities/task_execution_log.dart';

class _MemoryStorage {
  final Map<String, String> _values = {};

  Future<String?> read({required String key}) async => _values[key];

  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
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
          'planId': options.path
              .split('/')
              .elementAt(options.path.split('/').length - 2),
          'executionState': 'RUNNING',
          'ledgerState': 'UNMATERIALIZED',
          'version': 8,
          'projectionReady': true,
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
  test('TaskModel parses V2 execution contract without losing legacy id', () {
    final model = TaskModel.fromTaskApiJson({
      'planId': 'plan-v2-1',
      'coreId': 'core-1',
      'approvalState': 'APPROVED',
      'executionState': 'VALIDATED',
      'ledgerState': 'FINALIZED',
      'version': 12,
      'accumulatedMinutes': 300,
      'verifiedMinutes': 300,
      'projectionReady': true,
      'status': 'READY_QC',
      'taskDate': '2026-09-15',
      'dailyTargetHours': 5,
      'division': {'divisionName': 'BODY'},
      'unit': {'unitId': 'car-1', 'unitName': 'Mercedes 220S', 'owner': 'SM'},
      'task': {'namaPanel': 'Front Bumper', 'jobName': 'Repair'},
    });

    final entity = model.toEntity();

    expect(entity.planId, 'plan-v2-1');
    expect(entity.plandailyId, 'plan-v2-1');
    expect(entity.approvalState, 'APPROVED');
    expect(entity.executionState, 'VALIDATED');
    expect(entity.ledgerState, 'FINALIZED');
    expect(entity.version, 12);
    expect(entity.accumulatedMinutes, 300);
    expect(entity.verifiedMinutes, 300);
    expect(entity.unverifiedMinutes, 0);
    expect(entity.projectionReady, isTrue);
    expect(entity.mobileExecutionState, 'WAITING_QC');
    expect(entity.mobileExecutionLabel, 'Menunggu QC');
  });

  test('TaskModel exposes V2 hold as resumable mobile state', () {
    final entity = TaskModel.fromJson({
      'planId': 'plan-v2-hold',
      'approvalState': 'APPROVED',
      'executionState': 'HOLD',
      'ledgerState': 'UNMATERIALIZED',
      'version': 4,
      'projectionReady': true,
    }).toEntity();

    expect(entity.canStart, isFalse);
    expect(entity.canResume, isTrue);
    expect(entity.mobileExecutionState, 'HOLD');
    expect(entity.mobileExecutionLabel, 'Hold');
  });

  test(
    'ApiTaskDataSource sends V2 start command with commandId and expectedVersion',
    () async {
      final adapter = _CaptureAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final session = SessionManager(storage: _MemoryStorage());
      await session.login(
        token: 'token',
        refreshToken: 'refresh',
        userId: 'EMP-1',
        employeeId: 'EMP-1',
        fullName: 'Asep',
        role: 'operator',
        divisionName: 'BODY',
        jabatan: 'Operator',
        divisionId: 4,
        permissions: const [],
      );
      final dataSource = ApiTaskDataSource(
        apiClient: ApiClient(sessionManager: session, dio: dio),
        sessionManager: session,
      );

      await dataSource.startJobExecution(
        'plan-v2-1',
        isV2: true,
        commandId: 'cmd-start-1',
        expectedVersion: 7,
      );

      final payload = adapter.request!.data as Map<String, dynamic>;
      expect(
        adapter.request!.path.endsWith('/sm/job-plans/v2/plan-v2-1/execution'),
        isTrue,
      );
      expect(payload['action'], 'start');
      expect(payload['commandId'], 'cmd-start-1');
      expect(payload['expectedVersion'], 7);
      expect(payload['userId'], 'EMP-1');
      expect(payload.containsKey('plandailyId'), isFalse);
    },
  );

  test('ApiTaskDataSource maps V2 submit status to hold or finish', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final session = SessionManager(storage: _MemoryStorage());
    await session.login(
      token: 'token',
      refreshToken: 'refresh',
      userId: 'EMP-1',
      employeeId: 'EMP-1',
      fullName: 'Asep',
      role: 'operator',
      divisionName: 'BODY',
      jabatan: 'Operator',
      divisionId: 4,
      permissions: const [],
    );
    final dataSource = ApiTaskDataSource(
      apiClient: ApiClient(sessionManager: session, dio: dio),
      sessionManager: session,
    );

    await dataSource.submitTaskExecution(
      const TaskExecutionLog(
        plandailyId: 'plan-v2-1',
        startTime: '2026-09-15T08:00:00+07:00',
        finishTime: '2026-09-15T10:00:00+07:00',
        breakDurationMinutes: 0,
        progressPercent: 50,
        status: 'pending',
        isV2: true,
        commandId: 'cmd-hold-1',
        expectedVersion: 9,
      ),
    );
    expect((adapter.request!.data as Map<String, dynamic>)['action'], 'hold');

    await dataSource.submitTaskExecution(
      const TaskExecutionLog(
        plandailyId: 'plan-v2-1',
        startTime: '2026-09-15T08:00:00+07:00',
        finishTime: '2026-09-15T12:00:00+07:00',
        breakDurationMinutes: 60,
        progressPercent: 100,
        status: 'done',
        isV2: true,
        commandId: 'cmd-finish-1',
        expectedVersion: 10,
      ),
    );
    final payload = adapter.request!.data as Map<String, dynamic>;
    expect(payload['action'], 'finish');
    expect(payload['manualBreakMinutes'], 60);
    expect(payload['expectedVersion'], 10);
  });

  test('ApiTaskDataSource can send V2 resume command', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final session = SessionManager(storage: _MemoryStorage());
    await session.login(
      token: 'token',
      refreshToken: 'refresh',
      userId: 'EMP-1',
      employeeId: 'EMP-1',
      fullName: 'Asep',
      role: 'operator',
      divisionName: 'BODY',
      jabatan: 'Operator',
      divisionId: 4,
      permissions: const [],
    );
    final dataSource = ApiTaskDataSource(
      apiClient: ApiClient(sessionManager: session, dio: dio),
      sessionManager: session,
    );

    await dataSource.startJobExecution(
      'plan-v2-1',
      isV2: true,
      commandId: 'cmd-resume-1',
      expectedVersion: 11,
      v2Action: 'resume',
    );

    final payload = adapter.request!.data as Map<String, dynamic>;
    expect(payload['action'], 'resume');
    expect(payload['commandId'], 'cmd-resume-1');
    expect(payload['expectedVersion'], 11);
    expect(payload.containsKey('resumeAt'), isTrue);
  });
}
