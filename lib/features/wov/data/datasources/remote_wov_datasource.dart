import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';

/// Remote datasource for Work Order Vendor (WOV) operations.
///
/// Matches BE: sm_pr/app/main.py
/// Endpoints:
///   GET  /sm/wov              → list WOV
///   POST /sm/wov              → create / update-status
///   PUT  /sm/wov/{id}/finalize → finalize (TO_JOBDESC | TO_WAREHOUSE)
class RemoteWovDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  const RemoteWovDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  // ── List WOV ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWovs({
    String status = 'ALL',
    int page = 1,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.wov,
      queryParameters: {
        'status': status,
        'page': page,
        'limit': limit,
      },
    );

    final rawData = response.data;
    if (rawData is List) {
      return rawData.whereType<Map<String, dynamic>>().toList();
    }
    if (rawData is Map<String, dynamic>) {
      final items = rawData['items'] as List<dynamic>? ?? [];
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // ── Create WOV ─────────────────────────────────────────────

  /// Creates a new Work Order Vendor.
  ///
  /// BE flow: status starts at OPEN.
  Future<Map<String, dynamic>> createWov({
    required String carId,
    String? carName,
    String? coreId,
    String? unitPartEntryId,
    String? prId,
    String? vendorId,
    required String vendorName,
    String? picVendor,
    required String itemName,
    int? quantity,
    String? uom,
    String? goodsConditionOut,
    String? targetDateReturn,
    String? remarks,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'create',
        'userId': _userId,
        'carId': carId,
        if (carName != null) 'carName': carName,
        if (coreId != null) 'coreId': coreId,
        if (unitPartEntryId != null) 'unitPartEntryId': unitPartEntryId,
        if (prId != null) 'prId': prId,
        if (vendorId != null) 'vendorId': vendorId,
        'vendorName': vendorName,
        if (picVendor != null) 'picVendor': picVendor,
        'itemName': itemName,
        if (quantity != null) 'quantity': quantity,
        if (uom != null) 'uom': uom,
        if (goodsConditionOut != null) 'goodsConditionOut': goodsConditionOut,
        if (targetDateReturn != null) 'targetDateReturn': targetDateReturn,
        if (remarks != null) 'remarks': remarks,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Update Status ──────────────────────────────────────────

  /// Updates WOV status.
  ///
  /// Valid statuses: OPEN, SENT, PROSES_VENDOR, DONE_VENDOR, RECEIVED, REWORK_VENDOR
  Future<Map<String, dynamic>> updateStatus(
    String reqId,
    String newStatus, {
    String? remarks,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.wov,
      data: {
        'action': 'update-status',
        'userId': _userId,
        'reqId': reqId,
        'status': newStatus,
        if (remarks != null) 'remarks': remarks,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Finalize WOV ───────────────────────────────────────────

  /// Finalizes a WOV that is in DONE_VENDOR/PROSES_VENDOR/SENT status.
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
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.wovFinalize(reqId),
      data: {
        'userId': _userId,
        'route': route,
        if (divisionId != null) 'divisionId': divisionId,
        if (itemCategory != null) 'itemCategory': itemCategory,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (coreId != null) 'coreId': coreId,
        if (warehousePicId != null) 'warehousePicId': warehousePicId,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }
}
