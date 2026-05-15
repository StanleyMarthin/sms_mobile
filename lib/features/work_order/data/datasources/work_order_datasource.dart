/*
Tujuan: Datasource remote Work Order untuk list, detail, create, approval, dan extension.
Caller: WorkOrderRepositoryImpl.
Dependensi: ApiClient, ApiEndpoints, SessionManager, JobPlanRepository, WorkOrder entity/helper normalisasi.
Main Functions: getWorkOrders, getWorkOrderById, createWorkOrder, approveWorkOrder, rejectWorkOrder.
Side Effects: HTTP GET/POST ke service WO dan reuse dropdown job plan.
*/
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/work_order.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';

class WorkOrderRemoteDataSource {
  const WorkOrderRemoteDataSource({
    required this.apiClient,
    required this.sessionManager,
    required this.jobPlanRepository,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;
  final JobPlanRepository jobPlanRepository;

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  String? _pickString(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  double? _pickHours(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      final parsed = double.tryParse(text);
      if (parsed != null) return parsed;
    }
    return null;
  }

  // ── LIST ─────────────────────────────────────────────────
  Future<List<WorkOrder>> getWorkOrders({
    String view = 'ACTIVE',
    int page = 1,
    int limit = 30,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.workOrders,
      queryParameters: {
        'userId': _userId,
        'view': view,
        'page': page,
        'limit': limit,
      },
    );
    final rows = (response.data as List<dynamic>?) ?? [];
    return rows.whereType<Map<String, dynamic>>().map(_mapWo).toList();
  }

  // ── DETAIL ───────────────────────────────────────────────
  Future<WorkOrder> getWorkOrderById(String woId) async {
    final response = await apiClient.get(
      ApiEndpoints.workOrderById(woId),
      queryParameters: {'userId': _userId},
    );
    return _mapWo(response.data as Map<String, dynamic>);
  }

  // ── CREATE ───────────────────────────────────────────────
  Future<WorkOrder> createWorkOrder({
    required String carId,
    required String targetDivId,
    required String jobDetail,
    String? notes,
    required String targetDate,
    String? panelName,
    String? sectionName,
    String? panelCategory,
    bool addPanelToMaster = false,
    double? targetHours,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.workOrders,
      data: {
        'action': 'create',
        'userId': _userId,
        'carId': carId,
        'targetDivId': targetDivId,
        'jobDetail': jobDetail,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'targetDate': targetDate,
        if (panelName != null) 'panelName': panelName,
        if (sectionName != null && sectionName.isNotEmpty)
          'sectionName': sectionName,
        if (panelCategory != null) 'panelCategory': panelCategory,
        if (addPanelToMaster) 'addPanelToMaster': true,
        if (targetHours != null) 'targetHours': targetHours,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    final normalizedStage = normalizeWoStage(
      _pickString([data['currentStage'], data['approvalStage'], data['stage']]),
    );
    return WorkOrder(
      id: '${data['reqId'] ?? ''}',
      woNumber: '${data['woNumber'] ?? '-'}',
      carId: carId,
      unitName: '-',
      ownerName: '-',
      toDivId: targetDivId,
      toDivName: '-',
      fromDivId: sessionManager.divisionId?.toString() ?? '',
      fromDivName: sessionManager.divisionName ?? '-',
      panelName: sectionName ?? panelName,
      jobDetail: jobDetail,
      status: normalizeWoStatus(
        _pickString([data['status'], data['woStatus']]),
        currentStage: normalizedStage,
      ),
      currentStage: normalizedStage.startsWith('PENDING_')
          ? normalizedStage
          : 'PENDING_KD_TARGET',
      requestDate: targetDate,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> createWorkOrdersBatch({
    required String carId,
    required String targetDivId,
    required String targetDate,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.workOrders,
      data: {
        'action': 'create',
        'userId': _userId,
        'carId': carId,
        'targetDivId': targetDivId,
        'targetDate': targetDate,
        'items': items,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── APPROVE ──────────────────────────────────────────────
  Future<Map<String, dynamic>> approveWorkOrder({
    required String woId,
    double? estimatedHours,
    String? notes,
    String? picId,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.workOrders,
      data: {
        'action': 'approve',
        'userId': _userId,
        'reqId': woId,
        if (estimatedHours != null) 'estimatedHours': estimatedHours,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (picId != null) 'picId': picId,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── REJECT ───────────────────────────────────────────────
  Future<void> rejectWorkOrder({
    required String woId,
    required String rejectReason,
  }) async {
    await apiClient.post(
      ApiEndpoints.workOrders,
      data: {
        'action': 'reject',
        'userId': _userId,
        'reqId': woId,
        'rejectReason': rejectReason,
      },
    );
  }

  // ── EXTENSIONS ───────────────────────────────────────────
  Future<void> _extensionAction({
    required String action,
    required String woId,
    String? requestedValue,
    String? reason,
  }) async {
    await apiClient.post(
      ApiEndpoints.workOrderExtensions,
      data: {
        'action': action,
        'userId': _userId,
        'reqId': woId,
        if (requestedValue != null) 'requestedValue': requestedValue,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<void> requestDeadlineExtension({
    required String woId,
    required String newDeadline,
    required String reason,
  }) => _extensionAction(
    action: 'request-dl',
    woId: woId,
    requestedValue: newDeadline,
    reason: reason,
  );

  Future<void> respondDeadlineExtension({
    required String woId,
    required bool approve,
    String? note,
  }) => _extensionAction(
    action: approve ? 'approve-dl' : 'reject-dl',
    woId: woId,
    reason: note,
  );

  Future<void> requestHourExtension({
    required String woId,
    required double hours,
    required String reason,
  }) => _extensionAction(
    action: 'request-hours',
    woId: woId,
    requestedValue: hours.toString(),
    reason: reason,
  );

  Future<void> respondHourExtension({
    required String woId,
    required bool approve,
  }) => _extensionAction(
    action: approve ? 'approve-hours' : 'reject-hours',
    woId: woId,
  );

  // ── DROPDOWN — pakai job plan API ─────────────────────────
  Future<Map<String, dynamic>> getDropdowns({
    String? divisionId,
    String? carId,
  }) async {
    return jobPlanRepository.getDropdowns(divisionId: divisionId, carId: carId);
  }

  // ── MAPPER ───────────────────────────────────────────────
  WorkOrder _mapWo(Map<String, dynamic> j) {
    final normalizedStage = normalizeWoStage(
      _pickString([
        j['currentStage'],
        j['approvalStage'],
        j['stage'],
        j['approval_status'],
        j['status'],
      ]),
    );
    final stages =
        (j['stagesDone'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(WoApprovalStage.fromJson)
            .toList() ??
        [];
    final normalizedStatus = normalizeWoStatus(
      _pickString([
        j['status'],
        j['woStatus'],
        j['state'],
        j['approval_status'],
      ]),
      currentStage: normalizedStage,
    );

    return WorkOrder(
      id: _pickString([j['reqId'], j['req_id']]) ?? '',
      woNumber:
          _pickString([
            j['woNumber'],
            j['wo_number'],
            j['reqNumber'],
            j['req_number'],
          ]) ??
          '-',
      carId: _pickString([j['carId'], j['car_id']]) ?? '',
      unitName: _pickString([j['unitName'], j['unit_name']]) ?? '-',
      ownerName:
          _pickString([j['ownerName'], j['owner_name'], j['customer_name']]) ??
          '-',
      toDivId: _pickString([j['toDivId'], j['to_div_id']]) ?? '',
      toDivName: _pickString([j['toDivName'], j['to_div_name']]) ?? '-',
      fromDivId: _pickString([j['fromDivId'], j['from_div_id']]) ?? '',
      fromDivName: _pickString([j['fromDivName'], j['from_div_name']]) ?? '-',
      panelName: _pickString([
        j['panelName'],
        j['sectionName'],
        j['panel_name'],
      ]),
      jobDetail:
          _pickString([
            j['jobDetail'],
            j['job_detail'],
            j['jobOrItemDetail'],
            j['job_or_item_detail'],
            j['detail'],
          ]) ??
          '-',
      estimatedHours: _pickHours([
        j['estimatedHours'],
        j['estimated_hours'],
        j['targetHours'],
        j['workingHours'],
        j['estimatedCostOrHours'],
      ]),
      status: normalizedStatus,
      currentStage: normalizedStage.startsWith('PENDING_')
          ? normalizedStage
          : null,
      needsAdvisor:
          j['needsAdvisor'] == true ||
          j['hasAdvisor'] == true ||
          _pickString([j['advisorId'], j['advisor_id']]) != null,
      stagesDone: stages,
      estimatedByName: _pickString([
        j['estimatedByName'],
        j['estimated_by_name'],
        j['estimatorName'],
      ]),
      requestDate: _pickString([
        j['requestDate'],
        j['createdAt'],
        j['created_at'],
        j['targetDate'],
      ]),
      approvalDate: _pickString([
        j['approvalDate'],
        j['approvedAt'],
        j['approved_at'],
      ]),
      notes: _pickString([
        j['notes'],
        j['advisorNotes'],
        j['kpNotes'],
        j['mpNotes'],
      ]),
      picId: _pickString([
        j['picId'],
        j['assignedUserId'],
        j['assigned_user_id'],
      ]),
      picName: _pickString([
        j['picName'],
        j['assignedUserName'],
        j['assigned_user_name'],
        j['assignedTo'],
      ]),
      accAdvisor:
          j['accAdvisor'] == true ||
          j['accAdvisor'] == 1 ||
          j['accAdvisor'] == '1',
      coreId: _pickString([
        j['coreId'],
        j['core_id'],
        j['countdownId'],
        j['countdown_id'],
      ]),
    );
  }
}
