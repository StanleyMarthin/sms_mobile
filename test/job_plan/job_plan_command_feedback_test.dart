/*
Tujuan: Mengunci pesan konflik command/version Job Plan dan sinyal refresh.
Caller: Flutter test runner.
Dependensi: Failure dan JobPlanCommandFeedback.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_command_feedback.dart';

void main() {
  test('stale plan conflict asks UI to refresh backend state', () {
    const failure = ClientFailure(errorCode: 'ERR_STALE_PLAN');

    expect(JobPlanCommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      JobPlanCommandFeedback.message(failure),
      'Data Job Plan berubah. Memuat ulang data terbaru.',
    );
  });

  test('idempotency conflict is shown without backend details', () {
    const failure = ClientFailure(errorCode: 'ERR_IDEMPOTENCY_CONFLICT');

    expect(JobPlanCommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      JobPlanCommandFeedback.message(failure),
      'Command ID sudah dipakai untuk data berbeda.',
    );
  });

  test('invalid transition asks UI to reload latest state', () {
    const failure = ClientFailure(errorCode: 'ERR_INVALID_TRANSITION');

    expect(JobPlanCommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      JobPlanCommandFeedback.message(failure),
      'Status Job Plan sudah berubah. Memuat ulang data terbaru.',
    );
  });

  test('employee already running uses execution-specific message', () {
    const failure = ClientFailure(errorCode: 'ERR_EMPLOYEE_ALREADY_RUNNING');

    expect(JobPlanCommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      JobPlanCommandFeedback.message(failure),
      'PIC masih menjalankan pekerjaan lain. Memuat ulang jadwal terbaru.',
    );
  });
}
