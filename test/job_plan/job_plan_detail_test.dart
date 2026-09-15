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
      accumulatedMinutes: 300,
      verifiedMinutes: 120,
      unverifiedMinutes: 180,
      progress: 40,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: JobPlanDetailPage(planId: 'plan-1', initialPlan: plan),
      ),
    );

    expect(find.text('MB 220S'), findsWidgets);
    expect(find.text('Dashboard Wood Trim'), findsWidgets);
    expect(find.text('Restore Dashboard Wood'), findsWidgets);
    expect(find.text('Interior'), findsOneWidget);
    expect(find.text('Job Description'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('15 Sept 2026'), findsOneWidget);
    expect(find.text('08:00 - 12:00'), findsOneWidget);
    expect(find.text('Approval Timeline'), findsOneWidget);
    expect(find.text('Review KP'), findsOneWidget);
    expect(find.text('Review Management'), findsOneWidget);
    expect(find.text('Review Divisi'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Monitoring'), findsOneWidget);
    expect(find.text('Verified Hours'), findsOneWidget);
    expect(find.text('2 jam 0 menit'), findsOneWidget);
    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.text('3 jam 0 menit'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Belum Mulai'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Belum Terverifikasi'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('START'), findsNothing);
  });
}
