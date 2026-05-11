/// TaskModel is the data layer representation of TaskEntity.
///
/// This model handles JSON serialization/deserialization and serves as
/// the direct interface with the API. It mirrors TaskEntity fields and
/// provides a toEntity() method for converting to the domain layer.
///
/// The model receives data from the backend API that combines:
/// - trx_jobdesc_plandaily: Daily assignment information
/// - trx_jobdesc_core: Core job details
/// - trx_car_panel_status: Current panel lock status
/// - cars: Unit information
/// - master_panels: Panel master data
/// - master_job_types: Job type details
/// - sm_divisi: Division information
library;

import '../../domain/entities/task_entity.dart';

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
      plandailyId: json['plandailyId']?.toString() ?? '',
      coreId: json['coreId']?.toString() ?? '',
      carId: json['carId']?.toString() ?? '',
      unitName: json['unitName']?.toString() ?? '',
      panelName: json['panelName']?.toString() ?? '',
      jobName: json['jobName']?.toString() ?? '',
      divisionName: json['divisionName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      isPanelLocked: json['isPanelLocked'] == true || json['isPanelLocked'] == 1,
      dailyTargetHours: (json['dailyTargetHours'] as num?)?.toDouble() ?? 0.0,
      targetHoursRevised: (json['targetHoursRevised'] as num?)?.toDouble() ?? 0.0,
      remainingHours: (json['remainingHours'] as num?)?.toDouble() ?? 0.0,
      taskDate: json['taskDate']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '-',
      targetFinishTime: json['targetFinishTime']?.toString() ?? '-',
      createdAt: json['createdAt']?.toString() ?? '',
      startedAt: json['startedAt']?.toString(),
      completedAt: json['completedAt']?.toString(),
      taskCategory: json['taskCategory']?.toString() ?? '',
      jobDescription: json['jobDescription']?.toString() ?? json['job_description']?.toString() ?? json['customDescription']?.toString() ?? '',
      instruction: json['instruction']?.toString() ?? json['note']?.toString() ?? '',
      lockedByName: json['lockedByName']?.toString(),
      ownerName: json['ownerName']?.toString() ?? '',
      totalActualHours: (json['totalActualHours'] as num?)?.toDouble() ?? 0.0,
      hasMonitoringRecord: json['hasMonitoringRecord'] == true || json['hasMonitoringRecord'] == 1,
      isRework: json['isRework'] == true || json['isRework'] == 1,
      isOvertime: json['isOvertime'] == true || json['isOvertime'] == 1,
      isPriority: json['isPriority'] == true || json['isPriority'] == 1,
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
