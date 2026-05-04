library;

import '../../../qc/data/datasources/local_qc_datasource.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../datasources/local_countdown_datasource.dart';

class CountdownRepositoryImpl implements CountdownRepository {
  const CountdownRepositoryImpl({
    required this.dataSource,
    this.qcDataSource,
  });

  final CountdownDataSource dataSource;
  final QcDataSource? qcDataSource;

  @override
  Future<List<CountdownUnit>> getUnits({
    required String? role,
    required String? division,
  }) async {
    final units = await dataSource.getUnits();
    final normalizedDivision = division?.trim().toUpperCase();
    final canSeeAll =
        role == 'pm' || role == 'adv' || normalizedDivision == 'MANAGEMENT';
    final filtered = canSeeAll
        ? units
        : units.where((item) {
            final unitDivision =
                (item['division'] as String?)?.trim().toUpperCase();
            return unitDivision == normalizedDivision;
          }).toList();
    final visibleUnits = filtered.isEmpty ? units : filtered;
    return visibleUnits.map(_mapUnit).toList();
  }



  @override
  Future<List<CountdownDivision>> getDivisions(String carId) async {
    final rows = await dataSource.getDivisions(carId);
    return rows.map((item) => CountdownDivision(
      divisionId: (item['divisionId'] as num?)?.toInt() ?? 0,
      divisionName: (item['divisionName'] as String?) ?? '-',
      code: (item['code'] as String?) ?? '',
      divisionProgress: ((item['divisionProgress'] as num?) ?? 0).toDouble(),
    )).toList();
  }

