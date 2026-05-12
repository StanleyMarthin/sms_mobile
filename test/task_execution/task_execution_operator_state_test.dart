/*
Tujuan: Verifikasi state operator task execution agar sesi yang sudah disubmit tidak kembali ke tombol start.
Caller: flutter test.
Dependensi: flutter_test, TaskModel, TaskEntity.
Main Functions: test closed session lock state, test backend alias normalization.
Side Effects: Tidak ada; hanya assertion unit test.
*/
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/task_execution/data/models/task_model.dart';
import 'package:sm_system/features/task_execution/data/models/view_task_model.dart';
import 'package:sm_system/features/task_execution/domain/entities/task_entity.dart';

TaskEntity _buildTaskEntity({
  required String status,
  required double remainingHours,
  String? startedAt,
  String? completedAt,
  bool hasMonitoringRecord = false,
}) {
  return TaskEntity(
    plandailyId: 'pd-1',
    coreId: 'core-1',
    carId: 'car-1',
    unitName: 'FERRARI F355',
    panelName: 'DASHBOARD',
    jobName: 'ASSEMBLY',
    divisionName: 'INTERIOR',
    status: status,
    isPanelLocked: false,
    dailyTargetHours: 4,
    targetHoursRevised: 8,
    remainingHours: remainingHours,
    taskDate: '2026-05-11',
    startTime: '08:00',
    targetFinishTime: '12:00',
    createdAt: '2026-05-11T07:00:00+07:00',
    startedAt: startedAt,
    completedAt: completedAt,
    taskCategory: 'MAIN',
    jobDescription: 'Pasang dashboard',
    ownerName: 'Mr. Test',
    totalActualHours: 4,
    hasMonitoringRecord: hasMonitoringRecord,
  );
}

