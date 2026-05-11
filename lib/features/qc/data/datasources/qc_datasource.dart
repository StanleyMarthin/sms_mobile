abstract class QcDataSource {
  Future<List<Map<String, dynamic>>> getQcDivisions();

  Future<List<Map<String, dynamic>>> getQcItems({
    required String division,
    required bool canValidate,
  });

  Future<Map<String, dynamic>> getQcItemsByDivisionId({
    required String divisionId,
    String? unitId,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<void> submitQc({
    required String coreId,
    required String action,
    String? notes,
    int? inspectionDurationMinutes,
    String? photoBeforeUrl,
    String? evidencePhotoUrl,
    String? reworkDate,
    String? reworkAssignedUser,
    String? reworkDailyHours,
    String? reworkStartTime,
    String? reworkFinishTime,
    String? reworkDescription,
    bool? reworkIsOvertime,
    bool? reworkIsPriority,
  });

  Future<Map<String, dynamic>?> findQcItemByCoreId(String coreId);
}
