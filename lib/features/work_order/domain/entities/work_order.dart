import 'package:equatable/equatable.dart';

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

  /// Stage dari Redis: PENDING_KD_TARGET | PENDING_ADVISOR | PENDING_KP | PENDING_MP | APPROVED
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

  /// Untuk countdown setelah APPROVED
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
    this.coreId,
  });

  // ── Status helpers ──
  bool get isOpen => status == 'OPEN' || currentStage != null;
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isDone => status == 'DONE';
  bool get isActive => !isApproved && !isDone && !isRejected;

  bool get waitingKdTarget => currentStage == 'PENDING_KD_TARGET';
  bool get waitingAdvisor => currentStage == 'PENDING_ADVISOR';
  bool get waitingKp => currentStage == 'PENDING_KP';
  bool get waitingMp => currentStage == 'PENDING_MP';

  String get stageBadge {
    if (isApproved) return 'APPROVED';
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
      coreId: coreId ?? this.coreId,
    );
  }

  @override
  List<Object?> get props => [id, woNumber, status, currentStage, estimatedHours];
}