void main() {
  group('TaskEntity operator gating', () {
    test('closed execution session is locked and cannot start again', () {
      final entity = _buildTaskEntity(
        status: 'PROSES',
        remainingHours: 4,
        startedAt: '2026-05-11T08:00:00+07:00',
        completedAt: '2026-05-11T10:00:00+07:00',
      );

      expect(entity.canStart, isFalse);
      expect(entity.isMonitoringLocked, isTrue);
      expect(entity.isInProgress, isFalse);
      expect(entity.isCompleted, isFalse);
    });

    test('no remaining work is treated as completed even if status lags', () {
      final entity = _buildTaskEntity(
        status: 'PROSES',
        remainingHours: 0,
        startedAt: '2026-05-11T08:00:00+07:00',
        completedAt: '2026-05-11T12:00:00+07:00',
      );

      expect(entity.isCompleted, isTrue);
      expect(entity.canStart, isFalse);
    });
  });

  group('TaskModel.fromTaskApiJson', () {
    test('normalizes backend aliases for final done session', () {
      final model = TaskModel.fromTaskApiJson({
        'planDailyId': 'pd-1',
        'coreId': 'core-1',
        'status': 'PROSES',
        'dailyTargetHours': 4,
        'remainingHours': 0,
        'actualProgressPercent': 100,
        'taskDate': '2026-05-11',
        'started_at': '2026-05-11T08:00:00+07:00',
        'completed_at': '2026-05-11T12:00:00+07:00',
        'division': {'divisionName': 'INTERIOR'},
        'unit': {
          'unitId': 'car-1',
          'unitName': 'FERRARI F355',
          'owner': 'Mr. Test',
        },
        'task': {
          'namaPanel': 'DASHBOARD',
          'jobName': 'ASSEMBLY',
          'jobDescription': 'Pasang dashboard',
          'startTime': '08:00',
          'targetFinishTime': '12:00',
        },
      });

      expect(model.status, 'DONE');
      expect(model.hasMonitoringRecord, isTrue);
      expect(model.startedAt, '2026-05-11T08:00:00+07:00');
      expect(model.completedAt, '2026-05-11T12:00:00+07:00');
      expect(model.toEntity().isCompleted, isTrue);
    });

    test(
      'keeps partial submitted session locked instead of returning to start',
      () {
        final model = TaskModel.fromTaskApiJson({
          'planDailyId': 'pd-1',
          'coreId': 'core-1',
          'status': 'PROSES',
          'dailyTargetHours': 4,
          'targetHoursRevised': 8,
          'remainingHours': 4,
          'actualProgressPercent': 50,
          'startedAt': '2026-05-11T08:00:00+07:00',
          'completedAt': '2026-05-11T10:00:00+07:00',
          'division': {'divisionName': 'INTERIOR'},
          'unit': {
            'unitId': 'car-1',
            'unitName': 'FERRARI F355',
            'owner': 'Mr. Test',
          },
          'task': {
            'namaPanel': 'DASHBOARD',
            'jobName': 'ASSEMBLY',
            'jobDescription': 'Pasang dashboard',
            'startTime': '08:00',
            'targetFinishTime': '12:00',
          },
        });

        expect(model.status, 'PROSES');
        expect(model.hasMonitoringRecord, isTrue);
        expect(model.toEntity().canStart, isFalse);
        expect(model.toEntity().isMonitoringLocked, isTrue);
        expect(model.toEntity().isCompleted, isFalse);
      },
    );

    test(
      'parses plan aliases and derives finish time for execution detail',
      () {
        final model = TaskModel.fromTaskApiJson({
          'planDailyId': 'pd-2',
          'coreId': 'core-2',
          'status': 'ASSIGNED',
          'daily_target_hours': 4,
          'plan_starttime': '08:00',
          'task_date': '2026-05-11',
          'division': {'divisionName': 'INTERIOR'},
          'unit': {
            'unitId': 'car-2',
            'unitName': 'JAGUAR XK120',
            'owner': 'Mr. Test',
          },
          'task': {
            'namaPanel': 'DOOR TRIM',
            'jobName': 'UPHOLSTERY',
            'jobDescription': 'Pasang door trim',
          },
        });

        expect(model.dailyTargetHours, 4);
        expect(model.startTime, '08:00');
        expect(model.targetFinishTime, '12:00');
      },
    );

    test('prefers cumulative total actual hours from countdown payload', () {
      final model = TaskModel.fromTaskApiJson({
        'planDailyId': 'pd-3',
        'coreId': 'core-3',
        'status': 'PLAN',
        'dailyTargetHours': 2,
        'targetHoursRevised': 10,
        'remainingHours': 2,
        'totalActualHours': 8,
        'actualProgressPercent': 80,
        'division': {'divisionName': 'INTERIOR'},
        'unit': {
          'unitId': 'car-3',
          'unitName': 'PORSCHE 911',
          'owner': 'Mr. Test',
        },
        'task': {
          'namaPanel': 'DOOR PANEL',
          'jobName': 'ASSEMBLY',
          'jobDescription': 'Pasang panel pintu',
          'startTime': '08:00',
          'targetFinishTime': '10:00',
        },
      });

      expect(model.totalActualHours, 8);
      expect(model.toEntity().hoursUsed, 8);
      expect(model.toEntity().progressPercent, 80);
    });

    test('prefers explicit semantic blocks from backend task payload', () {
      final model = TaskModel.fromTaskApiJson({
        'planDailyId': 'pd-4',
        'coreId': 'core-4',
        'status': 'PROSES',
        'planDaily': {
          'startTime': '09:00',
          'targetFinishTime': '11:00',
          'dailyTargetHours': 2,
        },
        'countdownCumulative': {
          'targetHoursTotal': 10,
          'remainingHours': 2,
          'totalActualHours': 8,
          'progressPercent': 80,
        },
        'executionLatest': {
          'startedAt': '2026-05-11T09:00:00+07:00',
          'completedAt': '2026-05-11T11:00:00+07:00',
          'status': 'pending',
        },
        'division': {'divisionName': 'INTERIOR'},
        'unit': {
          'unitId': 'car-4',
          'unitName': 'PORSCHE 964',
          'owner': 'Mr. Test',
        },
        'task': {
          'namaPanel': 'CENTER CONSOLE',
          'jobName': 'ASSEMBLY',
          'jobDescription': 'Pasang console',
        },
      });

      expect(model.dailyTargetHours, 2);
      expect(model.targetHoursRevised, 10);
      expect(model.remainingHours, 2);
      expect(model.totalActualHours, 8);
      expect(model.startTime, '09:00');
      expect(model.targetFinishTime, '11:00');
      expect(model.startedAt, '2026-05-11T09:00:00+07:00');
      expect(model.completedAt, '2026-05-11T11:00:00+07:00');
    });
  });

  group('ViewTaskModel.fromJson', () {
    test(
      'parses plan aliases and derives finish time for monitoring detail',
      () {
        final model = ViewTaskModel.fromJson({
          'planDailyId': 'pd-view-1',
          'status': 'PROSES',
          'daily_target_hours': 3.5,
          'plan_starttime': '08:30',
          'division': {'divisionId': 'div-1', 'divisionName': 'INTERIOR'},
          'unit': {'unitId': 'car-1', 'unitName': 'FERRARI F355'},
          'employee': {'employeeId': 'emp-1', 'employeeName': 'HARIS'},
          'task': {
            'nama_panel': 'DASHBOARD',
            'job_name': 'ASSEMBLY',
            'description': 'Pasang dashboard',
          },
          'checkpointHistory': const [],
        });

        expect(model.task.targetHours, 3.5);
        expect(model.task.startTime, '08:30');
        expect(model.task.targetFinishTime, '12:00');
      },
    );

    test(
      'maps cumulative target metrics for monitoring summary and detail',
      () {
        final model = ViewTaskModel.fromJson({
          'planDailyId': 'pd-view-2',
          'status': 'PROSES',
          'dailyTargetHours': 2,
          'division': {'divisionId': 'div-1', 'divisionName': 'INTERIOR'},
          'unit': {'unitId': 'car-1', 'unitName': 'FERRARI F355'},
          'employee': {'employeeId': 'emp-1', 'employeeName': 'HARIS'},
          'task': {
            'namaPanel': 'DASHBOARD',
            'jobName': 'ASSEMBLY',
            'description': 'Pasang dashboard',
            'target_hours_revised': 10,
            'remaining_hours': 2,
            'total_actual_hours': 8,
            'targetStartHours': '08:00',
          },
          'checkpointHistory': const [],
        });

        final entity = model.toEntity();
        expect(entity.task.targetHours, 2);
        expect(entity.task.targetHoursRevised, 10);
        expect(entity.task.remainingHours, 2);
        expect(entity.task.totalActualHours, 8);
        expect(entity.hoursUsed, 8);
        expect(entity.progressPercent, 80);
        expect(entity.task.targetFinishTime, '10:00');
      },
    );

    test('prefers explicit semantic blocks for monitoring payload', () {
      final model = ViewTaskModel.fromJson({
        'planDailyId': 'pd-view-3',
        'status': 'PROSES',
        'division': {'divisionId': 'div-1', 'divisionName': 'INTERIOR'},
        'unit': {'unitId': 'car-1', 'unitName': 'FERRARI F355'},
        'employee': {'employeeId': 'emp-1', 'employeeName': 'HARIS'},
        'planDaily': {
          'startTime': '08:00',
          'targetFinishTime': '10:00',
          'dailyTargetHours': 2,
        },
        'countdownCumulative': {
          'targetHoursTotal': 10,
          'remainingHours': 2,
          'totalActualHours': 8,
          'progressPercent': 80,
        },
        'executionLatest': {
          'startedAt': '2026-05-11T08:00:00+07:00',
          'completedAt': '2026-05-11T10:00:00+07:00',
        },
        'task': {
          'namaPanel': 'DASHBOARD',
          'jobName': 'ASSEMBLY',
          'description': 'Pasang dashboard',
        },
        'checkpointHistory': const [],
      });

      final entity = model.toEntity();
      expect(entity.task.targetHours, 2);
      expect(entity.task.targetHoursRevised, 10);
      expect(entity.task.remainingHours, 2);
      expect(entity.task.totalActualHours, 8);
      expect(entity.task.startTime, '08:00');
      expect(entity.task.targetFinishTime, '10:00');
      expect(entity.progressPercent, 80);
    });
  });
}
