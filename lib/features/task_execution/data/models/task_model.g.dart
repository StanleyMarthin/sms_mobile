// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskModel _$TaskModelFromJson(Map<String, dynamic> json) => TaskModel(
      plandailyId: json['plandailyId'] as String,
      coreId: json['coreId'] as String,
      carId: json['carId'] as String,
      unitName: json['unitName'] as String,
      panelName: json['panelName'] as String,
      jobName: json['jobName'] as String,
      divisionName: json['divisionName'] as String,
      status: json['status'] as String,
      isPanelLocked: json['isPanelLocked'] as bool,
      dailyTargetHours: (json['dailyTargetHours'] as num).toDouble(),
      targetHoursRevised: (json['targetHoursRevised'] as num).toDouble(),
      remainingHours: (json['remainingHours'] as num).toDouble(),
      taskDate: json['taskDate'] as String,
      createdAt: json['createdAt'] as String,
      startedAt: json['startedAt'] as String?,
      completedAt: json['completedAt'] as String?,
      taskCategory: json['taskCategory'] as String,
      customDescription: json['customDescription'] as String,
      lockedByName: json['lockedByName'] as String?,
      ownerName: json['ownerName'] as String,
      totalActualHours: (json['totalActualHours'] as num).toDouble(),
      hasMonitoringRecord: json['hasMonitoringRecord'] as bool? ?? false,
      isRework: json['isRework'] as bool? ?? false,
      isOvertime: json['isOvertime'] as bool? ?? false,
      isPriority: json['isPriority'] as bool? ?? false,
    );

Map<String, dynamic> _$TaskModelToJson(TaskModel instance) => <String, dynamic>{
      'plandailyId': instance.plandailyId,
      'coreId': instance.coreId,
      'carId': instance.carId,
      'unitName': instance.unitName,
      'panelName': instance.panelName,
      'jobName': instance.jobName,
      'divisionName': instance.divisionName,
      'status': instance.status,
      'isPanelLocked': instance.isPanelLocked,
      'dailyTargetHours': instance.dailyTargetHours,
      'targetHoursRevised': instance.targetHoursRevised,
      'remainingHours': instance.remainingHours,
      'taskDate': instance.taskDate,
      'createdAt': instance.createdAt,
      'startedAt': instance.startedAt,
      'completedAt': instance.completedAt,
      'taskCategory': instance.taskCategory,
      'customDescription': instance.customDescription,
      'lockedByName': instance.lockedByName,
      'ownerName': instance.ownerName,
      'totalActualHours': instance.totalActualHours,
      'hasMonitoringRecord': instance.hasMonitoringRecord,
      'isRework': instance.isRework,
      'isOvertime': instance.isOvertime,
      'isPriority': instance.isPriority,
    };
