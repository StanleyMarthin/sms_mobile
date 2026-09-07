/*
Tujuan: Mengunci aturan role vs status approval Job Plan.
Caller: flutter test.
Dependensi: JobPlanApprovalGate.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_approval_gate.dart';

void main() {
  test('KP can review only KP pending plans', () {
    expect(
      JobPlanApprovalGate.canReview(accessBucket: 'KP', status: 'PENDING_KP'),
      isTrue,
    );
    expect(
      JobPlanApprovalGate.canReview(accessBucket: 'KP', status: 'PENDING_MP'),
      isFalse,
    );
  });

  test('global management can review only MP pending plans', () {
    expect(
      JobPlanApprovalGate.canReview(
        accessBucket: 'GLOBAL',
        status: 'PENDING_MP',
      ),
      isTrue,
    );
    expect(
      JobPlanApprovalGate.canReview(
        accessBucket: 'GLOBAL',
        status: 'PENDING_KP',
      ),
      isFalse,
    );
  });

  test('ADV can review only ADV pending plans', () {
    expect(
      JobPlanApprovalGate.canReview(accessBucket: 'ADV', status: 'PENDING_ADV'),
      isTrue,
    );
    expect(
      JobPlanApprovalGate.canReview(accessBucket: 'ADV', status: 'PENDING_KP'),
      isFalse,
    );
  });
}
