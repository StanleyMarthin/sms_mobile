/*
Tujuan: Mengunci mapper display state Job Plan V2.
Caller: Flutter test runner.
Dependensi: JobPlanV2StateMapper.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_v2_state_mapper.dart';

void main() {
  test('approval states are displayed without backend internals', () {
    expect(JobPlanV2StateMapper.approvalLabel('DRAFT'), 'Draft');
    expect(
      JobPlanV2StateMapper.approvalLabel('DIVISION_REVIEW'),
      'Review Divisi',
    );
    expect(JobPlanV2StateMapper.approvalLabel('UNIT_REVIEW'), 'Review KP');
    expect(
      JobPlanV2StateMapper.approvalLabel('MANAGEMENT_REVIEW'),
      'Review Management',
    );
    expect(JobPlanV2StateMapper.approvalLabel('APPROVED'), 'Approved');
    expect(JobPlanV2StateMapper.approvalLabel('REJECTED'), 'Rejected');
  });

  test('execution and ledger state labels are deterministic', () {
    expect(JobPlanV2StateMapper.executionLabel('NOT_STARTED'), 'Belum Mulai');
    expect(JobPlanV2StateMapper.executionLabel('RUNNING'), 'Berjalan');
    expect(JobPlanV2StateMapper.executionLabel('HOLD'), 'Hold');
    expect(
      JobPlanV2StateMapper.executionLabel('FINISHED_PENDING_VALIDATION'),
      'Menunggu Validasi KD',
    );
    expect(JobPlanV2StateMapper.executionLabel('VALIDATED'), 'Tervalidasi');
    expect(
      JobPlanV2StateMapper.ledgerLabel('UNMATERIALIZED'),
      'Belum Terverifikasi',
    );
    expect(JobPlanV2StateMapper.ledgerLabel('MATERIALIZED'), 'Terverifikasi');
    expect(JobPlanV2StateMapper.ledgerLabel('FINALIZED'), 'Final');
  });
}
