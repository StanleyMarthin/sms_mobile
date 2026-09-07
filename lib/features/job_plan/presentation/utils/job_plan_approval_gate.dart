/*
Tujuan: Menentukan apakah role user boleh mereview status approval Job Plan tertentu.
Caller: JobPlanPage approval list/detail dan unit test job plan.
Dependensi: Tidak ada.
Main Functions: JobPlanApprovalGate.canReview().
Side Effects: Tidak ada.
*/

class JobPlanApprovalGate {
  JobPlanApprovalGate._();

  static bool canReview({
    required String? accessBucket,
    required String status,
  }) {
    final bucket = (accessBucket ?? '').toUpperCase();
    final normalizedStatus = status.toUpperCase();

    return switch (bucket) {
      'ADV' => normalizedStatus == 'PENDING_ADV',
      'KP' => normalizedStatus == 'PENDING_KP',
      'GLOBAL' =>
        normalizedStatus == 'PENDING_MP' || normalizedStatus == 'PENDING_PM',
      _ => false,
    };
  }
}
