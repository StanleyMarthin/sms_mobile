/*
Tujuan: Mengunci tampilan planner calendar Job Plan V2 tetap read-only.
Caller: Flutter test runner.
Dependensi: JobPlanCalendarPage dan JobPlan entity.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_calendar_page.dart';

void main() {
  testWidgets('calendar displays backend schedule without action buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPlanCalendarPage(
            initialPlans: [
              _plan('plan-2', '10:00', 600),
              _plan('plan-1', '08:00', 480),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('08:00 - 12:00'), findsOneWidget);
    expect(find.text('10:00 - 14:00'), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Unit ID'), findsOneWidget);
    expect(find.text('PIC ID'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('START'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });
}

JobPlan _plan(String id, String start, int startMinute) {
  return JobPlan(
    planId: id,
    coreId: 'core-$id',
    carId: 'unit-1',
    sourceType: 'COUNTDOWN',
    sourceRefId: 'core-$id',
    unitName: 'MB220S',
    panelName: 'Dashboard Wood',
    assignedDivision: 'Interior',
    assignedUserId: 'emp-1',
    assignedTo: 'Budi',
    description: 'Restore Dashboard',
    targetHours: 4,
    workDate: '2026-09-15',
    startTime: start,
    finishTime: start == '08:00' ? '12:00' : '14:00',
    isOvertime: false,
    deadline: '2026-09-15',
    status: 'APPROVED',
    note: '',
    approvalState: 'APPROVED',
    executionState: 'NOT_STARTED',
    ledgerState: 'UNMATERIALIZED',
    version: 1,
    startMinute: startMinute,
    durationMinutes: 240,
  );
}
