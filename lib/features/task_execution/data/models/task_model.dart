/*
Tujuan: Model data task execution untuk menormalkan payload backend/operator menjadi entity domain yang stabil.
Caller: ApiTaskDataSource, LocalTaskDataSource, dan repository task execution.
Dependensi: TaskEntity, TimeParser.
Main Functions: fromJson, fromTaskApiJson, toEntity, copyWith.
Side Effects: Tidak ada; hanya parsing dan normalisasi data in-memory.
*/
library;

import '../../../../core/utils/time_parser.dart';
import '../../domain/entities/task_entity.dart';

String _taskString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

bool _taskBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

double _taskHours(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();

  final text = value.toString().trim();
  if (text.isEmpty) return fallback;

  final parsedClock = TimeParser.parseHHmmToDecimal(text);
  if (parsedClock != null) return parsedClock;
  return double.tryParse(text) ?? fallback;
}

double? _taskPercent(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}

String? _taskNullableString(Iterable<dynamic> candidates) {
  for (final candidate in candidates) {
    final value = _taskString(candidate);
    if (value.isNotEmpty) return value;
  }
  return null;
}

double _normalizeTaskPlanHours(double value) {
  if (value <= 24) return value;
  if (value <= 24 * 60) return value / 60;
  return value / 3600;
}

double? _taskPlanHours(Iterable<dynamic> candidates) {
  for (final candidate in candidates) {
    final parsed = _taskHours(candidate, fallback: -1);
    if (parsed >= 0) return _normalizeTaskPlanHours(parsed);
  }
  return null;
}

int? _taskClockToMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour * 60) + minute;
}

String _taskAddHours(String startTime, double hours) {
  final startMinutes = _taskClockToMinutes(startTime);
  if (startMinutes == null || hours <= 0) return '-';

  final totalMinutes = startMinutes + (hours * 60).round();
  final hour = '${(totalMinutes ~/ 60) % 24}'.padLeft(2, '0');
  final minute = '${totalMinutes % 60}'.padLeft(2, '0');
  return '$hour:$minute';
}

