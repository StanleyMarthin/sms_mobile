library;

import '../entities/qc_item.dart';

abstract class QcRepository {
  Future<List<QcDivision>> getDivisions();

  Future<QcPagedResponse> getQcItems({
    required String divisionId,
    String? unitId,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<void> submitQc({
    required String coreId,
    required String action, // "lolos" | "tidak_lolos"
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

  Future<QcItem?> findQcItemByCoreId(String coreId);
}
