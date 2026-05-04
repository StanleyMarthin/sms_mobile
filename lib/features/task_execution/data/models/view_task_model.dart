// View Task Model — JSON-serializable data model for GET /api/v1/tasks.
//
// Maps the nested JSON response structure to Dart objects and provides
// conversion to domain entities.
library;

import '../../domain/entities/view_task_entity.dart';

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
    final lower = value.trim().toLowerCase();
    if (lower == 'true') return 1;
    if (lower == 'false') return 0;
  }
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
}

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

  TaskCheckpointReviewer toEntity() =>
      TaskCheckpointReviewer(role: role, name: name);
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
      sessionNumber: _asInt(json['sessionNumber'], fallback: 1),
      startWorkTime: json['startWorkTime'] as String? ?? '--:--',
      finishWorkTime: json['finishWorkTime'] as String? ??
          json['checkpointTime'] as String? ??
          '--:--',
      progress: _asInt(json['progress']),
      checkpointTime: json['checkpointTime'] as String? ?? '--:--',
      jobStatus: json['jobStatus'] as String? ?? 'ON_PROGRESS',
      actorRole: json['actorRole'] as String? ?? 'kd',
      actorName: json['actorName'] as String? ?? 'SYSTEM',
      reviewers: reviewerItems.isNotEmpty
          ? reviewerItems
          : (legacyValidated && legacyRole != null && legacyName != null)
              ? [
                  TaskCheckpointReviewerModel(
                      role: legacyRole, name: legacyName)
                ]
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
      divisionId: _asString(json['divisionId']),
      divisionName: _asString(json['divisionName'], fallback: '-'),
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
      unitId: _asString(json['unitId']),
      unitName: _asString(json['unitName'], fallback: '-'),
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
      employeeId: _asString(json['employeeId']),
      employeeName: _asString(json['employeeName'], fallback: '-'),
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
      namaPanel: _asString(json['namaPanel'], fallback: '-'),
      jobName: _asString(json['jobName'], fallback: '-'),
      jobDescription: _asString(json['jobDescription']),
      startTime: _asString(json['startTime'], fallback: '-'),
      targetFinishTime: _asString(json['targetFinishTime'], fallback: '-'),
      isRework: _asBool(json['is_rework']) || _asBool(json['isRework']),
      breakDuration: _asInt(json['breakDuration']),
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
  final List<String> photosBefore;
  final List<String> photosProcess;
  final List<String> photosAfter;

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
    this.photosBefore = const [],
    this.photosProcess = const [],
    this.photosAfter = const [],
  });

  factory ViewTaskModel.fromJson(Map<String, dynamic> json) {
    final taskJson = json['task'] as Map<String, dynamic>;
    final checkpointItems = (json['checkpointHistory'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TaskCheckpointSessionModel.fromJson)
        .toList();
    final finalValidationItems =
        (json['finalValidations'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TaskFinalValidationModel.fromJson)
            .toList();
    final legacyValidation = json['validation'] as Map<String, dynamic>?;
    final legacyApproved = legacyValidation?['approved'] == true;
    final legacyRole = legacyValidation?['role'] as String?;
    final legacyName = legacyValidation?['name'] as String?;
    final legacyNote = legacyValidation?['note'] as String? ?? '';
    final legacyTime = legacyValidation?['time'] as String? ?? '';

    final photosJson = json['photos'] as Map<String, dynamic>? ?? {};
    final pBefore = (photosJson['before'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final pProcess = (photosJson['process'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final pAfter = (photosJson['after'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return ViewTaskModel(
      planDailyId: _asString(json['planDailyId']),
      division:
          TaskDivisionModel.fromJson(json['division'] as Map<String, dynamic>),
      unit: TaskUnitModel.fromJson(json['unit'] as Map<String, dynamic>),
      employee:
          TaskEmployeeModel.fromJson(json['employee'] as Map<String, dynamic>),
      task: TaskDetailModel.fromJson(taskJson),
      status: _asString(json['status'], fallback: 'PLAN'),
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
      maxCheckpointSessions:
          _asInt(json['maxCheckpointSessions'], fallback: 3),
      photosBefore: pBefore,
      photosProcess: pProcess,
      photosAfter: pAfter,
    );
  }

  Map<String, dynamic> toJson() => {
        'planDailyId': planDailyId,
        'division': division.toJson(),
        'unit': unit.toJson(),
        'employee': employee.toJson(),
        'task': task.toJson(),
        'status': status,
        'checkpointHistory':
            checkpointHistory.map((item) => item.toJson()).toList(),
        'finalValidations':
            finalValidations.map((item) => item.toJson()).toList(),
        'validation':
            finalValidations.isNotEmpty ? finalValidations.last.toJson() : null,
        'maxCheckpointSessions': maxCheckpointSessions,
      };

  ViewTaskEntity toEntity() => ViewTaskEntity(
        planDailyId: planDailyId,
        division: division.toEntity(),
        unit: unit.toEntity(),
        employee: employee.toEntity(),
        task: task.toEntity(),
        status: status,
        checkpointHistory:
            checkpointHistory.map((item) => item.toEntity()).toList(),
        finalValidations:
            finalValidations.map((item) => item.toEntity()).toList(),
        maxCheckpointSessions: maxCheckpointSessions,
      );
}
