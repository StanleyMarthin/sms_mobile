/*
Tujuan: Kontrak repository QC legacy dan adapter QC V2.
Caller: QC presentation layer dan dependency injection.
Dependensi: Entity QC.
Main Functions: QcRepository.
Side Effects: Implementasi dapat melakukan HTTP call.
*/

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

  Future<QcV2PagedResponse> getV2Queue({
    String? divisionId,
    String? unitId,
    String? panelId,
    int page = 1,
    int pageSize = 20,
  });

  Future<QcV2SubmitResult> submitV2Qc({
    required String coreId,
    required String commandId,
    required int expectedVersion,
    required String action,
    String? notes,
    List<String>? photos,
    int? inspectionDurationMinutes,
  });

  Future<QcItem?> findQcItemByCoreId(String coreId);
}
