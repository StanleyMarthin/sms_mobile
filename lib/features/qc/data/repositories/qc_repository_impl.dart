library;

import '../../domain/entities/qc_item.dart';
import '../../domain/repositories/qc_repository.dart';
import '../datasources/remote_qc_datasource.dart';
import '../datasources/local_qc_datasource.dart';

class QcRepositoryImpl implements QcRepository {
  const QcRepositoryImpl({required this.dataSource});

  final QcDataSource dataSource;

  @override
  Future<List<QcDivision>> getDivisions() async {
    if (dataSource is RemoteQcDataSource) {
      final rows = await (dataSource as RemoteQcDataSource).getQcDivisions();
      return rows.map((d) => QcDivision(
        divisionId: d['divisionId']?.toString() ?? '',
        divisionName: d['divisionName']?.toString() ?? '-',
        totalItem: (d['totalItem'] as num?)?.toInt() ?? 0,
      )).toList();
    }
    return [];
  }

  @override
  Future<QcPagedResponse> getQcItems({
    required String divisionId,
    String? unitId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (dataSource is RemoteQcDataSource) {
      final responseMap = await (dataSource as RemoteQcDataSource).getQcItemsByDivisionId(
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
        final jobdescs = (g['jobdescs'] as List?)
                ?.map((item) => _mapItem(item as Map<String, dynamic>))
                .toList() ??
            [];
        return QcUnitGroup(
          unitId:   g['unitId'] as String? ?? '',
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
    return QcPagedResponse(groups: [], hasMore: false, page: page, total: 0);
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
      coreId:                    coreId,
      action:                    action,
      notes:                     notes,
      inspectionDurationMinutes: inspectionDurationMinutes,
      photoBeforeUrl:            photoBeforeUrl,
      evidencePhotoUrl:          evidencePhotoUrl,
      reworkDate:                reworkDate,
      reworkAssignedUser:        reworkAssignedUser,
      reworkDailyHours:          reworkDailyHours,
      reworkStartTime:           reworkStartTime,
      reworkFinishTime:          reworkFinishTime,
      reworkDescription:         reworkDescription,
      reworkIsOvertime:          reworkIsOvertime,
      reworkIsPriority:          reworkIsPriority,
    );
  }

  @override
  Future<QcItem?> findQcItemByCoreId(String coreId) async {
    final item = await dataSource.findQcItemByCoreId(coreId);
    if (item == null) return null;
    return _mapItem(item);
  }

  QcItem _mapItem(Map<String, dynamic> item) {
    return QcItem(
      qcId:             item['qcId']  as String? ?? '',
      coreId:           item['coreId'] as String? ?? '',
      unitId:           item['unitId'] as String? ?? '',
      unitName:         item['unitName'] as String? ?? '-',
      panelName:        item['panelName'] as String? ?? '-',
      jobName:          item['jobName'] as String? ?? '-',
      mechanicDivision: item['mechanicDivision'] as String? ?? '',
      totalActualHours: (item['totalActualHours']  as num?)?.toDouble() ?? 0,
      targetHoursRevised: (item['targetHoursRevised'] as num?)?.toDouble() ?? 0,
      countdownStatus:  item['countdownStatus'] as String? ?? '',
      qcLevel:          item['qcLevel'] as String?,
      qcLastStatus:     item['qcLastStatus'] as String?,
      qcNotes:          item['qcNotes'] as String?,
      inspectionDurationMinutes: item['inspectionDurationMinutes'] as int?,
      remainingHours:   (item['remainingHours'] as num?)?.toDouble(),
      reworkDate:       item['reworkDate'] as String?,
    );
  }
}
