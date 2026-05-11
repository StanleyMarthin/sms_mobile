/*
Tujuan: Entity domain monitoring task yang menyatukan target harian, target total, sisa jam, checkpoint, dan status validasi.
Caller: TaskViewBloc, TaskViewPage, dan ViewTaskCard.
Dependensi: Equatable.
Main Functions: isDone, isInProgress, progressPercent, hoursUsed, hasRemainingCheckpointSessions.
Side Effects: Tidak ada; hanya komputasi state monitoring in-memory.
*/
library;

import 'package:equatable/equatable.dart';

/// Division info nested in the task response.
class TaskDivision extends Equatable {
  final String divisionId;
  final String divisionName;

  const TaskDivision({required this.divisionId, required this.divisionName});

  @override
  List<Object?> get props => [divisionId, divisionName];
}

/// Unit (car) info nested in the task response.
class TaskUnit extends Equatable {
  final String unitId;
  final String unitName;

  const TaskUnit({required this.unitId, required this.unitName});

  @override
  List<Object?> get props => [unitId, unitName];
}

/// Employee info nested in the task response.
class TaskEmployee extends Equatable {
  final String employeeId;
  final String employeeName;

  const TaskEmployee({required this.employeeId, required this.employeeName});

  @override
  List<Object?> get props => [employeeId, employeeName];
}

/// Task detail info nested in the task response.
class TaskDetail extends Equatable {
  final String namaPanel;
  final String jobName;
  final String jobDescription;
  final String startTime;
  final String targetFinishTime;
  final bool isRework;
  final int breakDuration;
  final double targetHours;
  final double targetHoursRevised;
  final double remainingHours;
  final double totalActualHours;
  final String note;

  const TaskDetail({
    required this.namaPanel,
    required this.jobName,
    required this.jobDescription,
    required this.startTime,
    required this.targetFinishTime,
    this.isRework = false,
    required this.breakDuration,
    this.targetHours = 0,
    this.targetHoursRevised = 0,
    this.remainingHours = 0,
    this.totalActualHours = 0,
    this.note = '',
  });

  @override
  List<Object?> get props => [
    namaPanel,
    jobName,
    jobDescription,
    startTime,
    targetFinishTime,
    isRework,
    breakDuration,
    targetHours,
    targetHoursRevised,
    remainingHours,
    totalActualHours,
    note,
  ];
}

class TaskCheckpointSession extends Equatable {
  final int sessionNumber;
  final String startWorkTime;
  final String finishWorkTime;
  final int progress;
  final String checkpointTime;
  final String jobStatus;
  final String actorRole;
  final String actorName;
  final List<TaskCheckpointReviewer> reviewers;

  const TaskCheckpointSession({
    required this.sessionNumber,
    required this.startWorkTime,
    required this.finishWorkTime,
    required this.progress,
    required this.checkpointTime,
    required this.jobStatus,
    required this.actorRole,
    required this.actorName,
    this.reviewers = const [],
  });

  String get actorRoleLabel => actorRole.toUpperCase();

  bool get isValidated => reviewers.isNotEmpty;

  String get reviewersLabel =>
      reviewers.map((item) => item.roleLabel).join(' dan ');

  String get reviewerNamesLabel =>
      reviewers.map((item) => item.name).join(', ');

  bool hasReviewerRole(String role) =>
      reviewers.any((item) => item.role.toLowerCase() == role.toLowerCase());

  String get workedDurationLabel {
    final startMinutes = _parseClockToMinutes(startWorkTime);
    final finishMinutes = _parseClockToMinutes(finishWorkTime);
    if (startMinutes == null ||
        finishMinutes == null ||
        finishMinutes < startMinutes) {
      return '-';
    }

    final totalMinutes = finishMinutes - startMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}j ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}j';
    }
    return '${minutes}m';
  }

  String get jobStatusLabel {
    switch (jobStatus) {
      case 'DONE':
        return 'Selesai';
      case 'CANCEL':
        return 'Cancel';
      default:
        return 'On Progress';
    }
  }

  static int? _parseClockToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  @override
  List<Object?> get props => [
    sessionNumber,
    startWorkTime,
    finishWorkTime,
    progress,
    checkpointTime,
    jobStatus,
    actorRole,
    actorName,
    reviewers,
  ];
}

class TaskCheckpointReviewer extends Equatable {
  final String role;
  final String name;

  const TaskCheckpointReviewer({required this.role, required this.name});

  String get roleLabel => role.toUpperCase();

  @override
  List<Object?> get props => [role, name];
}

class TaskFinalValidation extends Equatable {
  final String role;
  final String name;
  final String note;
  final String time;
  final bool approved;

  const TaskFinalValidation({
    required this.role,
    required this.name,
    required this.note,
    required this.time,
    this.approved = true,
  });

