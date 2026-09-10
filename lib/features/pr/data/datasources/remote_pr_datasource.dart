/*
Tujuan: Datasource HTTP Purchase Request mobile.
Caller: PR list/detail/form dan Master Panel Tracking create PR.
Dependensi: ApiClient, ApiEndpoints, SessionManager, PRHeader, PRItem.
Main Functions: getPrs(), getPrDetail(), createPr(), approvePr(), rejectPr(), updateItem(), finalizeItem().
Side Effects: HTTP GET/POST ke service sm_pr.
*/

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../models/pr_header.dart';
import '../models/pr_item.dart';

/// Remote datasource for Purchase Request operations.
///
/// Matches BE: sm_pr/app/main.py v2
/// Endpoints:
///   GET  /sm/pr              → list PR (query: accTracking, status, page, limit)
///   GET  /sm/pr/{reqId}      → detail PR + items
///   POST /sm/pr              → all actions via `action` field
class RemotePrDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  RemotePrDataSource({required this.apiClient, required this.sessionManager});

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  // ── List PR ────────────────────────────────────────────────

  /// Fetches paginated PR list with optional filters.
  Future<List<PRHeader>> getPrs({
    String accTracking = 'ALL',
    String status = 'ALL',
    int page = 1,
    int limit = 50,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.pr,
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
          .map(PRHeader.fromJson)
          .toList();
    }
    if (rawData is Map<String, dynamic>) {
      final items = rawData['items'] as List<dynamic>? ?? [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(PRHeader.fromJson)
          .toList();
    }
    return [];
  }

  // ── Detail PR ──────────────────────────────────────────────

  /// Fetches PR detail including all items.
  Future<PRHeader> getPrDetail(String reqId) async {
    final response = await apiClient.get(ApiEndpoints.prDetail(reqId));
    final rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      return PRHeader.fromJson(rawData);
    }
    throw Exception('Format response tidak sesuai.');
  }

  // ── Create PR ──────────────────────────────────────────────

  /// Creates a new Purchase Request with multiple items.
  ///
  /// BE flow: acc_tracking starts at PENDING_ADV, status = null.
  Future<Map<String, dynamic>> createPr({
    required String carId,
    int? masterPanelId,
    String? commandId,
    String? carName,
    String? divisionId,
    String? divisionName,
    String? targetDate,
    String? priority,
    String? notes,
    required List<PRItem> items,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.pr,
      data: {
        'action': 'create',
        'userId': _userId,
        'carId': carId,
        if (commandId != null) 'commandId': commandId,
        if (masterPanelId != null) 'masterPanelId': masterPanelId,
        if (carName != null) 'carName': carName,
        if (divisionId != null) 'divisionId': divisionId,
        if (divisionName != null) 'divisionName': divisionName,
        if (targetDate != null) 'targetDate': targetDate,
        if (priority != null) 'priority': priority,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Approve PR ─────────────────────────────────────────────

  /// Approves a PR — shifts acc_tracking one step forward.
  ///
  /// BE approval chain:
  ///   PENDING_ADV → PENDING_KP (by ADV)
  ///   PENDING_KP  → PENDING_MP (by KP)
  ///   PENDING_MP  → PENDING_PUR (by MP)
  ///   PENDING_PUR → APPROVED / status=OPEN (by Purchase Head)
  Future<Map<String, dynamic>> approvePr(String reqId, {String? notes}) async {
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

  // ── Reject PR ──────────────────────────────────────────────

  /// Rejects a PR — sets status to REJECTED.
  Future<Map<String, dynamic>> rejectPr(String reqId, {String? notes}) async {
    final response = await apiClient.post(
      ApiEndpoints.pr,
      data: {
        'action': 'reject',
        'userId': _userId,
        'reqId': reqId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Update Item ────────────────────────────────────────────

  /// Updates a single PR item's status/data (by purchasing team).
  Future<Map<String, dynamic>> updateItem(String reqId, PRItem item) async {
    final response = await apiClient.post(
      ApiEndpoints.pr,
      data: {
        'action': 'update-item',
        'userId': _userId,
        'reqId': reqId,
        'item': item.toJson(),
      },
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  // ── Finalize Item ──────────────────────────────────────────

  /// Finalizes a single PR item (must be ARRIVED) — routes to jobdesc or warehouse.
  ///
  /// [route] must be `TO_JOBDESC` or `TO_WAREHOUSE`.
  Future<Map<String, dynamic>> finalizeItem({
    required String reqId,
    required String itemId,
    required String route,
    String? divisionId,
    String? itemCategory,
    String? notes,
    String? coreId,
    String? warehousePicId,
    String? targetSearchDate,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.pr,
      data: {
        'action': 'finalize',
        'userId': _userId,
        'reqId': reqId,
        'item': {'itemId': itemId},
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
