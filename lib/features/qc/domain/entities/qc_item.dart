library;

class QcChecklistItem {
  const QcChecklistItem({
    required this.item,
    required this.passed,
  });

  final String item;
  final bool? passed;
}

class QcItem {
  const QcItem({
    required this.qcId,
    required this.coreId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    required this.mechanicName,
    required this.mechanicDivision,
    required this.totalActualHours,
    required this.targetHoursRevised,
    required this.qcChecklist,
    required this.validationStatus,
    this.resultStatus,
    this.qcNotes,
    this.kdRemainingHours,
    this.estimatedReworkHours,
    this.reworkDeadlineDate,
    this.finalRemainingHours,
    this.advNotes,
    this.pmNotes,
    this.kdCheckpointBy,
    this.advValidatedBy,
    this.pmValidatedBy,
    this.kdCheckpointAt,
    this.advValidatedAt,
    this.pmValidatedAt,
  });

  final String qcId;
  final String coreId;
  final String unitName;
  final String panelName;
  final String jobName;
  final String mechanicName;
  final String mechanicDivision;
  final double totalActualHours;
  final double targetHoursRevised;
  final List<QcChecklistItem> qcChecklist;
  final String validationStatus;
  final String? resultStatus;
  final String? qcNotes;
  final double? kdRemainingHours;
  final double? estimatedReworkHours;
  final String? reworkDeadlineDate;
  final double? finalRemainingHours;
  final String? advNotes;
  final String? pmNotes;
  final String? kdCheckpointBy;
  final String? advValidatedBy;
  final String? pmValidatedBy;
  final String? kdCheckpointAt;
  final String? advValidatedAt;
  final String? pmValidatedAt;
}