/*
Tujuan: Implementasi repository QC yang memetakan data source ke entity domain.
Caller: QC pages, Bloc, dan tests.
Dependensi: QcDataSource, entity QC.
Main Functions: QcRepositoryImpl.
Side Effects: Delegasi HTTP lewat datasource remote.
*/

library;

import '../../domain/entities/qc_item.dart';
import '../../domain/repositories/qc_repository.dart';
import '../datasources/qc_datasource.dart';

class QcRepositoryImpl implements QcRepository {
  QcRepositoryImpl({required this.dataSource});

  final QcDataSource dataSource;

  @override
  Future<List<QcDivision>> getDivisions() async {
    final rows = await dataSource.getQcDivisions();
    return rows
        .map(
          (d) => QcDivision(
            divisionId: d['divisionId']?.toString() ?? '',
            divisionName: d['divisionName']?.toString() ?? '-',
            totalItem: (d['totalItem'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<QcPagedResponse> getQcItems({
    required String divisionId,
    String? unitId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final responseMap = await dataSource.getQcItemsByDivisionId(
      divisionId: divisionId,
      unitId: unitId,
      search: search,
      page: page,
      pageSize: pageSize,
    );

    final dynamicGroups = responseMap['groups'] as List<dynamic>? ?? [];
    final hasMore = responseMap['hasMore'] as bool? ?? false;
    final total = (responseMap['total'] as num?)?.toInt() ?? 0;

    final groups = dynamicGroups.map((gRaw) {
      final g = gRaw as Map<String, dynamic>;
      final jobdescs =
          (g['jobdescs'] as List?)
              ?.map((item) => _mapItem(item as Map<String, dynamic>))
              .toList() ??
          [];
      return QcUnitGroup(
        unitId: g['unitId'] as String? ?? '',
        unitName: (g['unitName'] as String?)?.isNotEmpty == true
            ? g['unitName'] as String
            : 'Tanpa Unit',
        jobdescs: jobdescs,
      );
    }).toList();

    return QcPagedResponse(
      groups: groups,
      hasMore: hasMore,
      page: page,
      total: total,
    );
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
  }) async {
    await dataSource.submitQc(
      coreId: coreId,
      action: action,
      notes: notes,
      inspectionDurationMinutes: inspectionDurationMinutes,
      photoBeforeUrl: photoBeforeUrl,
      evidencePhotoUrl: evidencePhotoUrl,
      reworkDate: reworkDate,
      reworkAssignedUser: reworkAssignedUser,
      reworkDailyHours: reworkDailyHours,
      reworkStartTime: reworkStartTime,
      reworkFinishTime: reworkFinishTime,
      reworkDescription: reworkDescription,
      reworkIsOvertime: reworkIsOvertime,
      reworkIsPriority: reworkIsPriority,
    );
  }

  @override
  Future<QcV2PagedResponse> getV2Queue({
    String? divisionId,
    String? unitId,
    String? panelId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await dataSource.getV2Queue(
      divisionId: divisionId,
      unitId: unitId,
      panelId: panelId,
      page: page,
      pageSize: pageSize,
    );
    final items = (response['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapV2Item)
        .toList();
    return QcV2PagedResponse(
      items: items,
      hasMore: response['hasMore'] as bool? ?? false,
      page: (response['page'] as num?)?.toInt() ?? page,
      total: (response['total'] as num?)?.toInt() ?? items.length,
    );
  }

  @override
  Future<QcV2SubmitResult> submitV2Qc({
    required String coreId,
    required String commandId,
    required int expectedVersion,
    required String action,
    String? notes,
    List<String>? photos,
    int? inspectionDurationMinutes,
  }) async {
    final row = await dataSource.submitV2Qc(
      coreId: coreId,
      commandId: commandId,
      expectedVersion: expectedVersion,
      action: action,
      notes: notes,
      photos: photos,
      inspectionDurationMinutes: inspectionDurationMinutes,
    );
    return QcV2SubmitResult(
      qcId: row['qcId']?.toString() ?? '',
      result: row['result']?.toString() ?? action,
      reused: row['reused'] as bool? ?? false,
      version: (row['version'] as num?)?.toInt() ?? expectedVersion,
      remainingHours: (row['remainingHours'] as num?)?.toDouble(),
      nextAction: row['nextAction']?.toString(),
    );
  }

  @override
  Future<QcItem?> findQcItemByCoreId(String coreId) async {
    final item = await dataSource.findQcItemByCoreId(coreId);
    if (item == null) return null;
    return _mapItem(item);
  }

  QcV2QueueItem _mapV2Item(Map<String, dynamic> item) {
    return QcV2QueueItem(
      coreId: item['coreId']?.toString() ?? '',
      carId: item['carId']?.toString() ?? '',
      unitName: item['unitName']?.toString() ?? '-',
      panelId: item['panelId']?.toString() ?? '',
      panelName: item['panelName']?.toString() ?? '-',
      countdownName: item['countdownName']?.toString() ?? '-',
      countdownStatus: item['countdownStatus']?.toString() ?? '',
      remainingHours: (item['remainingHours'] as num?)?.toDouble() ?? 0,
      qcState: item['qcState']?.toString() ?? 'PENDING',
      latestQcResult: item['latestQcResult']?.toString(),
      latestQcLevel: item['latestQcLevel']?.toString(),
      validatedPlanCount: (item['validatedPlanCount'] as num?)?.toInt() ?? 0,
      validatedPlanIds: (item['validatedPlanIds'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      version: (item['version'] as num?)?.toInt() ?? 0,
    );
  }

  QcItem _mapItem(Map<String, dynamic> item) {
    return QcItem(
      qcId: item['qcId'] as String? ?? '',
      coreId: item['coreId'] as String? ?? '',
      unitId: item['unitId'] as String? ?? '',
      unitName: item['unitName'] as String? ?? '-',
      panelName: item['panelName'] as String? ?? '-',
      jobName: item['jobName'] as String? ?? '-',
      mechanicDivision: item['mechanicDivision'] as String? ?? '',
      totalActualHours: (item['totalActualHours'] as num?)?.toDouble() ?? 0,
      targetHoursRevised: (item['targetHoursRevised'] as num?)?.toDouble() ?? 0,
      countdownStatus: item['countdownStatus'] as String? ?? '',
      qcLevel: item['qcLevel'] as String?,
      qcLastStatus: item['qcLastStatus'] as String?,
      qcNotes: item['qcNotes'] as String?,
      inspectionDurationMinutes: item['inspectionDurationMinutes'] as int?,
      remainingHours: (item['remainingHours'] as num?)?.toDouble(),
      reworkDate: item['reworkDate'] as String?,
    );
  }
}
