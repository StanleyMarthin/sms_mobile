/*
Tujuan: Mengunci helper display approval V2 dan actor yang sedang ditunggu.
Caller: Flutter test runner.
Dependensi: JobPlanV2StateMapper.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_v2_state_mapper.dart';

void main() {
  test('approval waiting labels follow V2 semantic states', () {
    expect(JobPlanV2StateMapper.waitingFor('DIVISION_REVIEW'), 'ADV / QA');
    expect(JobPlanV2StateMapper.waitingFor('UNIT_REVIEW'), 'KP Unit');
    expect(JobPlanV2StateMapper.waitingFor('MANAGEMENT_REVIEW'), 'MP / PM');
    expect(JobPlanV2StateMapper.waitingFor('APPROVED'), '-');
  });
}
