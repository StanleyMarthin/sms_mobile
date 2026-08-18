/*
Tujuan: Kontrak datasource job plan untuk akses API/mock draft, browse, dan approval.
Caller: JobPlanRepositoryImpl.
Dependensi: Implementasi remote/local datasource.
Main Functions: saveDraft, getDraft, submitDraft, browsePlans, createPlan.
Side Effects: Delegasi ke HTTP call atau mock storage.
*/
library;

abstract class JobPlanDataSource {
  Future<List<Map<String, dynamic>>> getPlans();
  Future<List<Map<String, dynamic>>> getApprovalQueue({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  });
  Future<Map<String, dynamic>> getApprovalRaw({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  });
  Future<List<Map<String, dynamic>>> browsePlans({
    String? divisionId,
    String? unitId,
    String? role,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  });
  Future<Map<String, dynamic>> getAdditionalDropdowns({String? divisionId});
  Future<List<Map<String, dynamic>>> getDropdownUsers({
    required String divisionId,
    String? search,
    int limit = 200,
  });
  Future<Map<String, List<Map<String, dynamic>>>> getDropdowns({
    String? divisionId,
    String? carId,
    String? searchUser,
    int userLimit = 200,
  });

  // Drafts
  Future<void> saveDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    bool replaceItems = true,
    String? note,
  });
  Future<Map<String, dynamic>?> getDraft({required String userId});
  Future<void> deleteDraft({required String userId});
  Future<List<String>> submitDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    String? note,
  });

  // Approval
  Future<Map<String, dynamic>> approvePlan({
    required String planId,
    required String userId,
  });
  Future<Map<String, dynamic>> rejectPlan({
    required String planId,
    required String userId,
    required String rejectNote,
  });
  Future<Map<String, dynamic>> resubmitPlan({
    required String planId,
    required String userId,
    required List<Map<String, dynamic>> items,
  });
  Future<void> deleteRejectedPlan({
    required String planId,
    required String userId,
  });
  Future<Map<String, dynamic>> reviewPlan({
    required String planId,
    required bool approved,
  });
  Future<Map<String, dynamic>> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  });

  // Legacy / fallback
  Future<Map<String, dynamic>> createPlan({
    String coreId = '',
    String carId = '',
    String sourceType = 'ADDITIONAL',
    String sourceRefId = '',
    String? initialStatus,
    bool syncToTasks = false,
    bool isUrgent = false,
    required String unitName,
    required String panelName,
    required String assignedDivision,
    required String assignedUserId,
    required String assignedTo,
    required String description,
    required double targetHours,
    double? totalProjectHours,
    String? startDate,
    String? deadlineDate,
    required String workDate,
    required String startTime,
    required String finishTime,
    required bool isOvertime,
    bool isNonTechnicalJob = false,
    required String note,
  });
}
