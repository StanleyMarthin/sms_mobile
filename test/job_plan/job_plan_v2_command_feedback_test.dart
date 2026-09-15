/*
Tujuan: Mengunci pesan konflik command/version Job Plan V2 dan sinyal refresh.
Caller: Flutter test runner.
Dependensi: Failure dan JobPlanV2CommandFeedback.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_v2_command_feedback.dart';

void main() {
  test('stale plan conflict asks UI to refresh backend state', () {
    const failure = ClientFailure(errorCode: 'ERR_STALE_PLAN');

    expect(JobPlanV2CommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      JobPlanV2CommandFeedback.message(failure),
      'Data Job Plan berubah. Memuat ulang data terbaru.',
    );
  });

  test('idempotency conflict is shown without backend details', () {
    const failure = ClientFailure(errorCode: 'ERR_IDEMPOTENCY_CONFLICT');

    expect(JobPlanV2CommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      JobPlanV2CommandFeedback.message(failure),
      'Command ID sudah dipakai untuk data berbeda.',
    );
  });
}
