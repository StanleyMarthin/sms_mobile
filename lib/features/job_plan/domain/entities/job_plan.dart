/*
Tujuan: Entity domain Job Plan untuk legacy plan dan read model Job Plan V2.
Caller: JobPlanRepository, JobPlanPage, JobPlanDetailPage, dan unit test.
Dependensi: Tidak ada.
Main Functions: JobPlan, CommandMetadata, id, scheduleTimeLabel.
Side Effects: Tidak ada; hanya struktur data dan getter.
*/
library;

class JobPlan {
  JobPlan({
    required this.planId,
    required this.coreId,
    required this.carId,
    required this.sourceType,
    required this.sourceRefId,
    required this.unitName,
    required this.panelName,
    required this.assignedDivision,
    required this.assignedUserId,
    required this.assignedTo,
    required this.description,
    required this.targetHours,
    required this.workDate,
    required this.startTime,
    required this.finishTime,
    required this.isOvertime,
    required this.deadline,
    required this.status,
    required this.note,
    this.sourceId,
    this.panelId,
    this.unitId,
    this.countdownName,
    this.employeeId,
    this.employeeName,
    this.taskDate,
    this.startMinute,
    this.durationMinutes,
    this.approvalState,
    this.executionState,
    this.ledgerState,
    this.version = 0,
    this.createdAt,
    this.updatedAt,
    this.waitingFor,
    this.currentApproverType,
    this.accumulatedMinutes = 0,
    this.verifiedMinutes = 0,
    this.unverifiedMinutes = 0,
    this.countdownTargetMinutes = 0,
    this.panelCustomNote,
    this.rejectNote,
    this.targetHoursAlias,
    this.remainingHoursAlias,
    this.progress = 0,
    this.totalActualHours = 0.0,
  });

  final String planId;
  final String coreId;
  final String carId;
  final String sourceType;
  final String sourceRefId;
  final String? sourceId;
  final String unitName;
  final String panelName;
  final String? panelId;
  final String? unitId;
  final String? countdownName;
  final String assignedDivision;
  final String assignedUserId;
  final String assignedTo;
  final String? employeeId;
  final String? employeeName;
  final String description;
  final double targetHours;
  final String workDate;
  final String? taskDate;
  final String startTime;
  final String finishTime;
  final int? startMinute;
  final int? durationMinutes;
  final bool isOvertime;
  final String deadline;
  final String status;
  final String note;
  final String? approvalState;
  final String? executionState;
  final String? ledgerState;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? waitingFor;
  final String? currentApproverType;
  final int accumulatedMinutes;
  final int verifiedMinutes;
  final int unverifiedMinutes;
  final int countdownTargetMinutes;
  final String? panelCustomNote;
  final String? rejectNote;
  final String? targetHoursAlias;
  final String? remainingHoursAlias;
  final int progress;
  final double totalActualHours;

  String get id => planId;

  String get resolvedSourceId {
    final explicit = sourceId?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final ref = sourceRefId.trim();
    if (ref.isNotEmpty) return ref;
    return coreId;
  }

  String get resolvedCountdownName {
    final value = countdownName?.trim() ?? '';
    return value.isNotEmpty ? value : description;
  }

  String get resolvedEmployeeId {
    final value = employeeId?.trim() ?? '';
    return value.isNotEmpty ? value : assignedUserId;
  }

  String get resolvedEmployeeName {
    final value = employeeName?.trim() ?? '';
    return value.isNotEmpty ? value : assignedTo;
  }

  String get resolvedTaskDate {
    final value = taskDate?.trim() ?? '';
    return value.isNotEmpty ? value : workDate;
  }

  String get scheduleTimeLabel => '$startTime - $finishTime';
}

class CommandMetadata {
  const CommandMetadata({
    required this.commandId,
    required this.expectedVersion,
  });

  final String commandId;
  final int expectedVersion;
}
