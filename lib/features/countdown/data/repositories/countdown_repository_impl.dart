/*
Tujuan: Repository countdown untuk memetakan datasource ke entity domain countdown dan QC.
Caller: Countdown UI, monitoring grouped pages, dialog pembuatan plan.
Dependensi: CountdownDataSource, QcDataSource, entity countdown, failures.
Main Functions: getUnits, getJobdescs, getDetails.
Side Effects: Tidak ada langsung; datasource turunannya melakukan HTTP call.
*/
library;

import '../../../qc/data/datasources/qc_datasource.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../datasources/countdown_datasource.dart';

class CountdownRepositoryImpl implements CountdownRepository {
  CountdownRepositoryImpl({required this.dataSource, this.qcDataSource});

  final CountdownDataSource dataSource;
  final QcDataSource? qcDataSource;

  String _normalizeScopeRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    return switch (normalized) {
      'global' || 'pm' || 'mp' || 'admin' || 'mis' => 'GLOBAL',
      'kp' || 'kepala_produksi' || 'kepala_project' => 'KP',
      'adv' || 'advisor' => 'ADV',
      'kd' || 'ketua_divisi' || 'kepala_divisi' => 'KD',
      'field' || 'op' || 'team_lapangan' => 'FIELD',
      _ => normalized.toUpperCase(),
    };
  }

  @override
  Future<List<CountdownUnit>> getUnits({
    required String? role,
    required String? division,
  }) async {
    final units = await dataSource.getUnits();
    final normalizedDivision = division?.trim().toUpperCase();
    final scopeRole = _normalizeScopeRole(role);
    final canSeeAll =
        scopeRole == 'GLOBAL' ||
        scopeRole == 'ADV' ||
        normalizedDivision == 'MANAGEMENT';
    final filtered = canSeeAll
        ? units
        : units.where((item) {
            final unitDivision = (item['division'] as String?)
                ?.trim()
                .toUpperCase();
            return unitDivision == normalizedDivision;
          }).toList();
    final visibleUnits = filtered.isEmpty ? units : filtered;
    return visibleUnits.map(_mapUnit).toList();
  }

  @override
  Future<List<CountdownDivision>> getDivisions(String carId) async {
    final rows = await dataSource.getDivisions(carId);
    return rows
        .map(
          (item) => CountdownDivision(
            divisionId: (item['divisionId'] as num?)?.toInt() ?? 0,
            divisionName: (item['divisionName'] as String?) ?? '-',
            code: (item['code'] as String?) ?? '',
            divisionProgress: ((item['divisionProgress'] as num?) ?? 0)
                .toDouble(),
          ),
        )
        .toList();
  }

  @override
  Future<MasterPanelTracking> getMasterPanelTracking(String unitId) async {
    final row = await dataSource.getMasterPanelTracking(unitId);
    return _mapMasterPanelTracking(row);
  }

  @override
  Future<MasterPanelDetail> getMasterPanelDetail({
    required String unitId,
    required int panelId,
  }) async {
    final row = await dataSource.getMasterPanelDetail(
      unitId: unitId,
      panelId: panelId,
    );
    return _mapMasterPanelDetail(row);
  }

  @override
  Future<CountdownCreateOptions> getCountdownCreateOptions(
    String unitId,
  ) async {
    final raw = await dataSource.getCountdownCreateOptions(unitId);
    return CountdownCreateOptions(
      divisions: _asMapList(raw['divisions'])
          .map(
            (item) => CountdownCreateDivisionOption(
              id: _asInt(item['id']),
              name: _asText(item['name'], '-'),
            ),
          )
          .where((item) => item.id > 0)
          .toList(),
      jobTypes: _asMapList(raw['jobTypes'])
          .map(
            (item) => CountdownCreateJobTypeOption(
              id: _asText(item['id'], ''),
              name: _asText(item['job_name'] ?? item['name'], '-'),
              divisionId: _nullableInt(item['division_id']),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(),
      users: _asMapList(raw['users'])
          .map(
            (item) => CountdownCreateUserOption(
              id: _asText(item['id'], ''),
              name: _asText(item['name'], '-'),
              divisionId: _nullableInt(
                item['divisionId'] ?? item['division_id'],
              ),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> createMasterPanelCountdown({
    required String unitId,
    required int masterPanelId,
    required int divisionId,
    required String jobTypeId,
    required String description,
    required double targetHours,
    required String picPlan,
    String? startDate,
    String? deadlineDate,
    String taskCategory = 'MAIN',
  }) {
    return dataSource.createMasterPanelCountdown(
      unitId: unitId,
      masterPanelId: masterPanelId,
      divisionId: divisionId,
      jobTypeId: jobTypeId,
      description: description,
      targetHours: targetHours,
      picPlan: picPlan,
      startDate: startDate,
      deadlineDate: deadlineDate,
      taskCategory: taskCategory,
    );
  }

  @override
  Future<List<CountdownSection>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  }) async {
    final rows = await dataSource.getSections(
      carId: carId,
      divisionId: divisionId,
      search: search,
      status: status,
      plannable: plannable,
    );
    return rows
        .map(
          (item) => CountdownSection(
            panelId: (item['panelId'] as num?)?.toInt() ?? 0,
            sectionName: (item['sectionName'] as String?) ?? '-',
            section: (item['section'] as String?) ?? '-',
            totalJobdesc: (item['totalJobdesc'] as int?) ?? 0,
            totalRemainingHours: ((item['totalRemainingHours'] as num?) ?? 0)
                .toDouble(),
            totalTargetHours: ((item['totalTargetHours'] as num?) ?? 0)
                .toDouble(),
            sectionProgress: ((item['sectionProgress'] as num?) ?? 0)
                .toDouble(),
            sectionStatus: (item['sectionStatus'] as String?) ?? 'PLAN',
            totalTargetHoursAlias: item['totalTargetHoursAlias'] as String?,
            totalRemainingHoursAlias:
                item['totalRemainingHoursAlias'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<List<CountdownJobdesc>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  }) async {
    final rows = await dataSource.getJobdescs(
      carId: carId,
      divisionId: divisionId,
      panelId: panelId,
      search: search,
      status: status,
      plannable: plannable,
    );
    return Future.wait(
      rows.map((item) async {
        final qcItem = qcDataSource != null
            ? await qcDataSource!.findQcItemByCoreId(
                item['id'] as String? ?? '',
              )
            : null;
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

  MasterPanelTracking _mapMasterPanelTracking(Map<String, dynamic> item) {
    final summary = _mapTrackingSummary(
      item['summary'] is Map ? item['summary'] as Map : const {},
    );
    final components = (item['components'] as List? ?? const [])
        .whereType<Map>()
        .map(_mapTrackingComponent)
        .toList();
    return MasterPanelTracking(summary: summary, components: components);
  }

  MasterPanelTrackingSummary _mapTrackingSummary(Map item) {
    return MasterPanelTrackingSummary(
      total: _asInt(item['total']),
      pending: _asInt(item['pending']),
      progress: _asInt(item['progress']),
      order: _asInt(item['order']),
      done: _asInt(item['done']),
    );
  }

  MasterPanelTrackingComponent _mapTrackingComponent(Map item) {
    return MasterPanelTrackingComponent(
      componentId: _nullableInt(item['componentId']),
      componentName: _asText(item['componentName'], 'Tanpa Component'),
      totalPanels: _asInt(item['totalPanels']),
      totalParts: _asInt(item['totalParts']),
      pendingCount: _asInt(item['pendingCount']),
      progressCount: _asInt(item['progressCount']),
      orderCount: _asInt(item['orderCount']),
      panels: (item['panels'] as List? ?? const [])
          .whereType<Map>()
          .map(_mapTrackingPanel)
          .toList(),
    );
  }

  MasterPanelTrackingPanel _mapTrackingPanel(Map item) {
    return MasterPanelTrackingPanel(
      panelId: _nullableInt(item['panelId']),
      panelName: _asText(item['panelName'], 'Tanpa Panel'),
      totalParts: _asInt(item['totalParts']),
      activityCount: _asInt(item['activityCount']),
      progressPercent: _asDouble(item['progressPercent']),
      parts: (item['parts'] as List? ?? const [])
          .whereType<Map>()
          .map(_mapTrackingPart)
          .toList(),
    );
  }

  MasterPanelTrackingPart _mapTrackingPart(Map item) {
    final activity = item['activitySummary'] is Map
        ? item['activitySummary'] as Map
        : const {};
    return MasterPanelTrackingPart(
      masterPanelId: _asInt(item['masterPanelId']),
      componentName: _asText(item['componentName'], 'Tanpa Component'),
      panelName: _asText(item['panelName'], 'Tanpa Panel'),
      namePart: _asText(item['namePart'], 'Item'),
      aliasName: _nullableText(item['aliasName']),
      partNumber: _nullableText(item['partNumber']),
      qty: _asDouble(item['qty']),
      initialCondition: _asText(item['initialCondition'], 'UNKNOWN'),
      currentStatus: _asText(item['currentStatus'], 'WAITING'),
      trackingStatus: _asText(item['trackingStatus'], 'PENDING'),
      photoCount: _asInt(item['photoCount']),
      activitySummary: MasterPanelTrackingActivitySummary(
        countdownCount: _asInt(activity['countdownCount']),
        activeCountdownCount: _asInt(activity['activeCountdownCount']),
        jobPlanCount: _asInt(activity['jobPlanCount']),
        prCount: _asInt(activity['prCount']),
        woCount: _asInt(activity['woCount']),
        wovCount: _asInt(activity['wovCount']),
      ),
    );
  }

  MasterPanelDetail _mapMasterPanelDetail(Map item) {
    return MasterPanelDetail(
      id: _asInt(item['id']),
      name: _asText(
        item['name'] ?? item['namePart'] ?? item['name_part'],
        'Item',
      ),
      componentName: _asText(
        item['componentName'] ?? item['component_name'],
        'Tanpa Component',
      ),
      panelName: _asText(
        item['panelName'] ?? item['panel_name'],
        'Tanpa Panel',
      ),
      partNumber: _nullableText(item['partNumber'] ?? item['part_number']),
      qty: _asDouble(item['qty'] ?? item['qty_normal']),
      initialCondition: _asText(
        item['initialCondition'] ?? item['initial_condition'],
        'UNKNOWN',
      ),
      currentStatus: _asText(
        item['currentStatus'] ?? item['current_status'],
        'WAITING',
      ),
      notes: _nullableText(item['notes']),
      images: (item['media'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (media) => MasterPanelImage(
              id: _asInt(media['id']),
              fileUrl: _asText(media['fileUrl'] ?? media['file_url'], ''),
              caption: _nullableText(media['caption']),
            ),
          )
          .where((media) => media.fileUrl.isNotEmpty)
          .toList(),
      countdownCount: (item['jobdescs'] as List? ?? const []).length,
    );
  }

  CountdownJobdesc _mapCountdown(
    Map<String, dynamic> item,
    Map<String, dynamic>? qcItem,
  ) {
    final qcLastStatusFromItem = (qcItem?['qcLastStatus'] as String?)
        ?.toUpperCase();
    final qcLevel = qcItem?['qcLevel'] as String?;
    final kdCheckpointDone =
        qcLastStatusFromItem == 'LOLOS' ||
        qcLastStatusFromItem == 'TIDAK_LOLOS';
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
      targetHoursInitial: ((item['targetHoursInitial'] as num?) ?? 0)
          .toDouble(),
      timeExtensionHours: ((item['timeExtensionHours'] as num?) ?? 0)
          .toDouble(),
      targetHoursRevised: ((item['targetHoursRevised'] as num?) ?? 0)
          .toDouble(),
      totalActualHours: ((item['totalActualHours'] as num?) ?? 0).toDouble(),
      remainingHours: ((item['remainingHours'] as num?) ?? 0).toDouble(),
      startDate:
          (item['startDate'] as String?) ??
          DateTime.now().toIso8601String().split('T').first,
      deadlineDate: (item['deadlineDate'] as String?) ?? '-',
      qcLastStatus: qcLastStatus,
      qcValidationStatus: qcLevel,
      qcResultStatus: qcLastStatusFromItem,
      qcEstimatedReworkHours: null,
      qcReworkDeadlineDate: qcItem?['reworkDate'] as String?,
      qcAdvisorNotes: qcItem?['qcNotes'] as String?,
      revisionRequestStatus: item['extensionRequestStatus'] as String?,
      requestedRevisionHours: (item['extensionRequestedHours'] as num?)
          ?.toDouble(),
      requestedRevisionDeadline: item['extensionRequestedDeadline'] as String?,
      requestedRevisionReason: item['extensionRequestReason'] as String?,
      approvedRevisionHours: (item['extensionApprovedHours'] as num?)
          ?.toDouble(),
      approvedRevisionDeadline: item['extensionApprovedDeadline'] as String?,
      approvedRevisionByName: item['extensionApprovedByName'] as String?,
      rejectedRevisionByName: item['extensionRejectedByName'] as String?,
      isLockedByOtherDivision:
          item['isLockedByOtherDivision'] as bool? ?? false,
      targetHoursRevisedAlias: item['targetHoursRevisedAlias'] as String?,
      remainingHoursAlias: item['remainingHoursAlias'] as String?,
      availablePlanHours:
          ((item['availablePlanHours'] as num?) ?? item['remainingHours'] ?? 0)
              .toDouble(),
      reservedPlanHours: ((item['reservedPlanHours'] as num?) ?? 0).toDouble(),
      availablePlanHoursAlias: item['availablePlanHoursAlias'] as String?,
      reservedPlanHoursAlias: item['reservedPlanHoursAlias'] as String?,
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
        requestedRevisionAt: DateTime.tryParse(
          item['requestedAt']?.toString() ?? '',
        ),
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
      note: notes,
    );
  }
}

int _asInt(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return int.tryParse('$value');
}

double _asDouble(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _asText(Object? value, String fallback) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map<String, dynamic>>().toList();
}
