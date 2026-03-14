import 'package:equatable/equatable.dart';

/// Represents a Work Order (WO) or Work Order Vendor (WOV) created by KD.
///
/// WO: Request to another division (inter-KD) within SM Restoration.
/// WOV: Request to an external vendor (e.g., chrome plating, special machining).
///
/// Flow: KD creates → Advisor approves → PM approves → work begins.
/// Deadline extension: only the requesting KD can modify the deadline.
///
/// Status flow:
///   DRAFT → PENDING_ADVISOR → PENDING_PM → APPROVED → IN_PROGRESS → DONE
///   At any approval step, can be → REJECTED
///
/// Maps to: trx_wo table in ERP
class WorkOrder extends Equatable {
  /// Unique WO identifier. From: trx_wo.id
  final String id;

  /// WO display number. From: trx_wo.wo_number
  /// Example: "WO-MEC-2026-0042"
  final String woNumber;

  /// Type of work order: 'WO' (internal) or 'WOV' (vendor)
  final String woType;

  /// The car/unit this WO is for. From: cars.id
  final String carId;

  /// Human-readable car name. From: cars.unit_name
  final String unitName;

  /// Owner name. From: cars.owner_name
  final String ownerName;

  /// Panel being worked on. From: master_panels.name
  final String panelName;

  /// Optional part name under the panel.
  final String? partName;

  /// Optional job description label selected from master list.
  final String? jobdescName;

  /// The originating core job. From: trx_jobdesc_core.id
  final String coreId;

  /// Description of what work is needed.
  final String description;

  /// Division requesting the WO (KD's division). From: sm_divisi.name
  final String fromDivision;

  /// Target division (for WO) or vendor name (for WOV).
  final String toDivision;

  /// Estimated hours for the work.
  final double estimatedHours;

  /// Priority level: 'NORMAL' or 'HIGH'
  final String priority;

  /// Current status:
  /// 'DRAFT', 'PENDING_ADVISOR', 'PENDING_PM',
  /// 'APPROVED', 'REJECTED', 'IN_PROGRESS', 'DONE'
  final String status;

  /// Notes / additional context.
  final String notes;

  /// Who submitted this WO (KD). From: sm_employee.id
  final String requestedById;

  /// Name of the requester (KD). From: sm_employee.full_name
  final String requestedByName;

  /// ISO 8601 timestamp when WO was created.
  final String createdAt;

  // ── Deadline ──

  /// Target deadline for completion (ISO 8601 date, e.g. '2026-03-01').
  final String? deadline;

  // ── Approval chain ──

  /// ISO 8601 timestamp when Advisor approved (null if not yet).
  final String? advisorApprovedAt;

  /// Name of the advisor who approved.
  final String? advisorApprovedBy;

  /// ISO 8601 timestamp when PM approved (null if not yet).
  final String? pmApprovedAt;

  /// Name of the PM who approved.
  final String? pmApprovedBy;

  /// Reason for rejection (if status == REJECTED).
  final String? rejectedReason;

  /// Name of who rejected.
  final String? rejectedBy;

  // ── Deadline extension ──

  /// Previous deadline before extension (null if never extended).
  final String? previousDeadline;

  /// Reason for deadline extension request.
  final String? extensionReason;

  /// Legacy field — kept for backward compat.
  final String? approvedAt;

  // ── Revision request (ADV/PM) ──

  /// 'PENDING', 'APPROVED', 'REJECTED' for current revision cycle.
  final String? revisionRequestStatus;

  /// Requested revised estimate in hours.
  final double? requestedEstimatedHours;

  /// Requested revised deadline (YYYY-MM-DD).
  final String? requestedDeadline;

  /// Reason from ADV/PM when asking revision.
  final String? revisionReason;

  /// Name of reviewer that requested/handled revision.
  final String? revisionReviewedBy;

  // ── Deadline extension request (KD -> ADV/PM) ──

  /// 'PENDING', 'APPROVED', 'REJECTED' for extension request.
  final String? extensionRequestStatus;

  /// Requested new deadline before approval.
  final String? extensionRequestedDeadline;

  /// Requested reason before approval.
  final String? extensionRequestedReason;

  /// Name of reviewer that approved/rejected extension request.
  final String? extensionReviewedBy;

  const WorkOrder({
    required this.id,
    required this.woNumber,
    required this.woType,
    required this.carId,
    required this.unitName,
    required this.ownerName,
    required this.panelName,
    this.partName,
    this.jobdescName,
    required this.coreId,
    required this.description,
    required this.fromDivision,
    required this.toDivision,
    required this.estimatedHours,
    required this.priority,
    required this.status,
    required this.notes,
    required this.requestedById,
    required this.requestedByName,
    required this.createdAt,
    this.deadline,
    this.advisorApprovedAt,
    this.advisorApprovedBy,
    this.pmApprovedAt,
    this.pmApprovedBy,
    this.rejectedReason,
    this.rejectedBy,
    this.previousDeadline,
    this.extensionReason,
    this.approvedAt,
    this.revisionRequestStatus,
    this.requestedEstimatedHours,
    this.requestedDeadline,
    this.revisionReason,
    this.revisionReviewedBy,
    this.extensionRequestStatus,
    this.extensionRequestedDeadline,
    this.extensionRequestedReason,
    this.extensionReviewedBy,
  });

