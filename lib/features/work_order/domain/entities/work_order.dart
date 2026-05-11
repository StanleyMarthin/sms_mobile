/*
Tujuan: Entity dan helper normalisasi status Work Order lintas approval, countdown, dan jobdesc.
Caller: WorkOrderRemoteDataSource, WorkOrderBloc, WoDetailPage, WoCard, dan JobPlanPage saat WO jadi source jobdesc.
Dependensi: Equatable.
Main Functions: normalizeWoStage, normalizeWoStatus, WorkOrder, WoApprovalStage.
Side Effects: Tidak langsung; dipakai untuk menjaga konsistensi mapping data API/Redis ke UI.
*/
import 'package:equatable/equatable.dart';

String normalizeWoStage(String? raw) {
  final value = raw?.trim().toUpperCase() ?? '';
  return switch (value) {
    'PENDING_TARGET_KD' ||
    'PENDING_KD' ||
    'PENDING_KD_APPROVAL' ||
    'PENDING_KD_TARGET' => 'PENDING_KD_TARGET',
    'PENDING_ADVISOR' ||
    'PENDING_ADV' ||
    'PENDING_ADVISOR_APPROVAL' => 'PENDING_ADVISOR',
    'PENDING_KP' ||
    'PENDING_PROJECT_HEAD' ||
    'PENDING_KEPALA_PROJECT' ||
    'PENDING_KP_APPROVAL' => 'PENDING_KP',
    'PENDING_MP' ||
    'PENDING_PM' ||
    'PENDING_MANAGER' ||
    'PENDING_PROJECT_MANAGER' ||
    'PENDING_MP_APPROVAL' => 'PENDING_MP',
    _ => value,
  };
}

String normalizeWoStatus(String? rawStatus, {String? currentStage}) {
  final value = rawStatus?.trim().toUpperCase() ?? '';
  if (value.isEmpty) {
    final normalizedStage = normalizeWoStage(currentStage);
    if (normalizedStage.startsWith('PENDING_')) return 'OPEN';
    return normalizedStage.isEmpty ? 'OPEN' : normalizedStage;
  }

  return switch (value) {
    'CREATED' || 'OPEN' || 'SUBMITTED' => 'OPEN',
    'COUNTDOWN_READY' || 'COUNTDOWN_CREATED' => 'COUNTDOWN_CREATED',
    'IN_PROGRESS' || 'ON_PROGRESS' || 'PROGRESS' || 'PROSES' => 'ON_PROGRESS',
    'COMPLETED' || 'FINISHED' || 'SELESAI' || 'DONE' => 'DONE',
    'REJECT' || 'REJECTED' => 'REJECTED',
    'APPROVED' => 'APPROVED',
    _ => () {
      final normalizedStage = normalizeWoStage(value);
      if (normalizedStage.startsWith('PENDING_')) return 'OPEN';
      return value;
    }(),
  };
}

/// Approval stage dari Redis state
class WoApprovalStage extends Equatable {
  final String role;
  final String? userId;
  final String? name;
  final String? actionAt;
  final String? notes;
  final double? estimatedHours;

  const WoApprovalStage({
    required this.role,
    this.userId,
    this.name,
    this.actionAt,
    this.notes,
    this.estimatedHours,
  });

  factory WoApprovalStage.fromJson(Map<String, dynamic> j) => WoApprovalStage(
    role: '${j['role'] ?? ''}',
    userId: j['user_id']?.toString(),
    name: j['name']?.toString(),
    actionAt: j['action_at']?.toString(),
    notes: j['notes']?.toString(),
    estimatedHours: (j['estimated_hours'] as num?)?.toDouble(),
  );

  @override
  List<Object?> get props => [role, userId, actionAt];
}

/// Entity Work Order — sesuai Redis State Machine
class WorkOrder extends Equatable {
  final String id;
  final String woNumber;
  final String carId;
  final String unitName;
  final String ownerName;
  final String toDivId;
  final String toDivName;
  final String fromDivId;
  final String fromDivName;
  final String? panelName;
  final String jobDetail;
  final double? estimatedHours;
  final String status;

  /// Stage approval aktif dari Redis/API setelah dinormalisasi.
  final String? currentStage;

  /// Apakah unit punya advisor (dari Redis state)
  final bool needsAdvisor;

  /// Riwayat approval (dari Redis stages_done)
  final List<WoApprovalStage> stagesDone;

