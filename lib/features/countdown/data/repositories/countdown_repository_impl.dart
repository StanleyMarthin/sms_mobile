library;

import '../../../qc/data/datasources/local_qc_datasource.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../datasources/local_countdown_datasource.dart';

class CountdownRepositoryImpl implements CountdownRepository {
  const CountdownRepositoryImpl({
    required this.dataSource,
    required this.qcDataSource,
  });

  final CountdownDataSource dataSource;
  final QcDataSource qcDataSource;

  @override
  Future<List<CountdownUnit>> getUnits({
    required String? role,
    required String? division,
  }) async {
    final units = await dataSource.getUnits();
    final normalizedDivision = division?.trim().toUpperCase();
    final canSeeAll = role == 'pm' || role == 'adv' || normalizedDivision == 'MANAGEMENT';
    final filtered = canSeeAll
        ? units
        : units.where((item) {
            final unitDivision = (item['division'] as String?)?.trim().toUpperCase();
            return unitDivision == normalizedDivision;
          }).toList();
    final visibleUnits = filtered.isEmpty ? units : filtered;
    return visibleUnits.map(_mapUnit).toList();
  }

  @override
  Future<List<CountdownJobdesc>> getCountdowns(String carId) async {
    final rows = await dataSource.getCountdowns(carId);
    return Future.wait(
      rows.map((item) async {
        final qcItem = await qcDataSource.findQcItemByCoreId(item['id'] as String);
        return _mapCountdown(item, qcItem);
      }),
    );
  }

  @override
  Future<List<CountdownDetailItem>> getDetails(String countdownId) async {
    final rows = await dataSource.getDetails(countdownId);
    return rows.map(_mapDetail).toList();
  }

  CountdownUnit _mapUnit(Map<String, dynamic> item) {
    return CountdownUnit(
      carId: item['carId'] as String,
      unitName: item['unitName'] as String,
      owner: item['owner'] as String,
      progress: item['progress'] as int,
      status: item['status'] as String,
      division: item['division'] as String,
      deliveryDate: item['deliveryDate'] as String?,
    );
  }

  CountdownJobdesc _mapCountdown(
    Map<String, dynamic> item,
    Map<String, dynamic>? qcItem,
  ) {
    final qcValidationStatus = qcItem?['validationStatus'] as String?;
    final qcResultStatus = qcItem?['resultStatus'] as String?;
    final kdCheckpointDone = qcItem?['kdCheckpointBy'] != null || qcValidationStatus == 'KD_DONE';
    final qcLastStatus = kdCheckpointDone && qcResultStatus == 'LOLOS'
        ? 'LOLOS'
        : item['qcLastStatus'] as String?;

    return CountdownJobdesc(
      id: item['id'] as String,
      carId: item['carId'] as String,
      panelName: item['panelName'] as String,
      sectionName: item['sectionName'] as String,
      jobdesc: item['jobdesc'] as String,
      taskCategory: item['taskCategory'] as String,
      progress: item['actualProgressPercent'] as int,
      status: item['status'] as String,
      targetHoursInitial: (item['targetHoursInitial'] as num).toDouble(),
      timeExtensionHours: (item['timeExtensionHours'] as num).toDouble(),
      targetHoursRevised: (item['targetHoursRevised'] as num).toDouble(),
      totalActualHours: (item['totalActualHours'] as num).toDouble(),
      remainingHours: (item['remainingHours'] as num).toDouble(),
      startDate: item['startDate'] as String,
      deadlineDate: item['deadlineDate'] as String,
      qcLastStatus: qcLastStatus,
      qcValidationStatus: qcValidationStatus,
      qcResultStatus: qcResultStatus,
      qcEstimatedReworkHours: (qcItem?['estimatedReworkHours'] as num?)?.toDouble(),
      qcReworkDeadlineDate: qcItem?['reworkDeadlineDate'] as String?,
      qcAdvisorNotes: (qcItem?['pmNotes'] as String?) ?? (qcItem?['advNotes'] as String?),
      revisionRequestStatus: item['extensionRequestStatus'] as String?,
      requestedRevisionHours: (item['extensionRequestedHours'] as num?)?.toDouble(),
      requestedRevisionDeadline: item['extensionRequestedDeadline'] as String?,
      requestedRevisionReason: item['extensionRequestReason'] as String?,
      approvedRevisionHours: (item['extensionApprovedHours'] as num?)?.toDouble(),
      approvedRevisionDeadline: item['extensionApprovedDeadline'] as String?,
      approvedRevisionByName: item['extensionApprovedByName'] as String?,
      rejectedRevisionByName: item['extensionRejectedByName'] as String?,
    );
  }

  CountdownDetailItem _mapDetail(Map<String, dynamic> item) {
    return CountdownDetailItem(
      id: item['id'] as String,
      countdownId: item['countdownId'] as String,
      employeeName: item['employeeName'] as String,
      job: item['job'] as String,
      detailJob: item['detailJob'] as String,
      workDate: item['workDate'] as String,
      startTime: item['startTime'] as String,
      finishTime: item['finishTime'] as String,
      targetHours: (item['targetHours'] as num).toDouble(),
      durationHours: (item['durationHours'] as num).toDouble(),
      remainingHours: (item['remainingHours'] as num).toDouble(),
      overtimeHours: (item['overtimeHours'] as num).toDouble(),
      percentage: (item['percentage'] as num).toDouble(),
      status: item['status'] as String,
    );
  }
}