String _taskSubtractHours(String finishTime, double hours) {
  final finishMinutes = _taskClockToMinutes(finishTime);
  if (finishMinutes == null || hours <= 0) return '-';

  final totalMinutes = finishMinutes - (hours * 60).round();
  final normalizedMinutes =
      ((totalMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
  final hour = '${normalizedMinutes ~/ 60}'.padLeft(2, '0');
  final minute = '${normalizedMinutes % 60}'.padLeft(2, '0');
  return '$hour:$minute';
}

String _normalizeTaskStatusValue(
  String rawStatus, {
  required double remainingHours,
  double? actualProgressPercent,
}) {
  final normalized = rawStatus.trim().toUpperCase();
  final noRemainingWork = remainingHours <= 0.0001;
  final isFullProgress = (actualProgressPercent ?? -1) >= 100;

  if (noRemainingWork || isFullProgress) {
    return 'DONE';
  }

  switch (normalized) {
    case 'DONE':
    case 'QC_READY':
    case 'READY_QC':
      return 'DONE';
    case 'CANCEL':
    case 'CANCELLED':
      return 'CANCEL';
    case 'SUBMITTED':
      return 'PROSES';
    case 'PENDING':
      return 'PENDING';
    case 'PLAN':
    case 'ASSIGNED':
      return 'ASSIGNED';
    case 'PROSES':
    case 'IN_PROGRESS':
    case 'ON_PROGRESS':
    case 'ONPROGRESS':
    case 'CHECK_PROGRESS':
      return 'PROSES';
    default:
      return 'PLAN';
  }
}

/// TaskModel provides JSON serialization capabilities on top of TaskEntity.
class TaskModel {
  final String plandailyId;
  final String coreId;
  final String carId;
  final String unitName;
  final String panelName;
  final String jobName;
  final String divisionName;
  final String status;
  final bool isPanelLocked;
  final double dailyTargetHours;
  final double targetHoursRevised;
  final double remainingHours;
  final String taskDate;
  final String startTime;
  final String targetFinishTime;
  final String createdAt;
  final String? startedAt;
  final String? completedAt;
  final String taskCategory;
  final String jobDescription;
  final String? instruction;
  final String? lockedByName;
  final String ownerName;
  final double totalActualHours;
  final bool hasMonitoringRecord;
  final bool isRework;
  final bool isOvertime;
  final bool isPriority;

  TaskModel({
    required this.plandailyId,
    required this.coreId,
    required this.carId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    required this.divisionName,
    required this.status,
    required this.isPanelLocked,
    required this.dailyTargetHours,
    required this.targetHoursRevised,
    required this.remainingHours,
    required this.taskDate,
    this.startTime = '-',
    this.targetFinishTime = '-',
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.taskCategory,
    required this.jobDescription,
    this.instruction,
    this.lockedByName,
    required this.ownerName,
    required this.totalActualHours,
    this.hasMonitoringRecord = false,
    this.isRework = false,
    this.isOvertime = false,
    this.isPriority = false,
  });

  /// Factory constructor for deserializing JSON from API responses.
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      plandailyId: _taskString(json['plandailyId']),
      coreId: _taskString(json['coreId']),
      carId: _taskString(json['carId']),
      unitName: _taskString(json['unitName']),
      panelName: _taskString(json['panelName']),
      jobName: _taskString(json['jobName']),
      divisionName: _taskString(json['divisionName']),
      status: _taskString(json['status']),
      isPanelLocked: _taskBool(json['isPanelLocked']),
      dailyTargetHours: _taskHours(json['dailyTargetHours']),
      targetHoursRevised: _taskHours(json['targetHoursRevised']),
      remainingHours: _taskHours(json['remainingHours']),
      taskDate: _taskString(json['taskDate']),
      startTime: _taskString(json['startTime'], fallback: '-'),
      targetFinishTime: _taskString(json['targetFinishTime'], fallback: '-'),
      createdAt: _taskString(json['createdAt']),
      startedAt: _taskNullableString([json['startedAt']]),
      completedAt: _taskNullableString([json['completedAt']]),
      taskCategory: _taskString(json['taskCategory']),
      jobDescription: _taskString(
        json['jobDescription'] ??
            json['job_description'] ??
            json['customDescription'],
      ),
      instruction: _taskString(json['instruction'] ?? json['note']),
      lockedByName: _taskNullableString([json['lockedByName']]),
      ownerName: _taskString(json['ownerName']),
      totalActualHours: _taskHours(json['totalActualHours']),
      hasMonitoringRecord: _taskBool(json['hasMonitoringRecord']),
      isRework: _taskBool(json['isRework']),
      isOvertime: _taskBool(json['isOvertime']),
      isPriority: _taskBool(json['isPriority']),
    );
  }

  /// Factory khusus untuk payload GET /tasks yang masih campur nested task,
  /// alias snake_case, dan field progres aktual.
  factory TaskModel.fromTaskApiJson(Map<String, dynamic> json) {
    final division = json['division'] as Map<String, dynamic>? ?? const {};
    final unit = json['unit'] as Map<String, dynamic>? ?? const {};
    final task = json['task'] as Map<String, dynamic>? ?? const {};
    final planDaily = json['planDaily'] as Map<String, dynamic>? ?? const {};
    final countdownCumulative =
        json['countdownCumulative'] as Map<String, dynamic>? ?? const {};
    final executionLatest =
        json['executionLatest'] as Map<String, dynamic>? ?? const {};

    final dailyTargetHours =
        _taskPlanHours([
          planDaily['dailyTargetHours'],
          planDaily['daily_target_hours'],
          planDaily['targetHours'],
          planDaily['target_hours'],
          json['dailyTargetHours'],
          json['daily_target_hours'],
          json['targetHours'],
          json['target_hours'],
          task['dailyTargetHours'],
          task['daily_target_hours'],
          task['targetHours'],
          task['target_hours'],
        ]) ??
        0.0;
    final targetHoursRevised = _taskHours(
      countdownCumulative['targetHoursTotal'] ??
          countdownCumulative['target_hours_total'] ??
          countdownCumulative['targetHoursRevised'] ??
          countdownCumulative['target_hours_revised'] ??
          task['target_hours_revised'] ??
          task['targetHoursRevised'] ??
          json['targetHoursRevised'] ??
          json['target_hours_revised'] ??
          task['target_hours_initial'] ??
          task['targetHoursInitial'] ??
          json['targetHoursInitial'] ??
          dailyTargetHours,
    );
    final actualProgressPercent = _taskPercent(
      countdownCumulative['progressPercent'] ??
          countdownCumulative['progress_percent'] ??
          countdownCumulative['actualProgressPercent'] ??
          countdownCumulative['actual_progress_percent'] ??
          json['actualProgress'] ??
          json['actualProgressPercent'] ??
          json['actual_progress'] ??
          json['actual_progress_percent'] ??
          task['actualProgressPercent'] ??
          task['actual_progress_percent'] ??
          json['progressPercent'] ??
          json['progress'],
    );
    final actualDurationHours = _taskHours(
      executionLatest['durationHours'] ??
          executionLatest['duration_hours'] ??
          json['actualDurationHours'] ??
          json['actual_duration_hours'] ??
          json['durationHours'] ??
          json['workedHours'],
    );
    final totalActualHours = _taskHours(
      countdownCumulative['totalActualHours'] ??
          countdownCumulative['total_actual_hours'] ??
          task['total_actual_hours'] ??
          task['totalActualHours'] ??
          json['totalActualHours'] ??
          json['total_actual_hours'],
      fallback: -1,
    );

    final rawRemainingHours = _taskHours(
      countdownCumulative['remainingHours'] ??
          countdownCumulative['remaining_hours'] ??
          task['remaining_hours'] ??
          task['remainingHours'] ??
          json['remainingHours'] ??
          json['remaining_hours'],
      fallback: -1,
    );
    final remainingHours = rawRemainingHours >= 0
        ? rawRemainingHours
        : actualProgressPercent != null && targetHoursRevised > 0
        ? (targetHoursRevised * (1 - (actualProgressPercent / 100))).clamp(
            0.0,
            targetHoursRevised,
          )
        : (targetHoursRevised - actualDurationHours).clamp(
            0.0,
            targetHoursRevised,
          );

    final startedAt = _taskNullableString([
      executionLatest['startedAt'],
      executionLatest['started_at'],
      executionLatest['actualStartTime'],
      executionLatest['actual_start_time'],
      json['startedAt'],
      json['started_at'],
      json['actualStartTime'],
      json['actual_start_time'],
      json['startWorkTime'],
      json['start_work_time'],
    ]);
    final completedAt = _taskNullableString([
      executionLatest['completedAt'],
      executionLatest['completed_at'],
      executionLatest['actualFinishTime'],
      executionLatest['actual_finish_time'],
      json['completedAt'],
      json['completed_at'],
      json['actualFinishTime'],
      json['actual_finish_time'],
      json['finishWorkTime'],
      json['finish_work_time'],
      json['finishTime'],
    ]);

    final explicitMonitoringRecord = _taskBool(
      json['hasMonitoringRecord'] ??
          json['has_monitoring_record'] ??
          json['monitoringLocked'] ??
          json['monitoring_locked'] ??
          json['isSubmitted'],
    );
    final hasMonitoringRecord = explicitMonitoringRecord || completedAt != null;

    final lockedByName = _taskNullableString([
      json['lockedByName'],
      json['locked_by_name'],
      (json['lockedBy'] as Map<String, dynamic>?)?['fullName'],
    ]);

    var planStartTime = TimeParser.pickClock([
      planDaily['startTime'],
      planDaily['start_time'],
      planDaily['planStartTime'],
      planDaily['plan_starttime'],
      planDaily['plan_start_time'],
      planDaily['targetStartHours'],
      planDaily['target_start_hours'],
      task['startTime'],
      task['start_time'],
      task['planStartTime'],
      task['plan_starttime'],
      task['plan_start_time'],
      task['targetStartHours'],
      task['target_start_hours'],
      json['planStartTime'],
      json['plan_starttime'],
      json['plan_start_time'],
      json['startTime'],
      json['start_time'],
      json['targetStartHours'],
      json['target_start_hours'],
    ]);
    var planFinishTime = TimeParser.pickClock([
      planDaily['targetFinishTime'],
      planDaily['target_finish_time'],
      planDaily['planFinishTime'],
      planDaily['plan_finishtime'],
      planDaily['plan_finish_time'],
      planDaily['finishTime'],
      planDaily['finish_time'],
      planDaily['targetFinishHours'],
      planDaily['target_finish_hours'],
      task['targetFinishTime'],
      task['target_finish_time'],
      task['planFinishTime'],
      task['plan_finishtime'],
      task['plan_finish_time'],
      task['finishTime'],
      task['finish_time'],
      task['targetFinishHours'],
      task['target_finish_hours'],
      json['planFinishTime'],
      json['plan_finishtime'],
      json['plan_finish_time'],
      json['finishTime'],
      json['finish_time'],
      json['targetFinishHours'],
      json['target_finish_hours'],
    ]);
    final planHours = dailyTargetHours > 0
        ? dailyTargetHours
        : (targetHoursRevised > 0 ? targetHoursRevised : 0.0);
    if ((planStartTime == '-' || planStartTime.isEmpty) &&
        planFinishTime != '-' &&
        planHours > 0) {
      planStartTime = _taskSubtractHours(planFinishTime, planHours);
    }
    if ((planFinishTime == '-' || planFinishTime.isEmpty) &&
        planStartTime != '-' &&
        planHours > 0) {
      planFinishTime = _taskAddHours(planStartTime, planHours);
    }

    return TaskModel(
      plandailyId: _taskString(json['planDailyId'] ?? json['plandailyId']),
      coreId: _taskString(json['coreId'] ?? json['core_id']),
      carId: _taskString(unit['unitId'] ?? json['carId'] ?? json['car_id']),
      unitName: _taskString(
        unit['unitName'] ?? json['unitName'] ?? json['unit_name'],
        fallback: '-',
      ),
      panelName: _taskString(
        task['namaPanel'] ?? json['panelName'],
        fallback: '-',
      ),
      jobName: _taskString(task['jobName'] ?? json['jobName'], fallback: '-'),
      divisionName: _taskString(
        division['divisionName'] ??
            json['divisionName'] ??
            json['division_name'],
        fallback: '-',
      ),
      status: _normalizeTaskStatusValue(
        _taskString(json['status'], fallback: 'PLAN'),
        remainingHours: remainingHours,
        actualProgressPercent: actualProgressPercent,
      ),
      isPanelLocked:
          _taskBool(
            json['isPanelLocked'] ??
                json['is_panel_locked'] ??
                json['locked'] ??
                json['panelLocked'],
          ) ||
          lockedByName != null,
      dailyTargetHours: dailyTargetHours,
      targetHoursRevised: targetHoursRevised,
      remainingHours: remainingHours,
      taskDate: _taskString(
        json['taskDate'] ?? json['task_date'],
        fallback: DateTime.now().toIso8601String().substring(0, 10),
      ),
      startTime: planStartTime,
      targetFinishTime: planFinishTime,
      createdAt: _taskString(
        json['createdAt'] ?? json['created_at'],
        fallback: DateTime.now().toUtc().toIso8601String(),
      ),
      startedAt: startedAt,
      completedAt: completedAt,
      taskCategory: _taskString(
        json['taskCategory'] ?? task['taskCategory'] ?? task['task_category'],
      ),
      jobDescription: _taskString(
        task['jobDescription'] ??
            task['job_description'] ??
            json['jobDescription'] ??
            json['job_description'],
      ),
      instruction: _taskString(
        task['note'] ??
            task['catatan'] ??
            task['pok'] ??
            json['instruction'] ??
            json['note'],
      ),
      lockedByName: lockedByName,
      ownerName: _taskString(
        json['ownerName'] ??
            json['owner_name'] ??
            unit['owner'] ??
            json['owner'],
      ),
      totalActualHours: totalActualHours >= 0
          ? totalActualHours
          : targetHoursRevised > 0
          ? (targetHoursRevised - remainingHours).clamp(0.0, targetHoursRevised)
          : (actualProgressPercent != null && dailyTargetHours > 0
                ? (actualProgressPercent / 100.0) * dailyTargetHours
                : actualDurationHours),
      hasMonitoringRecord: hasMonitoringRecord,
      isRework: _taskBool(
        task['is_rework'] ?? task['isRework'] ?? json['isRework'],
      ),
      isOvertime: _taskBool(
        task['is_overtime'] ?? task['isOvertime'] ?? json['isOvertime'],
      ),
      isPriority: _taskBool(
        task['is_priority'] ?? task['isPriority'] ?? json['isPriority'],
      ),
    );
  }

  /// Serializes this model to JSON format suitable for API requests.
  Map<String, dynamic> toJson() => {
    'plandailyId': plandailyId,
    'coreId': coreId,
    'carId': carId,
    'unitName': unitName,
    'panelName': panelName,
    'jobName': jobName,
    'divisionName': divisionName,
    'status': status,
    'isPanelLocked': isPanelLocked,
    'dailyTargetHours': dailyTargetHours,
    'targetHoursRevised': targetHoursRevised,
    'remainingHours': remainingHours,
    'taskDate': taskDate,
    'startTime': startTime,
    'targetFinishTime': targetFinishTime,
    'createdAt': createdAt,
    'startedAt': startedAt,
    'completedAt': completedAt,
    'taskCategory': taskCategory,
    'jobDescription': jobDescription,
    'instruction': instruction,
    'lockedByName': lockedByName,
    'ownerName': ownerName,
    'totalActualHours': totalActualHours,
    'hasMonitoringRecord': hasMonitoringRecord,
    'isRework': isRework,
    'isOvertime': isOvertime,
    'isPriority': isPriority,
  };

  /// Converts this data model to a domain entity.
  ///
  /// This method is typically called within the repository layer after
  /// receiving data from the API. It creates a TaskEntity instance
  /// that is passed to the business logic layer.
  ///
  /// This ensures separation of concerns: the model handles serialization,
  /// while the entity represents pure business logic.
  TaskEntity toEntity() => TaskEntity(
    plandailyId: plandailyId,
    coreId: coreId,
    carId: carId,
    unitName: unitName,
    panelName: panelName,
    jobName: jobName,
    divisionName: divisionName,
    status: status,
    isPanelLocked: isPanelLocked,
    dailyTargetHours: dailyTargetHours,
    targetHoursRevised: targetHoursRevised,
    remainingHours: remainingHours,
    taskDate: taskDate,
    startTime: startTime,
    targetFinishTime: targetFinishTime,
    createdAt: createdAt,
    startedAt: startedAt,
    completedAt: completedAt,
    taskCategory: taskCategory,
    jobDescription: jobDescription,
    instruction: instruction,
    lockedByName: lockedByName,
    ownerName: ownerName,
    totalActualHours: totalActualHours,
    hasMonitoringRecord: hasMonitoringRecord,
    isRework: isRework,
    isOvertime: isOvertime,
    isPriority: isPriority,
  );

  /// Creates a copy of this model with some fields replaced.
  ///
  /// Useful for immutable updates and testing.
  TaskModel copyWith({
    String? plandailyId,
    String? coreId,
    String? carId,
    String? unitName,
    String? panelName,
    String? jobName,
    String? divisionName,
    String? status,
    bool? isPanelLocked,
    double? dailyTargetHours,
    double? targetHoursRevised,
    double? remainingHours,
    String? taskDate,
    String? startTime,
    String? targetFinishTime,
    String? createdAt,
    String? startedAt,
    String? completedAt,
    String? taskCategory,
    String? jobDescription,
    String? instruction,
    String? lockedByName,
    String? ownerName,
    double? totalActualHours,
    bool? hasMonitoringRecord,
    bool? isRework,
    bool? isOvertime,
    bool? isPriority,
  }) {
    return TaskModel(
      plandailyId: plandailyId ?? this.plandailyId,
      coreId: coreId ?? this.coreId,
      carId: carId ?? this.carId,
      unitName: unitName ?? this.unitName,
      panelName: panelName ?? this.panelName,
      jobName: jobName ?? this.jobName,
      divisionName: divisionName ?? this.divisionName,
      status: status ?? this.status,
      isPanelLocked: isPanelLocked ?? this.isPanelLocked,
      dailyTargetHours: dailyTargetHours ?? this.dailyTargetHours,
      targetHoursRevised: targetHoursRevised ?? this.targetHoursRevised,
      remainingHours: remainingHours ?? this.remainingHours,
      taskDate: taskDate ?? this.taskDate,
      startTime: startTime ?? this.startTime,
      targetFinishTime: targetFinishTime ?? this.targetFinishTime,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      taskCategory: taskCategory ?? this.taskCategory,
      jobDescription: jobDescription ?? this.jobDescription,
      instruction: instruction ?? this.instruction,
      lockedByName: lockedByName ?? this.lockedByName,
      ownerName: ownerName ?? this.ownerName,
      totalActualHours: totalActualHours ?? this.totalActualHours,
      hasMonitoringRecord: hasMonitoringRecord ?? this.hasMonitoringRecord,
      isRework: isRework ?? this.isRework,
      isOvertime: isOvertime ?? this.isOvertime,
      isPriority: isPriority ?? this.isPriority,
    );
  }
}
