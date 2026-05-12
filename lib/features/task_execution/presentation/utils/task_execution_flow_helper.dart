/*
Tujuan: Utilitas flow task execution untuk kalkulasi progress kumulatif, anchor tanggal submit, dan breakdown normal vs overtime.
Caller: TaskExecutionSheet, unit test task execution, dan flow submit operator.
Dependensi: material.dart, CountdownHelper.
Main Functions: buildTaskDateTime, computeSessionHours, computeRealtimeProgressPercent, resolveSubmitStatus, splitWorkedHours.
Side Effects: Tidak ada; seluruh fungsi bersifat pure/in-memory.
*/
import 'package:flutter/material.dart';

import '../../../countdown/presentation/utils/countdown_helper.dart';

class TaskExecutionWorkedHoursBreakdown {
  const TaskExecutionWorkedHoursBreakdown({
    required this.normalHours,
    required this.overtimeHours,
    required this.totalWorkedHours,
  });

  final double normalHours;
  final double overtimeHours;
  final double totalWorkedHours;
}

class TaskExecutionFlowHelper {
  const TaskExecutionFlowHelper._();

  static DateTime buildTaskDateTime({
    required String taskDate,
    required TimeOfDay time,
  }) {
    final parsedTaskDate = DateTime.tryParse(taskDate);
    final anchor = parsedTaskDate ?? DateTime.now();
    return DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
      time.hour,
      time.minute,
    );
  }

  static double computeSessionHours({
    required TimeOfDay startTime,
    required TimeOfDay finishTime,
    required int breakDurationMinutes,
  }) {
    final startMinutes = (startTime.hour * 60) + startTime.minute;
    var finishMinutes = (finishTime.hour * 60) + finishTime.minute;
    if (finishMinutes <= startMinutes) {
      finishMinutes += 24 * 60;
    }

    final workedMinutes = (finishMinutes - startMinutes - breakDurationMinutes)
        .clamp(0, 24 * 60);
    return workedMinutes / 60.0;
  }

  static double computeRealtimeProgressPercent({
    required double recordedWorkedHours,
    required double currentSessionHours,
    required double totalTargetHours,
  }) {
    if (totalTargetHours <= 0) return 0.0;
    final totalWorkedHours = (recordedWorkedHours + currentSessionHours).clamp(
      0.0,
      totalTargetHours,
    );
    return (((totalWorkedHours / totalTargetHours) * 100).clamp(
      0.0,
      100.0,
    )).toDouble();
  }

  static String resolveSubmitStatus({
    required String selectedStatus,
    required double progressPercent,
  }) {
    if (selectedStatus.trim().toLowerCase() == 'done' ||
        progressPercent >= 100) {
      return 'done';
    }
    return 'pending';
  }

  static TaskExecutionWorkedHoursBreakdown splitWorkedHours({
    required String taskDate,
    required TimeOfDay startTime,
    required TimeOfDay finishTime,
    required int breakDurationMinutes,
  }) {
    final startDt = buildTaskDateTime(taskDate: taskDate, time: startTime);
    var finishDt = buildTaskDateTime(taskDate: taskDate, time: finishTime);
    if (!finishDt.isAfter(startDt)) {
      finishDt = finishDt.add(const Duration(days: 1));
    }

    final totalWorkedHours = computeSessionHours(
      startTime: startTime,
      finishTime: finishTime,
      breakDurationMinutes: breakDurationMinutes,
    );
    if (totalWorkedHours <= 0) {
      return const TaskExecutionWorkedHoursBreakdown(
        normalHours: 0,
        overtimeHours: 0,
        totalWorkedHours: 0,
      );
    }

    final thresholdTime = CountdownHelper.normalThresholdForDate(startDt);
    final thresholdDt = DateTime(
      startDt.year,
      startDt.month,
      startDt.day,
      thresholdTime.hour,
      thresholdTime.minute,
    );

    if (!finishDt.isAfter(thresholdDt) && totalWorkedHours <= 8) {
      return TaskExecutionWorkedHoursBreakdown(
        normalHours: totalWorkedHours,
        overtimeHours: 0,
        totalWorkedHours: totalWorkedHours,
      );
    }

    if (!thresholdDt.isAfter(startDt)) {
      return TaskExecutionWorkedHoursBreakdown(
        normalHours: 0,
        overtimeHours: totalWorkedHours,
        totalWorkedHours: totalWorkedHours,
      );
    }

    var splitDt = finishDt;
    if (finishDt.isAfter(thresholdDt)) {
      splitDt = thresholdDt;
    }

    final durationSplitDt = startDt.add(
      Duration(minutes: (8 * 60) + breakDurationMinutes),
    );
    if (durationSplitDt.isBefore(splitDt)) {
      splitDt = durationSplitDt;
    }

    final normalMinutes =
        (splitDt.difference(startDt).inMinutes - breakDurationMinutes).clamp(
          0,
          (totalWorkedHours * 60).round(),
        );
    final overtimeMinutes = ((totalWorkedHours * 60).round() - normalMinutes)
        .clamp(0, 24 * 60);

    return TaskExecutionWorkedHoursBreakdown(
      normalHours: normalMinutes / 60.0,
      overtimeHours: overtimeMinutes / 60.0,
      totalWorkedHours: totalWorkedHours,
    );
  }
}
