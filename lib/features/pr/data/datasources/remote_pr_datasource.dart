import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';

/// Remote datasource for Purchase Request operations.
///
/// Matches BE: sm_pr/app/main.py
/// Endpoints:
///   GET  /sm/pr              → list PR
///   POST /sm/pr              → create / approve
///   PUT  /sm/pr/{id}/finalize → finalize (TO_JOBDESC | TO_WAREHOUSE)
class RemotePrDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  const RemotePrDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  // ── List PR ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPrs({
    String status = 'ALL',
    int page = 1,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.pr,
      queryParameters: {
        'status': status,
        'page': page,
        'limit': limit,
      },
    );

    // BE returns flat array inside data
    final rawData = response.data;
    if (rawData is List) {
      return rawData.whereType<Map<String, dynamic>>().toList();
    }
    // Fallback if wrapped in object
    if (rawData is Map<String, dynamic>) {
      final items = rawData['items'] as List<dynamic>? ?? [];
      return items.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // ── Create PR ──────────────────────────────────────────────

  /// Creates a new Purchase Request.
  ///
  /// BE flow: status starts at PENDING_KP.
  Future<Map<String, dynamic>> createPr({
    required String carId,
    String? carName,
    required String itemName,
    required double qty,
    required String uom,
    required String requestType,
    double? estimatedPrice,
    String? divisionId,
    String? divisionName,
    String? notes,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.pr,
      data: {
        'action': 'create',
        'userId': _userId,
        'carId': carId,
        if (carName != null) 'carName': carName,
        'itemName': itemName,
        'qty': qty,
        'uom': uom,
        'requestType': requestType,
        if (estimatedPrice != null) 'estimatedPrice': estimatedPrice,
        if (divisionId != null) 'divisionId': divisionId,
        if (divisionName != null) 'divisionName': divisionName,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Approve PR ─────────────────────────────────────────────

  /// Approves a PR.
  ///
  /// BE approval chain:
  ///   PENDING_KP → PENDING_MP (by KP)
  ///   PENDING_MP → PENDING_PUR (by MP)
  ///   PENDING_PUR → HUNTING (by Purchase Head)
  Future<Map<String, dynamic>> approvePr(
    String reqId, {
    String? notes,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.pr,
      data: {
        'action': 'approve',
        'userId': _userId,
        'reqId': reqId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Finalize PR ────────────────────────────────────────────

  /// Finalizes a PR that is in HUNTING/ORDERED status.
  ///
  /// [route] must be `TO_JOBDESC` or `TO_WAREHOUSE`.
  Future<Map<String, dynamic>> finalizePr({
    required String reqId,
    required String route,
    int? divisionId,
    String? itemCategory,
    String? notes,
    String? coreId,
    String? warehousePicId,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.prFinalize(reqId),
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
