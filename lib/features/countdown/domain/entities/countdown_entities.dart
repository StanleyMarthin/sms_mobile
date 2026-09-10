/*
Tujuan: Entity domain countdown untuk unit, jobdesc, dan detail eksekusi planning/monitoring.
Caller: CountdownRepositoryImpl, grouped monitoring pages, countdown detail sheet, dialog plan.
Dependensi: Tidak ada; file ini hanya mendefinisikan struktur data domain.
Main Functions: CountdownUnit, CountdownJobdesc, CountdownDetailItem constructors.
Side Effects: Tidak ada; hanya representasi data in-memory.
*/

library;

class CountdownUnit {
  CountdownUnit({
    required this.carId,
    required this.unitName,
    required this.owner,
    required this.progress,
    required this.status,
    required this.division,
    this.deliveryDate,
    this.contractDeliveryDate,
  });

  final String carId;
  final String unitName;
  final String owner;
  final int progress;
  final String status;
  final String division;
  final String? deliveryDate;

  /// Alias for [deliveryDate] — used in grouped monitoring pages.
  final String? contractDeliveryDate;
}

/// Level 2 response: list divisi per unit.
class CountdownDivision {
  CountdownDivision({
    required this.divisionId,
    required this.divisionName,
    required this.code,
    required this.divisionProgress,
  });
  final int divisionId;
  final String divisionName;
  final String code;
  final double divisionProgress;
}

/// Level 3 response: list section/panel per divisi.
class CountdownSection {
  CountdownSection({
    required this.panelId,
    required this.sectionName,
    required this.section,
    required this.totalJobdesc,
    required this.totalRemainingHours,
    required this.totalTargetHours,
    required this.sectionProgress,
    required this.sectionStatus,
    this.totalTargetHoursAlias,
    this.totalRemainingHoursAlias,
  });
  final int panelId;
  final String sectionName;
  final String section;
  final int totalJobdesc;
  final double totalRemainingHours;
  final double totalTargetHours;
  final double sectionProgress;
  final String sectionStatus;
  final String? totalTargetHoursAlias;
  final String? totalRemainingHoursAlias;
}

class MasterPanelTracking {
  MasterPanelTracking({required this.summary, required this.components});

  final MasterPanelTrackingSummary summary;
  final List<MasterPanelTrackingComponent> components;
}

class MasterPanelTrackingSummary {
  MasterPanelTrackingSummary({
    required this.total,
    required this.pending,
    required this.progress,
    required this.order,
    required this.done,
  });

  final int total;
  final int pending;
  final int progress;
  final int order;
  final int done;
}

class MasterPanelTrackingComponent {
  MasterPanelTrackingComponent({
    required this.componentId,
    required this.componentName,
    required this.totalPanels,
    required this.totalParts,
    required this.pendingCount,
    required this.progressCount,
    required this.orderCount,
    required this.panels,
  });

  final int? componentId;
  final String componentName;
  final int totalPanels;
  final int totalParts;
  final int pendingCount;
  final int progressCount;
  final int orderCount;
  final List<MasterPanelTrackingPanel> panels;
}

class MasterPanelTrackingPanel {
  MasterPanelTrackingPanel({
    required this.panelId,
    required this.panelName,
    required this.totalParts,
    required this.activityCount,
    required this.progressPercent,
    required this.parts,
  });

  final int? panelId;
  final String panelName;
  final int totalParts;
  final int activityCount;
  final double progressPercent;
  final List<MasterPanelTrackingPart> parts;
}

class MasterPanelTrackingPart {
  MasterPanelTrackingPart({
    required this.masterPanelId,
    required this.componentName,
    required this.panelName,
    required this.namePart,
    required this.aliasName,
    required this.partNumber,
    required this.qty,
    required this.initialCondition,
    required this.currentStatus,
    required this.trackingStatus,
    required this.photoCount,
    required this.activitySummary,
  });

  final int masterPanelId;
  final String componentName;
  final String panelName;
  final String namePart;
  final String? aliasName;
  final String? partNumber;
  final double qty;
  final String initialCondition;
  final String currentStatus;
  final String trackingStatus;
  final int photoCount;
  final MasterPanelTrackingActivitySummary activitySummary;
}

class MasterPanelTrackingActivitySummary {
  MasterPanelTrackingActivitySummary({
    required this.countdownCount,
    required this.activeCountdownCount,
    required this.jobPlanCount,
    required this.prCount,
    required this.woCount,
    required this.wovCount,
  });

