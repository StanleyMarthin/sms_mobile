/*
Tujuan: Mengunci kontrak parsing read model Job Plan V2 dari backend.
Caller: Flutter test runner.
Dependensi: JobPlanV2Model dan CommandMetadata.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/data/models/job_plan_v2_model.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';

void main() {
  test('JobPlanV2Model maps Countdown-owned V2 read contract', () {
    final plan = JobPlanV2Model.fromJson({
      'planId': 'plan-1',
      'coreId': 'core-1',
      'panelId': 'panel-1',
      'unitId': 'unit-1',
      'unitName': 'MB 220S',
      'panelName': 'Dashboard Wood Trim',
      'countdownName': 'Restore Dashboard Wood',
      'employeeId': 'emp-1',
      'employeeName': 'Budi',
      'taskDate': '2026-09-15',
      'startMinute': 480,
      'durationMinutes': 240,
      'approvalState': 'DIVISION_REVIEW',
      'executionState': 'NOT_STARTED',
      'ledgerState': 'UNMATERIALIZED',
      'version': 12,
      'createdAt': '2026-09-14T08:00:00+07:00',
    }).toEntity();

    expect(plan.id, 'plan-1');
    expect(plan.sourceType, 'COUNTDOWN');
    expect(plan.sourceId, 'core-1');
    expect(plan.coreId, 'core-1');
    expect(plan.panelId, 'panel-1');
    expect(plan.unitId, 'unit-1');
    expect(plan.countdownName, 'Restore Dashboard Wood');
    expect(plan.employeeId, 'emp-1');
    expect(plan.employeeName, 'Budi');
    expect(plan.taskDate, '2026-09-15');
    expect(plan.startMinute, 480);
    expect(plan.durationMinutes, 240);
    expect(plan.approvalState, 'DIVISION_REVIEW');
    expect(plan.executionState, 'NOT_STARTED');
    expect(plan.ledgerState, 'UNMATERIALIZED');
    expect(plan.version, 12);
  });

  test('CommandMetadata carries command id and expected version only', () {
    const metadata = CommandMetadata(
      commandId: 'mobile-approval-1',
      expectedVersion: 12,
    );

    expect(metadata.commandId, 'mobile-approval-1');
    expect(metadata.expectedVersion, 12);
  });
}
