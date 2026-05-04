library;

abstract class QcDataSource {
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

/// LocalQcDataSource — offline/mock implementation
class LocalQcDataSource implements QcDataSource {
  @override
  Future<List<Map<String, dynamic>>> getQcItems({
    required String division,
    required bool canValidate,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getQcItemsByDivisionId({
    required String divisionId,
    String? unitId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    return {'hasMore': false, 'total': 0, 'groups': []};
  }

  @override
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
  }) async {}

  @override
  Future<Map<String, dynamic>?> findQcItemByCoreId(String coreId) async => null;
}