  String get roleLabel => role.toUpperCase();

  @override
  List<Object?> get props => [role, name, note, time, approved];
}

/// Entity representing a single task in the unified view.
/// Returned by GET /api/v1/tasks.
/// Used by all roles (OP, KD, ADV, PM) — the same structure
/// regardless of role; only the data scope differs.
class ViewTaskEntity extends Equatable {
  /// Unique identifier for the plan_daily record.
  final String planDailyId;

  /// Division this task belongs to.
  final TaskDivision division;

  /// Unit (car) this task is being performed on.
  final TaskUnit unit;

  /// Employee assigned to this task.
  final TaskEmployee employee;

  /// Task details (panel, job, times).
  final TaskDetail task;

  /// Current status of the task (e.g. ASSIGNED, PROSES, DONE).
  final String status;

  final List<TaskCheckpointSession> checkpointHistory;

  final List<TaskFinalValidation> finalValidations;

  final int maxCheckpointSessions;

  final List<String> photosBefore;
  final List<String> photosProcess;
  final List<String> photosAfter;

  const ViewTaskEntity({
    required this.planDailyId,
    required this.division,
    required this.unit,
    required this.employee,
    required this.task,
    required this.status,
    this.checkpointHistory = const [],
    this.finalValidations = const [],
    this.maxCheckpointSessions = 3,
    this.photosBefore = const [],
    this.photosProcess = const [],
    this.photosAfter = const [],
  });

  /// Whether the task is completed.
  bool get isDone => status == 'DONE';

  /// Whether OP has submitted work and it is waiting for checkpoint/follow-up.
  bool get isSubmitted => status == 'SUBMITTED';

  bool get isValidated => status == 'VALIDATED';

  bool get hasFinalValidation => finalValidations.isNotEmpty || isValidated;

  bool hasFinalValidationByRole(String role) => finalValidations.any(
    (item) => item.role.toLowerCase() == role.toLowerCase(),
  );

  /// Whether the task is in progress.
  bool get isInProgress =>
      status == 'PROSES' || status == 'CHECK_PROGRESS' || status == 'SUBMITTED';

  /// Whether the task is assigned but not started.
  bool get isAssigned => status == 'ASSIGNED';

  bool get isCheckpointFlowFinished =>
      checkpointHistory.isNotEmpty &&
      checkpointHistory.last.jobStatus == 'DONE';

  bool get hasRemainingCheckpointSessions =>
      !isCheckpointFlowFinished &&
      checkpointHistory.length < maxCheckpointSessions;

  int get nextCheckpointSession => checkpointHistory.length + 1;

  double get dailyTargetHours => task.targetHours;

  double get targetHoursTotal =>
      task.targetHoursRevised > 0 ? task.targetHoursRevised : task.targetHours;

  double get remainingHours {
    if (task.remainingHours > 0) return task.remainingHours;
    if (isDone || hasFinalValidation) return 0.0;
    final computed = targetHoursTotal - hoursUsed;
    return computed.clamp(0.0, targetHoursTotal);
  }

  double get hoursUsed {
    if (targetHoursTotal > 0 && task.remainingHours > 0) {
      return (targetHoursTotal - task.remainingHours).clamp(
        0.0,
        targetHoursTotal,
      );
    }
    if (task.totalActualHours > 0) {
      final cap = targetHoursTotal > 0
          ? targetHoursTotal
          : task.totalActualHours;
      return task.totalActualHours.clamp(0.0, cap);
    }
    if (checkpointHistory.isNotEmpty) {
      final progress = checkpointHistory.last.progress.clamp(0, 100) / 100.0;
      return targetHoursTotal > 0 ? (targetHoursTotal * progress) : 0.0;
    }
    return isDone ? targetHoursTotal : 0.0;
  }

  int get progressPercent {
    if (isDone || hasFinalValidation) return 100;
    if (targetHoursTotal > 0) {
      return ((hoursUsed / targetHoursTotal) * 100).round().clamp(0, 100);
    }
    if (checkpointHistory.isNotEmpty) {
      return checkpointHistory.last.progress.clamp(0, 100);
    }
    return 0;
  }

  @override
  List<Object?> get props => [
    planDailyId,
    division,
    unit,
    employee,
    task,
    status,
    checkpointHistory,
    finalValidations,
    maxCheckpointSessions,
    photosBefore,
    photosProcess,
    photosAfter,
  ];
}

/// Response wrapper for paginated task list.
class ViewTaskResponse extends Equatable {
  final String type;
  final String date;
  final String? divisionId;
  final String? unitId;
  final List<ViewTaskEntity> tasks;

  const ViewTaskResponse({
    required this.type,
    required this.date,
    this.divisionId,
    this.unitId,
    required this.tasks,
  });

  @override
  List<Object?> get props => [type, date, divisionId, unitId, tasks];
}