  @override
  Future<List<CountdownSection>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
  }) async {
    final rows = await dataSource.getSections(carId: carId, divisionId: divisionId, search: search, status: status);
    return rows.map((item) => CountdownSection(
      panelId: (item['panelId'] as num?)?.toInt() ?? 0,
      sectionName: (item['sectionName'] as String?) ?? '-',
      section: (item['section'] as String?) ?? '-',
      totalJobdesc: (item['totalJobdesc'] as int?) ?? 0,
      totalRemainingHours: ((item['totalRemainingHours'] as num?) ?? 0).toDouble(),
      totalTargetHours: ((item['totalTargetHours'] as num?) ?? 0).toDouble(),
      sectionProgress: ((item['sectionProgress'] as num?) ?? 0).toDouble(),
      sectionStatus: (item['sectionStatus'] as String?) ?? 'PLAN',
    )).toList();
  }

  @override
  Future<List<CountdownJobdesc>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
  }) async {
    final rows = await dataSource.getJobdescs(
      carId: carId,
      divisionId: divisionId,
      panelId: panelId,
      search: search,
      status: status,
    );
    return Future.wait(rows.map((item) async {
      final qcItem = qcDataSource != null
          ? await qcDataSource!.findQcItemByCoreId(item['id'] as String? ?? '')
          : null;
      return _mapCountdown(item, qcItem);
    }));
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
    final qcLastStatusFromItem = (qcItem?['qcLastStatus'] as String?)?.toUpperCase();
    final qcLevel = qcItem?['qcLevel'] as String?;
    final kdCheckpointDone = qcLastStatusFromItem == 'LOLOS' || qcLastStatusFromItem == 'TIDAK_LOLOS';
    final qcLastStatus = kdCheckpointDone && qcLastStatusFromItem == 'LOLOS'
        ? 'LOLOS'
        : (qcLastStatusFromItem ?? item['qcLastStatus'] as String?);

    return CountdownJobdesc(
      id: (item['id'] as String?) ?? '',
      carId: (item['carId'] as String?) ?? '',
      divisionId: (item['divisionId'] ?? item['division_id'] ?? '').toString(),
      panelName: (item['panelName'] as String?) ?? '-',
      sectionName: (item['sectionName'] as String?) ?? '-',
      jobdesc: (item['jobdesc'] as String?) ?? '-',
      taskCategory: (item['taskCategory'] as String?) ?? 'MAIN',
      progress: (item['actualProgressPercent'] as int?) ?? 0,
      status: (item['status'] as String?) ?? 'PLAN',
      targetHoursInitial: ((item['targetHoursInitial'] as num?) ?? 0).toDouble(),
      timeExtensionHours: ((item['timeExtensionHours'] as num?) ?? 0).toDouble(),
      targetHoursRevised: ((item['targetHoursRevised'] as num?) ?? 0).toDouble(),
      totalActualHours: ((item['totalActualHours'] as num?) ?? 0).toDouble(),
      remainingHours: ((item['remainingHours'] as num?) ?? 0).toDouble(),
      startDate: (item['startDate'] as String?) ?? DateTime.now().toIso8601String().split('T').first,
      deadlineDate: (item['deadlineDate'] as String?) ?? '-',
      qcLastStatus: qcLastStatus,
      qcValidationStatus: qcLevel, // gunakan qcLevel sebagai validationStatus
      qcResultStatus: qcLastStatusFromItem,
      qcEstimatedReworkHours: null,
      qcReworkDeadlineDate: qcItem?['reworkDate'] as String?,
      qcAdvisorNotes: qcItem?['qcNotes'] as String?,
      revisionRequestStatus: item['extensionRequestStatus'] as String?,
      requestedRevisionHours:
          (item['extensionRequestedHours'] as num?)?.toDouble(),
      requestedRevisionDeadline: item['extensionRequestedDeadline'] as String?,
      requestedRevisionReason: item['extensionRequestReason'] as String?,
      approvedRevisionHours:
          (item['extensionApprovedHours'] as num?)?.toDouble(),
      approvedRevisionDeadline: item['extensionApprovedDeadline'] as String?,
      approvedRevisionByName: item['extensionApprovedByName'] as String?,
      rejectedRevisionByName: item['extensionRejectedByName'] as String?,
      isLockedByOtherDivision: item['isLockedByOtherDivision'] as bool? ?? false,
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

  @override
  Future<List<CountdownJobdesc>> getRevisionRequests({String? carId}) async {
    final rows = await dataSource.getRevisionRequests(carId: carId);
    return rows.map((item) {
      return CountdownJobdesc(
        id: item['countdownId'] as String? ?? '',
        carId: item['carId'] as String? ?? '',
        divisionId: (item['divisionId'] ?? '').toString(),
        panelName: item['panelName'] as String? ?? '-',
        sectionName: '-',
        jobdesc: item['jobdesc'] as String? ?? '-',
        taskCategory: '-',
        progress: 0,
        status: item['status'] as String? ?? 'REQUESTED',
        targetHoursInitial: 0.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: (item['currentHours'] as num?)?.toDouble() ?? 0.0,
        totalActualHours: 0.0,
        remainingHours: 0.0,
        startDate: '-',
        deadlineDate: item['currentDeadline'] as String? ?? '-',
        qcLastStatus: null,
        qcValidationStatus: null,
        qcResultStatus: null,
        qcEstimatedReworkHours: null,
        qcReworkDeadlineDate: null,
        qcAdvisorNotes: null,
        revisionRequestStatus: item['status'] as String?,
        requestedRevisionHours: (item['requestedHours'] as num?)?.toDouble(),
        requestedRevisionDeadline: item['requestedDeadline'] as String?,
        requestedRevisionReason: item['reason'] as String?,
        requestedRevisionByName: item['requestedByName'] as String?,
        requestedRevisionAt: DateTime.tryParse(item['requestedAt']?.toString() ?? ''),
      );
    }).toList();
  }

  @override
  Future<void> requestRevision({
    required String countdownId,
    required double requestedHours,
    required String requestedDeadline,
    required String reason,
  }) {
    return dataSource.requestRevision(
      countdownId: countdownId,
      requestedHours: requestedHours,
      requestedDeadline: requestedDeadline,
      reason: reason,
    );
  }

  @override
  Future<void> processRevisionRequest({
    required String requestId,
    required bool approved,
    required double approvedHours,
    required String approvedDeadline,
  }) {
    return dataSource.processRevisionRequest(
      requestId: requestId,
      approved: approved,
      approvedHours: approvedHours,
      approvedDeadline: approvedDeadline,
    );
  }

  @override
  Future<void> markAsQcReady(String countdownId) {
    return dataSource.markAsQcReady(countdownId);
  }

  @override
  Future<void> moApproveRevision({
    required String requestId,
    required bool approved,
    String? notes,
  }) {
    return dataSource.moApproveRevision(
      requestId: requestId,
      approved: approved,
      notes: notes,
    );
  }
}
