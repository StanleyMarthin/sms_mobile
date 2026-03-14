library;

abstract class JobPlanDataSource {
  Future<List<Map<String, dynamic>>> getPlans();

  Future<Map<String, dynamic>> createPlan({
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

  Future<Map<String, dynamic>> reviewPlan({required String planId, required bool approved});

  Future<Map<String, dynamic>> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  });
}