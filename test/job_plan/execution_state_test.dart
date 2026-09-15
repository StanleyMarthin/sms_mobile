/*
Tujuan: Mengunci state execution V2 mobile tetap dari backend, bukan status lokal.
Caller: Flutter test runner.
Dependensi: TaskModel.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/task_execution/data/models/task_model.dart';

void main() {
  test('V2 execution actions are gated by backend states and version', () {
    final ready = TaskModel.fromJson({
      'planId': 'plan-1',
      'approvalState': 'APPROVED',
      'executionState': 'NOT_STARTED',
      'ledgerState': 'UNMATERIALIZED',
      'projectionReady': true,
      'version': 8,
    }).toEntity();
    final waitingValidation = TaskModel.fromJson({
      'planId': 'plan-2',
      'approvalState': 'APPROVED',
      'executionState': 'FINISHED_PENDING_VALIDATION',
      'ledgerState': 'MATERIALIZED',
      'projectionReady': true,
      'version': 12,
    }).toEntity();

    expect(ready.canStart, isTrue);
    expect(ready.version, 8);
    expect(waitingValidation.canStart, isFalse);
    expect(waitingValidation.mobileExecutionLabel, 'Menunggu KD');
  });
}