  /// Nama yang memberikan estimasi terakhir
  final String? estimatedByName;

  final String? requestDate;
  final String? approvalDate;
  final String? notes;

  /// PIC/Pelaksana yang dipilih KD Target
  final String? picId;
  final String? picName;
  final bool accAdvisor;

  /// Referensi countdown/core job setelah final approval.
  final String? coreId;

  const WorkOrder({
    required this.id,
    required this.woNumber,
    required this.carId,
    required this.unitName,
    required this.ownerName,
    required this.toDivId,
    required this.toDivName,
    required this.fromDivId,
    required this.fromDivName,
    this.panelName,
    required this.jobDetail,
    this.estimatedHours,
    required this.status,
    this.currentStage,
    this.needsAdvisor = false,
    this.stagesDone = const [],
    this.estimatedByName,
    this.requestDate,
    this.approvalDate,
    this.notes,
    this.picId,
    this.picName,
    this.accAdvisor = false,
    this.coreId,
  });

  // ── Status helpers ──
  bool get isOpen =>
      status == 'OPEN' ||
      status == 'SUBMITTED' ||
      (currentStage?.startsWith('PENDING_') ?? false);
  bool get isApproved => status == 'APPROVED' || status == 'COUNTDOWN_CREATED';
  bool get isInProgress => status == 'ON_PROGRESS';
  bool get isRejected => status == 'REJECTED';
  bool get isDone => status == 'DONE';
  bool get hasCountdownLink =>
      (coreId ?? '').trim().isNotEmpty || isApproved || isInProgress || isDone;
  bool get isReadyForJobdesc =>
      status == 'APPROVED' ||
      status == 'COUNTDOWN_CREATED' ||
      status == 'ON_PROGRESS';

  /// ACTIVE = semua status yang belum benar-benar selesai dikerjakan
  bool get isActive => !isDone && !isRejected;

  bool get waitingKdTarget => currentStage == 'PENDING_KD_TARGET';
  bool get waitingAdvisor => currentStage == 'PENDING_ADVISOR';
  bool get waitingKp => currentStage == 'PENDING_KP';
  bool get waitingMp => currentStage == 'PENDING_MP';

  String get stageBadge {
    if (status == 'COUNTDOWN_CREATED') return 'COUNTDOWN_CREATED';
    if (isInProgress) return 'ON_PROGRESS';
    if (status == 'APPROVED') return 'APPROVED';
    if (isRejected) return 'REJECTED';
    if (isDone) return 'DONE';
    return currentStage ?? status;
  }

  WorkOrder copyWith({
    String? id,
    String? woNumber,
    String? carId,
    String? unitName,
    String? ownerName,
    String? toDivId,
    String? toDivName,
    String? fromDivId,
    String? fromDivName,
    String? panelName,
    String? jobDetail,
    double? estimatedHours,
    String? status,
    String? currentStage,
    bool? needsAdvisor,
    List<WoApprovalStage>? stagesDone,
    String? estimatedByName,
    String? requestDate,
    String? approvalDate,
    String? notes,
    String? picId,
    String? picName,
    bool? accAdvisor,
    String? coreId,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      woNumber: woNumber ?? this.woNumber,
      carId: carId ?? this.carId,
      unitName: unitName ?? this.unitName,
      ownerName: ownerName ?? this.ownerName,
      toDivId: toDivId ?? this.toDivId,
      toDivName: toDivName ?? this.toDivName,
      fromDivId: fromDivId ?? this.fromDivId,
      fromDivName: fromDivName ?? this.fromDivName,
      panelName: panelName ?? this.panelName,
      jobDetail: jobDetail ?? this.jobDetail,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      status: status ?? this.status,
      currentStage: currentStage ?? this.currentStage,
      needsAdvisor: needsAdvisor ?? this.needsAdvisor,
      stagesDone: stagesDone ?? this.stagesDone,
      estimatedByName: estimatedByName ?? this.estimatedByName,
      requestDate: requestDate ?? this.requestDate,
      approvalDate: approvalDate ?? this.approvalDate,
      notes: notes ?? this.notes,
      picId: picId ?? this.picId,
      picName: picName ?? this.picName,
      accAdvisor: accAdvisor ?? this.accAdvisor,
      coreId: coreId ?? this.coreId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    woNumber,
    status,
    currentStage,
    estimatedHours,
  ];
}
