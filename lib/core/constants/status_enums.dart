/// Status state machines for all business entities.
///
/// These enums mirror the backend status columns and define valid
/// state transitions for the UI.
library;

// ── Job Plan ────────────────────────────────────────────────

enum JobPlanStatus {
  planCreated,
  pendingAdv,
  pendingPm,
  approved,
  onProgress,
  done,
  rejected;

  static JobPlanStatus? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'PLAN_CREATED' => planCreated,
      'PENDING_ADV' => pendingAdv,
      'PENDING_PM' => pendingPm,
      'APPROVED' => approved,
      'ON_PROGRESS' => onProgress,
      'DONE' => done,
      'REJECTED' => rejected,
      _ => null,
    };
  }

  String get label => switch (this) {
    planCreated => 'Draft',
    pendingAdv => 'Menunggu Advisor',
    pendingPm => 'Menunggu PM',
    approved => 'Disetujui',
    onProgress => 'Sedang Berjalan',
    done => 'Selesai',
    rejected => 'Ditolak',
  };
}

// ── Task Execution ──────────────────────────────────────────

enum TaskExecutionStatus {
  assigned,
  onProgress,
  submitted,
  done;

  static TaskExecutionStatus? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'ASSIGNED' => assigned,
      'ON_PROGRESS' => onProgress,
      'SUBMITTED' => submitted,
      'DONE' => done,
      _ => null,
    };
  }

  String get label => switch (this) {
    assigned => 'Ditugaskan',
    onProgress => 'Sedang Dikerjakan',
    submitted => 'Dikirim',
    done => 'Selesai',
  };
}

// ── QC ──────────────────────────────────────────────────────

enum QcStatus {
  noQc,
  qcKd,
  qcValidated,
  rework;

  static QcStatus? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'NO_QC' => noQc,
      'QC_KD' => qcKd,
      'QC_VALIDATED' => qcValidated,
      'REWORK' => rework,
      _ => null,
    };
  }

  String get label => switch (this) {
    noQc => 'Belum QC',
    qcKd => 'QC oleh KD',
    qcValidated => 'QC Tervalidasi',
    rework => 'Perlu Perbaikan',
  };
}

// ── Work Order ──────────────────────────────────────────────

enum WorkOrderStatus {
  created,
  pendingTargetKd,
  pendingAdvisor,
  pendingPm,
  approved,
  countdownCreated;

  static WorkOrderStatus? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'CREATED' => created,
      'PENDING_TARGET_KD' => pendingTargetKd,
      'PENDING_ADVISOR' => pendingAdvisor,
      'PENDING_PM' => pendingPm,
      'APPROVED' => approved,
      'COUNTDOWN_CREATED' => countdownCreated,
      _ => null,
    };
  }

  String get label => switch (this) {
    created => 'Dibuat',
    pendingTargetKd => 'Menunggu KD Tujuan',
    pendingAdvisor => 'Menunggu Advisor',
    pendingPm => 'Menunggu PM',
    approved => 'Disetujui',
    countdownCreated => 'Countdown Dibuat',
  };
}

// ── Warehouse ───────────────────────────────────────────────

enum WarehouseStatus {
  requested,
  pendingKd,
  approved,
  taken,
  returned;

  static WarehouseStatus? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'REQUESTED' => requested,
      'PENDING_KD' => pendingKd,
      'APPROVED' => approved,
      'TAKEN' => taken,
      'RETURNED' => returned,
      _ => null,
    };
  }

  String get label => switch (this) {
    requested => 'Diminta',
    pendingKd => 'Menunggu KD',
    approved => 'Disetujui',
    taken => 'Diambil',
    returned => 'Dikembalikan',
  };
}

// ── Warehouse Transaction Type ──────────────────────────────

enum WarehouseTransactionType {
  peminjaman,
  pengambilan,
  pengembalian;

  static WarehouseTransactionType? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'PEMINJAMAN' => peminjaman,
      'PENGAMBILAN' => pengambilan,
      'PENGEMBALIAN' => pengembalian,
      _ => null,
    };
  }

  String get label => switch (this) {
    peminjaman => 'Peminjaman',
    pengambilan => 'Pengambilan',
    pengembalian => 'Pengembalian',
  };
}
