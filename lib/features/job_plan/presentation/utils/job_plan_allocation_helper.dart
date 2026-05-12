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
  const JobPlanAllocationResult({
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
  const JobPlanAllocationHelper._();

  static List<JobPlanAllocationResult> allocateSequential({
    required DateTime taskDate,
    required TimeOfDay sessionStartTime,
    required double totalSessionHours,
    required List<JobPlanAllocationTarget> jobs,
  }) {
    final allocations = <JobPlanAllocationResult>[];
    var remainingSessionHours = totalSessionHours;
    var currentStartTime = sessionStartTime;

    for (final job in jobs) {
      if (remainingSessionHours <= 0) break;

      final availablePlanHours = job.availablePlanHours
          .clamp(0.0, 9999.0)
          .toDouble();
      if (availablePlanHours <= 0) continue;

      final allocatedHours = remainingSessionHours <= availablePlanHours
          ? remainingSessionHours
          : availablePlanHours;
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

      remainingSessionHours = (remainingSessionHours - allocatedHours)
          .clamp(0.0, 9999.0)
          .toDouble();
      currentStartTime = finishTime;
    }

    return allocations;
  }
}
