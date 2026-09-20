/*
Tujuan: Mengunci helper display approval V2 dan actor yang sedang ditunggu.
Caller: Flutter test runner.
Dependensi: JobPlanStateMapper.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_state_mapper.dart';

void main() {
  test('approval waiting labels follow V2 semantic states', () {
    expect(JobPlanStateMapper.waitingFor('DIVISION_REVIEW'), 'ADV / QA');
    expect(JobPlanStateMapper.waitingFor('UNIT_REVIEW'), 'KP Unit');
    expect(JobPlanStateMapper.waitingFor('MANAGEMENT_REVIEW'), 'MP / PM');
    expect(JobPlanStateMapper.waitingFor('APPROVED'), '-');
  });
}
