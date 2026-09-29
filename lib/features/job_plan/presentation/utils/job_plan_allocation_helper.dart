/*
Tujuan: Utilitas pembagian jam multi-job secara berurutan berdasarkan kapasitas planning tiap job.
Caller: JobPlanPage saat membuat draft/plan multi-job countdown atau additional.
Dependensi: material.dart, CountdownHelper.
Main Functions: allocateSequential.
Side Effects: Tidak ada; hanya transformasi data in-memory.
*/
import 'package:flutter/material.dart';

import '../../../countdown/presentation/utils/countdown_helper.dart';

class JobPlanAllocationTarget {
  const JobPlanAllocationTarget({
    required this.jobId,
    required this.availablePlanHours,
  });

  final String jobId;
  final double availablePlanHours;
}

class JobPlanAllocationResult {
  JobPlanAllocationResult({
    required this.jobId,
    required this.allocatedHours,
    required this.startTime,
    required this.finishTime,
    required this.isOvertime,
  });

  final String jobId;
  final double allocatedHours;
  final TimeOfDay startTime;
  final TimeOfDay finishTime;
  final bool isOvertime;
}

class JobPlanAllocationHelper {
  JobPlanAllocationHelper._();

  static int hoursToMinutes(double hours) {
    return (hours.clamp(0.0, 9999.0).toDouble() * 60).round();
  }

  static double minutesToHours(int minutes) {
    return minutes.clamp(0, 9999 * 60) / 60.0;
  }

  static bool exceedsAvailableByMinute({
    required double targetHours,
    required double availableHours,
  }) {
    return hoursToMinutes(targetHours) > hoursToMinutes(availableHours);
  }

  /// Sisa jam kerja harian yang boleh dipakai operator.
  /// Normal: maksimal 8 jam. Lembur: 8 jam normal + kuota lembur (5/7 jam).
  static double allowedDayHours({
    required double usedNormal,
    required double usedOt,
    required bool isOvertime,
    required bool isSunday,
  }) {
    final normalLeft = (8 - usedNormal).clamp(0.0, 9999.0).toDouble();
    if (!isOvertime) return normalLeft;
    final maxOt = isSunday ? 7 : 5;
    final otLeft = (maxOt - usedOt).clamp(0.0, 9999.0).toDouble();
    return normalLeft + otLeft;
  }

  static List<JobPlanAllocationResult> allocateSequential({
    required DateTime taskDate,
    required TimeOfDay sessionStartTime,
    required double totalSessionHours,
    required List<JobPlanAllocationTarget> jobs,
  }) {
    final allocations = <JobPlanAllocationResult>[];
    var remainingSessionMinutes = hoursToMinutes(totalSessionHours);
    var currentStartTime = sessionStartTime;

    for (final job in jobs) {
      if (remainingSessionMinutes <= 0) break;

      final availablePlanMinutes = hoursToMinutes(job.availablePlanHours);
      if (availablePlanMinutes <= 0) continue;

      final allocatedMinutes = remainingSessionMinutes <= availablePlanMinutes
          ? remainingSessionMinutes
          : availablePlanMinutes;
      final allocatedHours = minutesToHours(allocatedMinutes);
      final finishTime = CountdownHelper.calculateFinishTime(
        startTime: currentStartTime,
        durationHours: allocatedHours,
        date: taskDate,
      );

      allocations.add(
        JobPlanAllocationResult(
          jobId: job.jobId,
          allocatedHours: allocatedHours,
          startTime: currentStartTime,
          finishTime: finishTime,
          isOvertime: CountdownHelper.isOvertimeByTime(
            finishTime,
            date: taskDate,
          ),
        ),
      );

      remainingSessionMinutes -= allocatedMinutes;
      currentStartTime = finishTime;
    }

    return allocations;
  }
}
