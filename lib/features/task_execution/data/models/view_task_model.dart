// View Task Model — JSON-serializable data model for GET /api/v1/tasks.
//
// Maps the nested JSON response structure to Dart objects and provides
// conversion to domain entities.
library;

import '../../domain/entities/view_task_entity.dart';

class TaskCheckpointReviewerModel {
  final String role;
  final String name;

  const TaskCheckpointReviewerModel({
    required this.role,
    required this.name,
  });

  factory TaskCheckpointReviewerModel.fromJson(Map<String, dynamic> json) {
    return TaskCheckpointReviewerModel(
      role: json['role'] as String? ?? 'adv',
      name: json['name'] as String? ?? 'SYSTEM',
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'name': name,
      };

  TaskCheckpointReviewer toEntity() => TaskCheckpointReviewer(role: role, name: name);
}

class TaskCheckpointSessionModel {
  final int sessionNumber;
  final String startWorkTime;
  final String finishWorkTime;
  final int progress;
  final String checkpointTime;
  final String jobStatus;
  final String actorRole;
  final String actorName;
  final List<TaskCheckpointReviewerModel> reviewers;

  const TaskCheckpointSessionModel({
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

  factory TaskCheckpointSessionModel.fromJson(Map<String, dynamic> json) {
    final reviewerItems = (json['reviewers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TaskCheckpointReviewerModel.fromJson)
        .toList();
    final legacyRole = json['reviewerRole'] as String?;
    final legacyName = json['reviewerName'] as String?;
    final legacyValidated = json['isValidated'] == true;

    return TaskCheckpointSessionModel(
      sessionNumber: (json['sessionNumber'] as num?)?.toInt() ?? 1,
      startWorkTime: json['startWorkTime'] as String? ?? '--:--',
      finishWorkTime:
          json['finishWorkTime'] as String? ?? json['checkpointTime'] as String? ?? '--:--',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      checkpointTime: json['checkpointTime'] as String? ?? '--:--',
      jobStatus: json['jobStatus'] as String? ?? 'ON_PROGRESS',
      actorRole: json['actorRole'] as String? ?? 'kd',
      actorName: json['actorName'] as String? ?? 'SYSTEM',
      reviewers: reviewerItems.isNotEmpty
          ? reviewerItems
          : (legacyValidated && legacyRole != null && legacyName != null)
              ? [TaskCheckpointReviewerModel(role: legacyRole, name: legacyName)]
              : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionNumber': sessionNumber,
        'startWorkTime': startWorkTime,
        'finishWorkTime': finishWorkTime,
        'progress': progress,
        'checkpointTime': checkpointTime,
        'jobStatus': jobStatus,
        'actorRole': actorRole,
        'actorName': actorName,
        'isValidated': reviewers.isNotEmpty,
        'reviewers': reviewers.map((item) => item.toJson()).toList(),
      };

  TaskCheckpointSession toEntity() => TaskCheckpointSession(
        sessionNumber: sessionNumber,
        startWorkTime: startWorkTime,
        finishWorkTime: finishWorkTime,
        progress: progress,
        checkpointTime: checkpointTime,
        jobStatus: jobStatus,
        actorRole: actorRole,
        actorName: actorName,
        reviewers: reviewers.map((item) => item.toEntity()).toList(),
      );
}

class TaskFinalValidationModel {
  final String role;
  final String name;
  final String note;
  final String time;
  final bool approved;

  const TaskFinalValidationModel({
    required this.role,
    required this.name,
    required this.note,
    required this.time,
    this.approved = true,
  });

  factory TaskFinalValidationModel.fromJson(Map<String, dynamic> json) {
    return TaskFinalValidationModel(
      role: json['role'] as String? ?? 'adv',
      name: json['name'] as String? ?? 'SYSTEM',
      note: json['note'] as String? ?? '',
      time: json['time'] as String? ?? '',
      approved: json['approved'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'name': name,
        'note': note,
        'time': time,
        'approved': approved,
      };

  TaskFinalValidation toEntity() => TaskFinalValidation(
        role: role,
        name: name,
        note: note,
        time: time,
        approved: approved,
      );
}

/// Model for the division nested object in the task response.
class TaskDivisionModel {
  final String divisionId;
  final String divisionName;

  const TaskDivisionModel({
    required this.divisionId,
    required this.divisionName,
  });

  factory TaskDivisionModel.fromJson(Map<String, dynamic> json) {
    return TaskDivisionModel(
      divisionId: json['divisionId'] as String,
      divisionName: json['divisionName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'divisionId': divisionId,
        'divisionName': divisionName,
      };

  TaskDivision toEntity() => TaskDivision(
        divisionId: divisionId,
        divisionName: divisionName,
      );
}

/// Model for the unit nested object in the task response.
class TaskUnitModel {
  final String unitId;
  final String unitName;

  const TaskUnitModel({
    required this.unitId,
    required this.unitName,
  });

  factory TaskUnitModel.fromJson(Map<String, dynamic> json) {
    return TaskUnitModel(
      unitId: json['unitId'] as String,
      unitName: json['unitName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'unitId': unitId,
        'unitName': unitName,
      };

  TaskUnit toEntity() => TaskUnit(
        unitId: unitId,
        unitName: unitName,
      );
}

/// Model for the employee nested object in the task response.
class TaskEmployeeModel {
  final String employeeId;
  final String employeeName;

  const TaskEmployeeModel({
    required this.employeeId,
    required this.employeeName,
  });

  factory TaskEmployeeModel.fromJson(Map<String, dynamic> json) {
    return TaskEmployeeModel(
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
      };

  TaskEmployee toEntity() => TaskEmployee(
        employeeId: employeeId,
        employeeName: employeeName,
      );
}

/// Model for the task detail nested object in the task response.
class TaskDetailModel {
  final String namaPanel;
  final String jobName;
  final String jobDescription;
  final String startTime;
  final String targetFinishTime;
  final bool isRework;
  final int breakDuration;

  const TaskDetailModel({
    required this.namaPanel,
    required this.jobName,
    required this.jobDescription,
    required this.startTime,
    required this.targetFinishTime,
    this.isRework = false,
    required this.breakDuration,
  });

  factory TaskDetailModel.fromJson(Map<String, dynamic> json) {
    return TaskDetailModel(
      namaPanel: json['namaPanel'] as String,
      jobName: json['jobName'] as String,
      jobDescription: json['jobDescription'] as String,
      startTime: json['startTime'] as String,
      targetFinishTime: json['targetFinishTime'] as String,
      isRework: (json['is_rework'] as num?)?.toInt() == 1 ||
          json['isRework'] == true,
      breakDuration: (json['breakDuration'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'namaPanel': namaPanel,
        'jobName': jobName,
        'jobDescription': jobDescription,
        'startTime': startTime,
        'targetFinishTime': targetFinishTime,
        'is_rework': isRework ? 1 : 0,
        'breakDuration': breakDuration,
      };

  TaskDetail toEntity() => TaskDetail(
        namaPanel: namaPanel,
        jobName: jobName,
        jobDescription: jobDescription,
        startTime: startTime,
        targetFinishTime: targetFinishTime,
        isRework: isRework,
        breakDuration: breakDuration,
      );
}

/// Top-level model for a single task in the GET /api/v1/tasks response.
class ViewTaskModel {
  final String planDailyId;
  final TaskDivisionModel division;
  final TaskUnitModel unit;
  final TaskEmployeeModel employee;
  final TaskDetailModel task;
  final String status;
  final List<TaskCheckpointSessionModel> checkpointHistory;
  final List<TaskFinalValidationModel> finalValidations;
  final int maxCheckpointSessions;

  const ViewTaskModel({
    required this.planDailyId,
    required this.division,
    required this.unit,
    required this.employee,
    required this.task,
    required this.status,
    required this.checkpointHistory,
    required this.finalValidations,
    required this.maxCheckpointSessions,
  });

  factory ViewTaskModel.fromJson(Map<String, dynamic> json) {
    final taskJson = json['task'] as Map<String, dynamic>;
    final checkpointItems = (json['checkpointHistory'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TaskCheckpointSessionModel.fromJson)
        .toList();
    final finalValidationItems = (json['finalValidations'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(TaskFinalValidationModel.fromJson)
      .toList();
    final legacyValidation = json['validation'] as Map<String, dynamic>?;
    final legacyApproved = legacyValidation?['approved'] == true;
    final legacyRole = legacyValidation?['role'] as String?;
    final legacyName = legacyValidation?['name'] as String?;
    final legacyNote = legacyValidation?['note'] as String? ?? '';
    final legacyTime = legacyValidation?['time'] as String? ?? '';

    return ViewTaskModel(
      planDailyId: json['planDailyId'] as String,
      division: TaskDivisionModel.fromJson(
          json['division'] as Map<String, dynamic>),
      unit: TaskUnitModel.fromJson(json['unit'] as Map<String, dynamic>),
      employee: TaskEmployeeModel.fromJson(
          json['employee'] as Map<String, dynamic>),
      task: TaskDetailModel.fromJson(taskJson),
      status: json['status'] as String,
      checkpointHistory: checkpointItems,
      finalValidations: finalValidationItems.isNotEmpty
          ? finalValidationItems
          : (legacyApproved && legacyRole != null && legacyName != null)
              ? [
                  TaskFinalValidationModel(
                    role: legacyRole,
                    name: legacyName,
                    note: legacyNote,
                    time: legacyTime,
                    approved: true,
                  ),
                ]
              : const [],
      maxCheckpointSessions: (json['maxCheckpointSessions'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'planDailyId': planDailyId,
        'division': division.toJson(),
        'unit': unit.toJson(),
        'employee': employee.toJson(),
        'task': task.toJson(),
        'status': status,
        'checkpointHistory': checkpointHistory.map((item) => item.toJson()).toList(),
        'finalValidations': finalValidations.map((item) => item.toJson()).toList(),
        'validation': finalValidations.isNotEmpty
            ? finalValidations.last.toJson()
            : null,
        'maxCheckpointSessions': maxCheckpointSessions,
      };

  ViewTaskEntity toEntity() => ViewTaskEntity(
        planDailyId: planDailyId,
        division: division.toEntity(),
        unit: unit.toEntity(),
        employee: employee.toEntity(),
        task: task.toEntity(),
        status: status,
        checkpointHistory: checkpointHistory.map((item) => item.toEntity()).toList(),
        finalValidations: finalValidations.map((item) => item.toEntity()).toList(),
        maxCheckpointSessions: maxCheckpointSessions,
      );
}
