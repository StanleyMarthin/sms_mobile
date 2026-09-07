/*
Tujuan: Mengunci pembagian jam multi-job agar tidak lagi dibagi rata buta dan tetap menghormati kapasitas tiap job.
Caller: flutter test.
Dependensi: flutter_test, material.dart, JobPlanAllocationHelper.
Main Functions: test allocateSequential.
Side Effects: Tidak ada; hanya assertion unit test.
*/
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_allocation_helper.dart';

void main() {
  group('JobPlanAllocationHelper', () {
    test('caps normal hours at 8 and keeps overtime quota', () {
      expect(
        JobPlanAllocationHelper.allowedDayHours(
          usedNormal: 3,
          usedOt: 0,
          isOvertime: false,
          isSunday: false,
        ),
        5,
      );
      expect(
        JobPlanAllocationHelper.allowedDayHours(
          usedNormal: 3,
          usedOt: 2,
          isOvertime: true,
          isSunday: false,
        ),
        8,
      );
      expect(
        JobPlanAllocationHelper.allowedDayHours(
          usedNormal: 8,
          usedOt: 0,
          isOvertime: false,
          isSunday: false,
        ),
        0,
      );
    });

    test(
      'allocates session hours sequentially based on available plan hours',
      () {
        final allocations = JobPlanAllocationHelper.allocateSequential(
          taskDate: DateTime(2026, 5, 13),
          sessionStartTime: const TimeOfDay(hour: 8, minute: 0),
          totalSessionHours: 6,
          jobs: const [
            JobPlanAllocationTarget(jobId: 'a', availablePlanHours: 3),
            JobPlanAllocationTarget(jobId: 'b', availablePlanHours: 5),
          ],
        );

        expect(allocations.length, 2);
        expect(allocations[0].jobId, 'a');
        expect(allocations[0].allocatedHours, 3);
        expect(allocations[0].startTime, const TimeOfDay(hour: 8, minute: 0));
        expect(allocations[0].finishTime, const TimeOfDay(hour: 11, minute: 0));
        expect(allocations[1].jobId, 'b');
        expect(allocations[1].allocatedHours, 3);
        expect(allocations[1].startTime, const TimeOfDay(hour: 11, minute: 0));
        expect(allocations[1].finishTime, const TimeOfDay(hour: 15, minute: 0));
      },
    );

    test('skips exhausted jobs and keeps remaining hours on later jobs', () {
      final allocations = JobPlanAllocationHelper.allocateSequential(
        taskDate: DateTime(2026, 5, 13),
        sessionStartTime: const TimeOfDay(hour: 8, minute: 0),
        totalSessionHours: 3,
        jobs: const [
          JobPlanAllocationTarget(jobId: 'a', availablePlanHours: 0),
          JobPlanAllocationTarget(jobId: 'b', availablePlanHours: 2),
          JobPlanAllocationTarget(jobId: 'c', availablePlanHours: 4),
        ],
      );

      expect(allocations.length, 2);
      expect(allocations[0].jobId, 'b');
      expect(allocations[0].allocatedHours, 2);
      expect(allocations[1].jobId, 'c');
      expect(allocations[1].allocatedHours, 1);
      expect(allocations[1].startTime, const TimeOfDay(hour: 10, minute: 0));
      expect(allocations[1].finishTime, const TimeOfDay(hour: 11, minute: 0));
    });

    test('keeps equality valid and exhausted capacity unavailable', () {
      final exact = JobPlanAllocationHelper.allocateSequential(
        taskDate: DateTime(2026, 5, 13),
        sessionStartTime: const TimeOfDay(hour: 8, minute: 0),
        totalSessionHours: 1,
        jobs: const [
          JobPlanAllocationTarget(jobId: 'a', availablePlanHours: 1),
        ],
      );
      final exhausted = JobPlanAllocationHelper.allocateSequential(
        taskDate: DateTime(2026, 5, 13),
        sessionStartTime: const TimeOfDay(hour: 8, minute: 0),
        totalSessionHours: 0.5,
        jobs: const [
          JobPlanAllocationTarget(jobId: 'a', availablePlanHours: 0),
        ],
      );
      final partial = JobPlanAllocationHelper.allocateSequential(
        taskDate: DateTime(2026, 5, 13),
        sessionStartTime: const TimeOfDay(hour: 8, minute: 0),
        totalSessionHours: 3,
        jobs: const [
          JobPlanAllocationTarget(jobId: 'a', availablePlanHours: 3),
        ],
      );

      expect(exact.single.allocatedHours, 1);
      expect(exhausted, isEmpty);
      expect(partial.single.allocatedHours, 3);
    });
  });
}
