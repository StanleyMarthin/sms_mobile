/*
Tujuan: Mengunci kalkulasi submit task execution untuk progress kumulatif, anchor tanggal task, dan split overtime.
Caller: flutter test.
Dependensi: flutter_test, material.dart, TaskExecutionFlowHelper.
Main Functions: test buildTaskDateTime, computeRealtimeProgressPercent, splitWorkedHours, resolveSubmitStatus.
Side Effects: Tidak ada; hanya assertion unit test.
*/
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/task_execution/presentation/utils/task_execution_flow_helper.dart';

void main() {
  group('TaskExecutionFlowHelper', () {
    test(
      'anchors submit timestamps to the task date instead of device today',
      () {
        final dt = TaskExecutionFlowHelper.buildTaskDateTime(
          taskDate: '2026-05-20',
          time: const TimeOfDay(hour: 9, minute: 30),
        );

        expect(dt.year, 2026);
        expect(dt.month, 5);
        expect(dt.day, 20);
        expect(dt.hour, 9);
        expect(dt.minute, 30);
      },
    );

    test('computes realtime progress against total target hours', () {
      final progress = TaskExecutionFlowHelper.computeRealtimeProgressPercent(
        recordedWorkedHours: 8,
        currentSessionHours: 1,
        totalTargetHours: 10,
      );

      expect(progress, 90);
    });

    test('resolves non-final submit status to pending', () {
      expect(
        TaskExecutionFlowHelper.resolveSubmitStatus(
          selectedStatus: 'pending',
          progressPercent: 80,
        ),
        'pending',
      );
      expect(
        TaskExecutionFlowHelper.resolveSubmitStatus(
          selectedStatus: 'done',
          progressPercent: 100,
        ),
        'done',
      );
    });

    test('splits weekday work into normal and overtime hours', () {
      final breakdown = TaskExecutionFlowHelper.splitWorkedHours(
        taskDate: '2026-05-13',
        startTime: const TimeOfDay(hour: 8, minute: 0),
        finishTime: const TimeOfDay(hour: 18, minute: 0),
        breakDurationMinutes: 60,
      );

      expect(breakdown.normalHours, 8);
      expect(breakdown.overtimeHours, 1);
      expect(breakdown.totalWorkedHours, 9);
    });

    test('splits saturday work using the 14:00 overtime threshold', () {
      final breakdown = TaskExecutionFlowHelper.splitWorkedHours(
        taskDate: '2026-05-16',
        startTime: const TimeOfDay(hour: 8, minute: 0),
        finishTime: const TimeOfDay(hour: 16, minute: 0),
        breakDurationMinutes: 0,
      );

      expect(breakdown.normalHours, 6);
      expect(breakdown.overtimeHours, 2);
      expect(breakdown.totalWorkedHours, 8);
    });
  });
}