  // ── Status helpers ──

  bool get isDraft => status == 'DRAFT';
  bool get isPendingAdvisor => status == 'PENDING_ADVISOR';
  bool get isPendingPm => status == 'PENDING_PM';
  bool get isPending =>
      status == 'PENDING_ADVISOR' || status == 'PENDING_PM';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isDone => status == 'DONE';
  bool get isWO => woType == 'WO';
  bool get isWOV => woType == 'WOV';

  /// Whether the deadline has been extended.
  bool get hasDeadlineExtension => previousDeadline != null;

  bool get hasPendingRevision => status == 'REVISION_REQUESTED_ADVISOR' || status == 'REVISION_REQUESTED_PM';

  bool get hasPendingExtensionRequest => extensionRequestStatus == 'PENDING';

  /// Whether this WO is fully approved (both advisor + PM).
  bool get isFullyApproved =>
      advisorApprovedAt != null && pmApprovedAt != null;

  /// Copy with new values.
  WorkOrder copyWith({
    String? id,
    String? woNumber,
    String? woType,
    String? carId,
    String? unitName,
    String? ownerName,
    String? panelName,
    String? partName,
    String? jobdescName,
    String? coreId,
    String? description,
    String? fromDivision,
    String? toDivision,
    double? estimatedHours,
    String? priority,
    String? status,
    String? notes,
    String? requestedById,
    String? requestedByName,
    String? createdAt,
    String? deadline,
    String? advisorApprovedAt,
    String? advisorApprovedBy,
    String? pmApprovedAt,
    String? pmApprovedBy,
    String? rejectedReason,
    String? rejectedBy,
    String? previousDeadline,
    String? extensionReason,
    String? approvedAt,
    String? revisionRequestStatus,
    double? requestedEstimatedHours,
    String? requestedDeadline,
    String? revisionReason,
    String? revisionReviewedBy,
    String? extensionRequestStatus,
    String? extensionRequestedDeadline,
    String? extensionRequestedReason,
    String? extensionReviewedBy,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      woNumber: woNumber ?? this.woNumber,
      woType: woType ?? this.woType,
      carId: carId ?? this.carId,
      unitName: unitName ?? this.unitName,
      ownerName: ownerName ?? this.ownerName,
      panelName: panelName ?? this.panelName,
      partName: partName ?? this.partName,
      jobdescName: jobdescName ?? this.jobdescName,
      coreId: coreId ?? this.coreId,
      description: description ?? this.description,
      fromDivision: fromDivision ?? this.fromDivision,
      toDivision: toDivision ?? this.toDivision,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      requestedById: requestedById ?? this.requestedById,
      requestedByName: requestedByName ?? this.requestedByName,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      advisorApprovedAt: advisorApprovedAt ?? this.advisorApprovedAt,
      advisorApprovedBy: advisorApprovedBy ?? this.advisorApprovedBy,
      pmApprovedAt: pmApprovedAt ?? this.pmApprovedAt,
      pmApprovedBy: pmApprovedBy ?? this.pmApprovedBy,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      previousDeadline: previousDeadline ?? this.previousDeadline,
      extensionReason: extensionReason ?? this.extensionReason,
      approvedAt: approvedAt ?? this.approvedAt,
        revisionRequestStatus:
          revisionRequestStatus ?? this.revisionRequestStatus,
        requestedEstimatedHours:
          requestedEstimatedHours ?? this.requestedEstimatedHours,
        requestedDeadline: requestedDeadline ?? this.requestedDeadline,
        revisionReason: revisionReason ?? this.revisionReason,
        revisionReviewedBy: revisionReviewedBy ?? this.revisionReviewedBy,
        extensionRequestStatus:
          extensionRequestStatus ?? this.extensionRequestStatus,
        extensionRequestedDeadline:
          extensionRequestedDeadline ?? this.extensionRequestedDeadline,
        extensionRequestedReason:
          extensionRequestedReason ?? this.extensionRequestedReason,
        extensionReviewedBy: extensionReviewedBy ?? this.extensionReviewedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        woNumber,
        woType,
        carId,
        unitName,
        ownerName,
        panelName,
        partName,
        jobdescName,
        coreId,
        description,
        fromDivision,
        toDivision,
        estimatedHours,
        priority,
        status,
        notes,
        requestedById,
        requestedByName,
        createdAt,
        deadline,
        advisorApprovedAt,
        advisorApprovedBy,
        pmApprovedAt,
        pmApprovedBy,
        rejectedReason,
        rejectedBy,
        previousDeadline,
        extensionReason,
        approvedAt,
        revisionRequestStatus,
        requestedEstimatedHours,
        requestedDeadline,
        revisionReason,
        revisionReviewedBy,
        extensionRequestStatus,
        extensionRequestedDeadline,
        extensionRequestedReason,
        extensionReviewedBy,
      ];
}
