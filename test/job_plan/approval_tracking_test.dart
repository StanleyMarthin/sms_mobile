/*
Tujuan: Mengunci approval tracking Job Plan V2 tetap read-only.
Caller: Flutter test runner.
Dependensi: JobPlanApprovalTrackingPage dan JobPlan entity.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_approval_tracking_page.dart';

void main() {
  testWidgets('tracking shows current approval step without mutations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JobPlanApprovalTrackingPage(
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
              targetHours: 4,
              workDate: '2026-09-15',
              startTime: '08:00',
              finishTime: '12:00',
              isOvertime: false,
              deadline: '2026-09-15',
              status: 'UNIT_REVIEW',
              note: '',
              approvalState: 'UNIT_REVIEW',
              executionState: 'NOT_STARTED',
              ledgerState: 'UNMATERIALIZED',
              version: 4,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approval Tracking'), findsOneWidget);
    expect(find.text('KP: Waiting'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });
}
