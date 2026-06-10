/*
Tujuan: Helper pemecahan log task execution untuk kebutuhan split normal vs overtime.
Caller: Modul job plan saat split jam kerja normal vs overtime pada draft plan.
Dependensi: TimeParser, CountdownHelper.
Main Functions: splitJobPlanItem.
Side Effects: Tidak ada; hanya transformasi data in-memory.
*/
import '../../../countdown/presentation/utils/countdown_helper.dart';

class TaskExecutionHelper {
  /// Splits a Job Plan draft item into Normal and Overtime if needed.
  static List<Map<String, dynamic>> splitJobPlanItem(
    Map<String, dynamic> item,
  ) {
    final targetHours = item['targetHours'] as double? ?? 0.0;
    if (targetHours <= 0) return [item];
    final totalProjectHours =
        (item['totalProjectHours'] as num?)?.toDouble() ?? targetHours;
    final hasSeparatedProjectTarget =
        totalProjectHours > 0.0 && totalProjectHours > targetHours;

    final taskDate = DateTime.parse(item['taskDate'] as String);
    final startTimeStr = item['startTime'] as String;
    final finishTimeStr = item['finishTime'] as String;

    final startParts = startTimeStr.split(':');
    final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

    final finishParts = finishTimeStr.split(':');
    final finishMins =
        int.parse(finishParts[0]) * 60 + int.parse(finishParts[1]);

    final threshold = CountdownHelper.normalThresholdForDate(taskDate);
    final thresholdMins = threshold.hour * 60 + threshold.minute;

    final maxNormalMins = 8 * 60;

    // We don't know the exact break here, but let's assume if it's > 8h target,
    // it's already including or excluding break based on how UX works.
    // In JobPlanPage, targetHours is the work duration.

    bool needsSplit = false;
    int splitMins = finishMins;

    // Time-based split
    if (!hasSeparatedProjectTarget && finishMins > thresholdMins) {
      if (startMins < thresholdMins) {
        needsSplit = true;
        splitMins = thresholdMins;
      } else {
        // Already OT
        return [Map<String, dynamic>.from(item)..['isOvertime'] = true];
      }
    }

    // Duration-based split (target hours > 8)
    if (!hasSeparatedProjectTarget && targetHours > 8.0) {
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
      ..['finishTime'] =
          '${(splitMins ~/ 60).toString().padLeft(2, '0')}:${(splitMins % 60).toString().padLeft(2, '0')}'
      ..['isOvertime'] = false;

    final otItem = Map<String, dynamic>.from(item)
      ..['draftItemId'] = '${item['draftItemId']}_ot'
      ..['targetHours'] = otHours
      ..['startTime'] = normalItem['finishTime']
      ..['isOvertime'] = true;

    return [normalItem, otItem];
  }
}
