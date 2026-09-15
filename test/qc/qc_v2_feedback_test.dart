/*
Tujuan: Mengunci pesan error command QC V2 dan kebutuhan refresh state.
Caller: Flutter test runner.
Dependensi: Failure dan QcV2CommandFeedback.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/features/qc/presentation/utils/qc_v2_command_feedback.dart';

void main() {
  test('stale QC asks UI to refresh', () {
    const failure = ClientFailure(errorCode: 'ERR_STALE_QC');

    expect(QcV2CommandFeedback.shouldRefresh(failure), isTrue);
    expect(
      QcV2CommandFeedback.message(failure),
      'Data QC sudah berubah. Memuat ulang data terbaru.',
    );
  });

  test('idempotency and V2 ownership conflicts are safe messages', () {
    expect(
      QcV2CommandFeedback.message(
        const ClientFailure(errorCode: 'ERR_IDEMPOTENCY_CONFLICT'),
      ),
      'Command ID sudah dipakai untuk data berbeda.',
    );
    expect(
      QcV2CommandFeedback.message(
        const ClientFailure(errorCode: 'ERR_V2_CORE_OWNED'),
      ),
      'Core ini dikelola Job Plan V2. Muat ulang antrean QC.',
    );
  });
}
