library;

class CountdownUnit {
  const CountdownUnit({
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
  const CountdownDivision({
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
  const CountdownSection({
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

class CountdownJobdesc {
  const CountdownJobdesc({
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
}

class CountdownDetailItem {
  const CountdownDetailItem({
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