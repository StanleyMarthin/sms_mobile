/*
Tujuan: Mengunci mapper display state Job Plan.
Caller: Flutter test runner.
Dependensi: JobPlanStateMapper.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_state_mapper.dart';

void main() {
  test('approval states are displayed without backend internals', () {
    expect(JobPlanStateMapper.approvalLabel('DRAFT'), 'Draft');
    expect(
      JobPlanStateMapper.approvalLabel('DIVISION_REVIEW'),
      'Review Divisi',
    );
    expect(JobPlanStateMapper.approvalLabel('UNIT_REVIEW'), 'Review KP');
    expect(
      JobPlanStateMapper.approvalLabel('MANAGEMENT_REVIEW'),
      'Review Management',
    );
    expect(JobPlanStateMapper.approvalLabel('APPROVED'), 'Approved');
    expect(JobPlanStateMapper.approvalLabel('REJECTED'), 'Rejected');
  });

  test('execution and ledger state labels are deterministic', () {
    expect(JobPlanStateMapper.executionLabel('NOT_STARTED'), 'Belum Mulai');
    expect(JobPlanStateMapper.executionLabel('RUNNING'), 'Berjalan');
    expect(JobPlanStateMapper.executionLabel('HOLD'), 'Hold');
    expect(
      JobPlanStateMapper.executionLabel('FINISHED_PENDING_VALIDATION'),
      'Menunggu Validasi KD',
    );
    expect(JobPlanStateMapper.executionLabel('VALIDATED'), 'Tervalidasi');
    expect(
      JobPlanStateMapper.ledgerLabel('UNMATERIALIZED'),
      'Belum Terverifikasi',
    );
    expect(JobPlanStateMapper.ledgerLabel('MATERIALIZED'), 'Terverifikasi');
    expect(JobPlanStateMapper.ledgerLabel('FINALIZED'), 'Final');
  });
}
