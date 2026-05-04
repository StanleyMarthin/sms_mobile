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

  String get _userId => sessionManager.userId ?? sessionManager.employeeId ?? '';

  // ── LIST ─────────────────────────────────────────────────
  Future<List<WorkOrder>> getWorkOrders({String view = 'ACTIVE', int page = 1, int limit = 30}) async {
    final response = await apiClient.get(
      ApiEndpoints.workOrders,
      queryParameters: {'userId': _userId, 'view': view, 'page': page, 'limit': limit},
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
    required String targetDate,
    String? panelName,
    String? sectionName,
    String? panelCategory,
    bool    addPanelToMaster = false,
    double? targetHours,
  }) async {
    final response = await apiClient.post(ApiEndpoints.workOrders, data: {
      'action': 'create',
      'userId': _userId,
      'carId': carId,
      'targetDivId': targetDivId,
      'jobDetail': jobDetail,
      'targetDate': targetDate,
      if (panelName != null) 'panelName': panelName,
      if (sectionName != null && sectionName.isNotEmpty) 'sectionName': sectionName,
      if (panelCategory != null) 'panelCategory': panelCategory,
      if (addPanelToMaster) 'addPanelToMaster': true,
      if (targetHours != null) 'targetHours': targetHours,
    });
    final data = response.data as Map<String, dynamic>? ?? {};
    return WorkOrder(
      id: '${data['reqId'] ?? ''}',
      woNumber: '${data['woNumber'] ?? '-'}',
      carId: carId,
      unitName: '-',
      ownerName: '-',
      toDivId: targetDivId,
      toDivName: '-',
      fromDivId: '${sessionManager.divisionId?.toString() ?? ''}',
      fromDivName: sessionManager.divisionName ?? '-',
      panelName: sectionName ?? panelName,
      jobDetail: jobDetail,
      status: 'OPEN',
      currentStage: data['currentStage']?.toString() ?? 'PENDING_KD_TARGET',
      requestDate: targetDate,
    );
  }

  // ── APPROVE ──────────────────────────────────────────────
  Future<Map<String, dynamic>> approveWorkOrder({
    required String woId,
    double? estimatedHours,
    String? notes,
  }) async {
    final response = await apiClient.post(ApiEndpoints.workOrders, data: {
      'action': 'approve',
      'userId': _userId,
      'reqId': woId,
      if (estimatedHours != null) 'estimatedHours': estimatedHours,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── REJECT ───────────────────────────────────────────────
  Future<void> rejectWorkOrder({required String woId, required String rejectReason}) async {
    await apiClient.post(ApiEndpoints.workOrders, data: {
      'action': 'reject',
      'userId': _userId,
      'reqId': woId,
      'rejectReason': rejectReason,
    });
  }

  // ── EXTENSIONS ───────────────────────────────────────────
  Future<void> _extensionAction({
    required String action,
    required String woId,
    String? requestedValue,
    String? reason,
  }) async {
    await apiClient.post(ApiEndpoints.workOrderExtensions, data: {
      'action': action,
      'userId': _userId,
      'reqId': woId,
      if (requestedValue != null) 'requestedValue': requestedValue,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> requestDeadlineExtension({required String woId, required String newDeadline, required String reason}) =>
      _extensionAction(action: 'request-dl', woId: woId, requestedValue: newDeadline, reason: reason);

  Future<void> respondDeadlineExtension({required String woId, required bool approve, String? note}) =>
      _extensionAction(action: approve ? 'approve-dl' : 'reject-dl', woId: woId, reason: note);

  Future<void> requestHourExtension({required String woId, required double hours, required String reason}) =>
      _extensionAction(action: 'request-hours', woId: woId, requestedValue: hours.toString(), reason: reason);

  Future<void> respondHourExtension({required String woId, required bool approve}) =>
      _extensionAction(action: approve ? 'approve-hours' : 'reject-hours', woId: woId);

  // ── DROPDOWN — pakai job plan API ─────────────────────────
  Future<Map<String, dynamic>> getDropdowns({String? divisionId}) async {
    return jobPlanRepository.getDropdowns(divisionId: divisionId);
  }

  // ── MAPPER ───────────────────────────────────────────────
  WorkOrder _mapWo(Map<String, dynamic> j) {
    final stages = (j['stagesDone'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(WoApprovalStage.fromJson)
            .toList() ??
        [];

    return WorkOrder(
      id: '${j['reqId'] ?? ''}',
      woNumber: '${j['woNumber'] ?? '-'}',
      carId: '${j['carId'] ?? ''}',
      unitName: '${j['unitName'] ?? '-'}',
      ownerName: '${j['ownerName'] ?? '-'}',
      toDivId: '${j['toDivId'] ?? ''}',
      toDivName: '${j['toDivName'] ?? '-'}',
      fromDivId: '${j['fromDivId'] ?? ''}',
      fromDivName: '${j['fromDivName'] ?? '-'}',
      panelName: j['panelName']?.toString(),
      jobDetail: '${j['jobDetail'] ?? j['detail'] ?? '-'}',
      estimatedHours: (j['estimatedHours'] as num?)?.toDouble(),
      status: '${j['status'] ?? 'OPEN'}',
      currentStage: j['currentStage']?.toString(),
      needsAdvisor: j['needsAdvisor'] == true,
      stagesDone: stages,
      estimatedByName: j['estimatedByName']?.toString(),
      requestDate: j['requestDate']?.toString(),
      approvalDate: j['approvalDate']?.toString(),
      notes: j['notes']?.toString(),
      coreId: j['coreId']?.toString(),
    );
  }
}