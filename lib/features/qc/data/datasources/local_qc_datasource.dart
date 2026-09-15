/*
Tujuan: Datasource lokal/mock QC untuk kompatibilitas test dan offline shell.
Caller: Pengembangan lokal bila datasource mock dipakai.
Dependensi: Tidak ada.
Main Functions: LocalQcDataSource.
Side Effects: Tidak ada.
*/

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

  Future<Map<String, dynamic>> getV2Queue({
    String? divisionId,
    String? unitId,
    String? panelId,
    int page = 1,
    int pageSize = 20,
  });

  Future<Map<String, dynamic>> submitV2Qc({
    required String coreId,
    required String commandId,
    required int expectedVersion,
    required String action,
    String? notes,
    List<String>? photos,
    int? inspectionDurationMinutes,
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
  Future<Map<String, dynamic>> getV2Queue({
    String? divisionId,
    String? unitId,
    String? panelId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return {
      'page': page,
      'pageSize': pageSize,
      'total': 0,
      'hasMore': false,
      'items': [],
    };
  }

  @override
  Future<Map<String, dynamic>> submitV2Qc({
    required String coreId,
    required String commandId,
    required int expectedVersion,
    required String action,
    String? notes,
    List<String>? photos,
    int? inspectionDurationMinutes,
  }) async {
    return {
      'qcId': commandId,
      'result': action,
      'reused': false,
      'version': expectedVersion + 1,
    };
  }

  @override
  Future<Map<String, dynamic>?> findQcItemByCoreId(String coreId) async => null;
}
