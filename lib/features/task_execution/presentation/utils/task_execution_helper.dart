import 'package:flutter/material.dart';
import '../../domain/entities/task_execution_log.dart';
import '../../../../core/utils/time_parser.dart';
import '../../../countdown/presentation/utils/countdown_helper.dart';

class TaskExecutionHelper {
  /// Splits a [TaskExecutionLog] into two logs (Normal and Overtime) if it exceeds
  /// 8 hours of work OR goes past the daily normal threshold (17:00/14:00).
  ///
  /// Returns a list of 1 or 2 logs.
  static List<TaskExecutionLog> splitOvertime(TaskExecutionLog log) {
    final startDt = DateTime.parse(log.startTime);
    final finishDt = DateTime.parse(log.finishTime);
    
    // Normal threshold for the day
    final thresholdTime = CountdownHelper.normalThresholdForDate(startDt);
    final thresholdDt = DateTime(
      startDt.year,
      startDt.month,
      startDt.day,
      thresholdTime.hour,
      thresholdTime.minute,
    );

    // Max normal work duration (8 hours)
    final maxNormalWorkMins = 8 * 60;
    
    // Total duration including break
    final totalMins = finishDt.difference(startDt).inMinutes;
    final workMins = totalMins - log.breakDurationMinutes;

    // Check if we need to split
    bool needsSplit = false;
    DateTime splitDt = finishDt;
    int normalBreak = log.breakDurationMinutes;
    int otBreak = 0;

    // 1. Check time-based threshold
    if (finishDt.isAfter(thresholdDt)) {
      needsSplit = true;
      if (thresholdDt.isAfter(startDt)) {
        splitDt = thresholdDt;
      } else {
        // Start is already after threshold (all OT)
        return [log]; 
      }
    }

    // 2. Check duration-based threshold (8 hours)
    final durationSplitDt = startDt.add(Duration(minutes: maxNormalWorkMins + log.breakDurationMinutes));
    if (workMins > maxNormalWorkMins && durationSplitDt.isBefore(splitDt)) {
      needsSplit = true;
      splitDt = durationSplitDt;
    }

    if (!needsSplit || splitDt.isAtSameMomentAs(finishDt)) {
      return [log];
    }

    // Adjust breaks: assuming break happens in the normal part if possible.
    // This is a simplification.
    
    final logNormal = log.copyWith(
      finishTime: TimeParser.formatIsoWithOffset(splitDt),
      // For progress, we just give it the full progress if it's the first log?
      // Or split it proportionally? User didn't specify, but usually they report 
      // progress for the whole session. Let's keep it as is or set normal part as 'pending'
      // if total is 100%. Actually, backend might expect 'done' only on the last part.
      status: 'pending', 
    );

    final logOT = log.copyWith(
      startTime: TimeParser.formatIsoWithOffset(splitDt),
      breakDurationMinutes: 0, // Break already accounted for in normal
    );

    return [logNormal, logOT];
  }

  /// Splits a Job Plan draft item into Normal and Overtime if needed.
  static List<Map<String, dynamic>> splitJobPlanItem(Map<String, dynamic> item) {
    final targetHours = item['targetHours'] as double? ?? 0.0;
    if (targetHours <= 0) return [item];

    final taskDate = DateTime.parse(item['taskDate'] as String);
    final startTimeStr = item['startTime'] as String;
    final finishTimeStr = item['finishTime'] as String;

    final startParts = startTimeStr.split(':');
    final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    
    final finishParts = finishTimeStr.split(':');
    final finishMins = int.parse(finishParts[0]) * 60 + int.parse(finishParts[1]);

    final threshold = CountdownHelper.normalThresholdForDate(taskDate);
    final thresholdMins = threshold.hour * 60 + threshold.minute;

    final maxNormalMins = 8 * 60;
    
    // We don't know the exact break here, but let's assume if it's > 8h target, 
    // it's already including or excluding break based on how UX works.
    // In JobPlanPage, targetHours is the work duration.
    
    bool needsSplit = false;
    int splitMins = finishMins;

    // Time-based split
    if (finishMins > thresholdMins) {
      if (startMins < thresholdMins) {
        needsSplit = true;
        splitMins = thresholdMins;
      } else {
        // Already OT
        return [Map<String, dynamic>.from(item)..['isOvertime'] = true];
      }
    }

    // Duration-based split (target hours > 8)
    if (targetHours > 8.0) {
      final durationSplitMins = startMins + maxNormalMins;
      if (!needsSplit || durationSplitMins < splitMins) {
        needsSplit = true;
        splitMins = durationSplitMins;
      }
    }

    if (!needsSplit || splitMins >= finishMins) {
      return [item];
    }

    final normalHours = (splitMins - startMins) / 60.0;
    final otHours = targetHours - normalHours;

    final normalItem = Map<String, dynamic>.from(item)
      ..['targetHours'] = normalHours
      ..['finishTime'] = '${(splitMins ~/ 60).toString().padLeft(2, '0')}:${(splitMins % 60).toString().padLeft(2, '0')}'
      ..['isOvertime'] = false;

    final otItem = Map<String, dynamic>.from(item)
      ..['draftItemId'] = '${item['draftItemId']}_ot'
      ..['targetHours'] = otHours
      ..['startTime'] = normalItem['finishTime']
      ..['isOvertime'] = true;

    return [normalItem, otItem];
  }
}
