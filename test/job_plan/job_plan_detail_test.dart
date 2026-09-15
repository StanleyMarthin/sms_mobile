/*
Tujuan: Mengunci tampilan detail read-only Job Plan V2.
Caller: Flutter test runner.
Dependensi: JobPlanDetailPage dan JobPlan entity.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_detail_page.dart';

void main() {
  testWidgets('JobPlanDetailPage renders V2 read model without actions', (
    tester,
  ) async {
    final plan = JobPlan(
      planId: 'plan-1',
      coreId: 'core-1',
      carId: 'unit-1',
      sourceType: 'COUNTDOWN',
      sourceRefId: 'core-1',
      unitName: 'MB 220S',
      panelName: 'Dashboard Wood Trim',
      assignedDivision: 'Interior',
      assignedUserId: 'emp-1',
      assignedTo: 'Budi',
      description: 'Restore Dashboard Wood',
      targetHours: 4,
      workDate: '2026-09-15',
      startTime: '08:00',
      finishTime: '12:00',
      isOvertime: false,
      deadline: '2026-09-15',
      status: 'DIVISION_REVIEW',
      note: 'Polish veneer',
      panelId: 'panel-1',
      unitId: 'unit-1',
      countdownName: 'Restore Dashboard Wood',
      employeeId: 'emp-1',
      employeeName: 'Budi',
      taskDate: '2026-09-15',
      startMinute: 480,
      durationMinutes: 240,
      approvalState: 'DIVISION_REVIEW',
      executionState: 'NOT_STARTED',
      ledgerState: 'UNMATERIALIZED',
      version: 12,
      createdAt: DateTime.parse('2026-09-14T08:00:00+07:00'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JobPlanDetailPage(planId: 'plan-1', initialPlan: plan),
      ),
    );

    expect(find.text('MB 220S'), findsOneWidget);
    expect(find.text('Dashboard Wood Trim'), findsOneWidget);
    expect(find.text('Restore Dashboard Wood'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('15 Sept 2026'), findsOneWidget);
    expect(find.text('08:00 - 12:00'), findsOneWidget);
    expect(find.text('Review Divisi'), findsOneWidget);
    expect(find.text('Belum Mulai'), findsOneWidget);
    expect(find.text('Belum Terverifikasi'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('START'), findsNothing);
  });
}
