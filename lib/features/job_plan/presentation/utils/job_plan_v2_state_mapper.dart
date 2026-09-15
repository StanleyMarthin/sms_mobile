/*
Tujuan: Mapper label display untuk state Job Plan V2.
Caller: JobPlan detail/list page dan unit test.
Dependensi: Tidak ada.
Main Functions: approvalLabel, executionLabel, ledgerLabel.
Side Effects: Tidak ada.
*/
library;

class JobPlanV2StateMapper {
  JobPlanV2StateMapper._();

  static String approvalLabel(String? value) {
    return switch (_key(value)) {
      'DRAFT' => 'Draft',
      'DIVISION_REVIEW' => 'Review Divisi',
      'UNIT_REVIEW' => 'Review KP',
      'MANAGEMENT_REVIEW' => 'Review Management',
      'APPROVED' => 'Approved',
      'REJECTED' => 'Rejected',
      final raw => raw.isEmpty ? '-' : raw,
    };
  }

  static String executionLabel(String? value) {
    return switch (_key(value)) {
      'NOT_STARTED' => 'Belum Mulai',
      'RUNNING' => 'Berjalan',
      'HOLD' => 'Hold',
      'FINISHED_PENDING_VALIDATION' => 'Menunggu Validasi KD',
      'VALIDATED' => 'Tervalidasi',
      final raw => raw.isEmpty ? '-' : raw,
    };
  }

  static String ledgerLabel(String? value) {
    return switch (_key(value)) {
      'UNMATERIALIZED' => 'Belum Terverifikasi',
      'MATERIALIZED' => 'Terverifikasi',
      'FINALIZED' => 'Final',
      final raw => raw.isEmpty ? '-' : raw,
    };
  }

  static String waitingFor(String? approvalState) {
    return switch (_key(approvalState)) {
      'DIVISION_REVIEW' => 'ADV / QA',
      'UNIT_REVIEW' => 'KP Unit',
      'MANAGEMENT_REVIEW' => 'MP / PM',
      final _ => '-',
    };
  }

  static String _key(String? value) => (value ?? '').trim().toUpperCase();
}
