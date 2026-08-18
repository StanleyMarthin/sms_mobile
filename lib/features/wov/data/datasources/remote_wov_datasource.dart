import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../models/wov_order.dart';

/// Remote datasource for Work Order Vendor (WOV) operations.
///
/// Matches BE: sm_pr/app/main.py v2
/// Endpoints:
///   GET  /sm/wov              → list WOV (query: accTracking, status, page, limit)
///   GET  /sm/wov/{reqId}      → detail WOV
///   POST /sm/wov              → all actions via `action` field
///
/// Note: unitPartEntryId has been removed from the backend schema.
class RemoteWovDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  RemoteWovDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  // ── List WOV ───────────────────────────────────────────────

  /// Fetches paginated WOV list with optional filters.
  Future<List<WOVOrder>> getWovs({
    String accTracking = 'ALL',
    String status = 'ALL',
    int page = 1,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.wov,
      queryParameters: {
        'accTracking': accTracking,
        'status': status,
        'page': page,
        'limit': limit,
      },
    );

    final rawData = response.data;
    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map(WOVOrder.fromJson)
          .toList();
    }
    if (rawData is Map<String, dynamic>) {
      final items = rawData['items'] as List<dynamic>? ?? [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(WOVOrder.fromJson)
          .toList();
    }
    return [];
  }

  // ── Detail WOV ─────────────────────────────────────────────

  /// Fetches WOV detail by ID.
  Future<WOVOrder> getWovDetail(String reqId) async {
    final response = await apiClient.get(ApiEndpoints.wovDetail(reqId));
    final rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      return WOVOrder.fromJson(rawData);
    }
    throw Exception('Format response tidak sesuai.');
  }

  // ── Create WOV ─────────────────────────────────────────────

  /// Creates a new Work Order Vendor.
  ///
  /// BE flow: acc_tracking starts at PENDING_ADV, status = null.
  Future<Map<String, dynamic>> createWov({
    required String carId,
    String? carName,
    String? coreId,
    String? prId,
    String? vendorId,
    required String vendorName,
    String? picVendor,
    String? itemName,
    double? quantity,
    String? uom,
    String? goodsConditionOut,
    String? targetDateReturn,
    double? estimatedCost,
    String? divisionName,
    String? remarks,
    List<Map<String, dynamic>>? items,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'create',
        'userId': _userId,
        'carId': carId,
        if (carName != null) 'carName': carName,
        if (coreId != null) 'coreId': coreId,
        if (prId != null) 'prId': prId,
        if (vendorId != null) 'vendorId': vendorId,
        'vendorName': vendorName,
        if (picVendor != null) 'picVendor': picVendor,
        if (items != null && items.isNotEmpty)
          'items': items
        else ...{
          'itemName': itemName,
          if (quantity != null) 'quantity': quantity,
          if (uom != null) 'uom': uom,
          if (goodsConditionOut != null) 'goodsConditionOut': goodsConditionOut,
          if (estimatedCost != null) 'estimatedCost': estimatedCost,
        },
        if (targetDateReturn != null) 'targetDateReturn': targetDateReturn,
        if (divisionName != null) 'divisionName': divisionName,
        if (remarks != null) 'remarks': remarks,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Approve WOV ────────────────────────────────────────────

  /// Approves a WOV — shifts acc_tracking one step forward.
  ///
  /// BE approval chain:
  ///   PENDING_ADV → PENDING_KP (by ADV)
  ///   PENDING_KP  → PENDING_PM (by KP)
  ///   PENDING_PM  → APPROVED / status=OPEN (by PM/MP)
  Future<Map<String, dynamic>> approveWov(String reqId, {String? notes}) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'approve',
        'userId': _userId,
        'reqId': reqId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Reject WOV ─────────────────────────────────────────────

  /// Rejects a WOV — sets status to REJECTED.
  Future<Map<String, dynamic>> rejectWov(String reqId, {String? notes}) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'reject',
        'userId': _userId,
        'reqId': reqId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Update Status ──────────────────────────────────────────

  /// Updates WOV status lifecycle (only after acc_tracking == APPROVED).
  ///
  /// Valid statuses: OPEN, SENT, PROSES_VENDOR, DONE_VENDOR, RECEIVED, REWORK_VENDOR
  /// Sends only the fields that changed (dynamic update).
  Future<Map<String, dynamic>> updateStatus(
    String reqId,
    String newStatus, {
    String? remarks,
    String? goodsConditionIn,
    double? actualCost,
    String? qcStatus,
    String? dateIn,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'update-status',
        'userId': _userId,
        'reqId': reqId,
        'status': newStatus,
        if (remarks != null) 'remarks': remarks,
        if (goodsConditionIn != null) 'goodsConditionIn': goodsConditionIn,
        if (actualCost != null) 'actualCost': actualCost,
        if (qcStatus != null) 'qcStatus': qcStatus,
        if (dateIn != null) 'dateIn': dateIn,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Finalize WOV ───────────────────────────────────────────

  /// Finalizes a WOV (must be DONE_VENDOR or RECEIVED) — routes to jobdesc or warehouse.
  ///
  /// [route] must be `TO_JOBDESC` or `TO_WAREHOUSE`.
  Future<Map<String, dynamic>> finalizeWov({
    required String reqId,
    required String route,
    int? divisionId,
    String? itemCategory,
    String? notes,
    String? coreId,
    String? warehousePicId,
    String? targetSearchDate,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'finalize',
        'userId': _userId,
        'reqId': reqId,
        'route': route,
        if (divisionId != null) 'divisionId': divisionId,
        if (itemCategory != null) 'itemCategory': itemCategory,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (coreId != null) 'coreId': coreId,
        if (warehousePicId != null) 'warehousePicId': warehousePicId,
        if (targetSearchDate != null) 'targetSearchDate': targetSearchDate,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }
}
