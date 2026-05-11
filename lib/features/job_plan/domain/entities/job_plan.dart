library;

class JobPlan {
  const JobPlan({
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
    this.panelCustomNote,
    this.rejectNote,
    this.targetHoursAlias,
    this.remainingHoursAlias,
  });

  final String planId;
  final String coreId;
  final String carId;
  final String sourceType;
  final String sourceRefId;
  final String unitName;
  final String panelName;
  final String assignedDivision;
  final String assignedUserId;
  final String assignedTo;
  final String description;
  final double targetHours;
  final String workDate;
  final String startTime;
  final String finishTime;
  final bool isOvertime;
  final String deadline;
  final String status;
  final String note;
  final String? panelCustomNote;
  final String? rejectNote;
  final String? targetHoursAlias;
  final String? remainingHoursAlias;
}
