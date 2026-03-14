library;

import '../entities/job_plan.dart';

abstract class JobPlanRepository {
  Future<List<JobPlan>> getPlans();

  Future<JobPlan> createPlan({
    String coreId = '',
    String carId = '',
    String sourceType = 'ADDITIONAL',
    String sourceRefId = '',
    required String unitName,
    required String panelName,
    required String assignedDivision,
    required String assignedUserId,
    required String assignedTo,
    required String description,
    required double targetHours,
    required String workDate,
    required String startTime,
    required String finishTime,
    required bool isOvertime,
    required String note,
  });

  Future<JobPlan> reviewPlan({required String planId, required bool approved});

  Future<JobPlan> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  });
}