  final int countdownCount;
  final int activeCountdownCount;
  final int jobPlanCount;
  final int prCount;
  final int woCount;
  final int wovCount;
}

class MasterPanelImage {
  MasterPanelImage({required this.id, required this.fileUrl, this.caption});

  final int id;
  final String fileUrl;
  final String? caption;
}

class MasterPanelDetail {
  MasterPanelDetail({
    required this.id,
    required this.name,
    required this.componentName,
    required this.panelName,
    required this.partNumber,
    required this.qty,
    required this.initialCondition,
    required this.currentStatus,
    required this.notes,
    required this.images,
  });

  final int id;
  final String name;
  final String componentName;
  final String panelName;
  final String? partNumber;
  final double qty;
  final String initialCondition;
  final String currentStatus;
  final String? notes;
  final List<MasterPanelImage> images;
}

class CountdownJobdesc {
  CountdownJobdesc({
    required this.id,
    required this.carId,
    required this.divisionId,
    required this.panelName,
    required this.sectionName,
    required this.jobdesc,
    required this.taskCategory,
    required this.progress,
    required this.status,
    required this.targetHoursInitial,
    required this.timeExtensionHours,
    required this.targetHoursRevised,
    required this.totalActualHours,
    required this.remainingHours,
    required this.startDate,
    required this.deadlineDate,
    required this.qcLastStatus,
    required this.qcValidationStatus,
    required this.qcResultStatus,
    required this.qcEstimatedReworkHours,
    required this.qcReworkDeadlineDate,
    required this.qcAdvisorNotes,
    this.revisionRequestStatus,
    this.requestedRevisionHours,
    this.requestedRevisionDeadline,
    this.requestedRevisionReason,
    this.requestedRevisionByName,
    this.requestedRevisionAt,
    this.approvedRevisionHours,
    this.approvedRevisionDeadline,
    this.approvedRevisionByName,
    this.approvedRevisionAt,
    this.rejectedRevisionByName,
    this.rejectedRevisionAt,
    this.isLockedByOtherDivision = false,
    this.targetHoursRevisedAlias,
    this.remainingHoursAlias,
    this.availablePlanHours = 0.0,
    this.reservedPlanHours = 0.0,
    this.availablePlanHoursAlias,
    this.reservedPlanHoursAlias,
  });

  final String id;
  final String carId;
  final String divisionId;
  final String panelName;
  final String sectionName;
  final String jobdesc;
  final String taskCategory;
  final int progress;
  final String status;
  final double targetHoursInitial;
  final double timeExtensionHours;
  final double targetHoursRevised;
  final double totalActualHours;
  final double remainingHours;
  final String startDate;
  final String deadlineDate;
  final String? qcLastStatus;
  final String? qcValidationStatus;
  final String? qcResultStatus;
  final double? qcEstimatedReworkHours;
  final String? qcReworkDeadlineDate;
  final String? qcAdvisorNotes;
  final String? revisionRequestStatus;
  final double? requestedRevisionHours;
  final String? requestedRevisionDeadline;
  final String? requestedRevisionReason;
  final String? requestedRevisionByName;
  final DateTime? requestedRevisionAt;
  final double? approvedRevisionHours;
  final String? approvedRevisionDeadline;
  final String? approvedRevisionByName;
  final DateTime? approvedRevisionAt;
  final String? rejectedRevisionByName;
  final DateTime? rejectedRevisionAt;
  final bool isLockedByOtherDivision;
  final String? targetHoursRevisedAlias;
  final String? remainingHoursAlias;
  final double availablePlanHours;
  final double reservedPlanHours;
  final String? availablePlanHoursAlias;
  final String? reservedPlanHoursAlias;
}

class CountdownDetailItem {
  CountdownDetailItem({
    required this.id,
    required this.countdownId,
    required this.employeeName,
    required this.job,
    required this.detailJob,
    required this.workDate,
    required this.startTime,
    required this.finishTime,
    required this.targetHours,
    required this.durationHours,
    required this.remainingHours,
    required this.overtimeHours,
    required this.percentage,
    required this.status,
  });

  final String id;
  final String countdownId;
  final String employeeName;
  final String job;
  final String detailJob;
  final String workDate;
  final String startTime;
  final String finishTime;
  final double targetHours;
  final double durationHours;
  final double remainingHours;
  final double overtimeHours;
  final double percentage;
  final String status;
}
