library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import 'warehouse_request_datasource.dart';

class RemoteWarehouseDataSource implements WarehouseDataSource {
  const RemoteWarehouseDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  // ── getLogs ─────────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getLogs({
    String? approvalStatus,
    String? itemStatus,
    String? transactionType,
  }) async {
    final uid = _userId;
    if (uid.isEmpty) return [];
    final q = <String, dynamic>{'userId': uid, 'limit': 100, 'offset': 0};
    if (approvalStatus != null && approvalStatus != 'ALL') {
      q['approvalStatus'] = approvalStatus;
    }
    if (itemStatus != null) q['itemStatus'] = itemStatus;
    if (transactionType != null) q['transactionType'] = transactionType;

    final res = await apiClient.get(
      ApiEndpoints.warehouseLogs,
      queryParameters: q,
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    return _listOf(data['logs']);
  }

  // ── getMyItems ──────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getMyItems() async {
    final uid = _userId;
    if (uid.isEmpty) return [];
    final res = await apiClient.get(
      ApiEndpoints.warehouseMyItems,
      queryParameters: {'userId': uid},
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    return _listOf(data['items']);
  }

  // ── getPendingApprovals ────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    final uid = _userId;
    if (uid.isEmpty) return [];
    final res = await apiClient.get(
      ApiEndpoints.warehousePendingApproval,
      queryParameters: {'userId': uid},
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    return _listOf(data['items']);
  }

  // ── getStockCard ────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getStockCard({String? carId}) async {
    final uid = _userId;
    final q = <String, dynamic>{'userId': uid};
    if (carId != null) q['carId'] = carId;
    final res = await apiClient.get(
      ApiEndpoints.warehouseStockCard,
      queryParameters: q,
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    return _listOf(data['items']);
  }

  // ── getStorageLocations ─────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getStorageLocations() async {
    final res = await apiClient.get(ApiEndpoints.warehouseStorageLocations);
    final data = (res.data as Map<String, dynamic>?) ?? {};
    return _listOf(data['items']);
  }

  // ── searchItems ────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> searchItems({
    required String query,
    String? category,
  }) async {
    final uid = _userId;
    if (uid.isEmpty || query.trim().isEmpty) return [];
    final res = await apiClient.get(
      ApiEndpoints.warehouseItemsSearch,
      queryParameters: {
        'userId': uid,
        'q': query.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final data = (res.data as Map<String, dynamic>?) ?? {};
    return _listOf(data['items']);
  }

  // ── createTransaction ───────────────────────────────────────
  @override
  Future<void> createTransaction({
    required String transactionType,
    required String itemCategory,
    required String itemName,
    required double qty,
    required String uom,
    required String requester,
    required String division,
    required int divisionId,
    required String employeeId,
    String? carId,
    String? coreId,
    String? unitName,
    String? panelName,
    String? jobdesc,
    String? stockCardId,
    String? itemMasterId,
    required bool installToUnit,
    DateTime? targetSearchDate,
    DateTime? deadlineDate,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
    List<String>? photoUrls,
    String? sourceTransactionId,
  }) async {
    final body = <String, dynamic>{
      'action': 'create',
      'userId': _userId,
      'transactionType': transactionType,
      'itemCategory': itemCategory,
      'itemName': itemName,
      'qty': qty,
      'uom': uom,
      'requester': requester,
      'division': division,
      'divisionId': divisionId,
      'employeeId': employeeId,
      'installToUnit': installToUnit,
      if (carId != null) 'carId': carId,
      if (coreId != null) 'coreId': coreId,
      if (unitName != null) 'unitName': unitName,
      if (panelName != null) 'panelName': panelName,
      if (jobdesc != null) 'jobdesc': jobdesc,
      if (stockCardId != null) 'stockCardId': stockCardId,
      if (itemMasterId != null) 'itemMasterId': itemMasterId,
      if (targetSearchDate != null)
        'targetSearchDate': targetSearchDate.toIso8601String().substring(0, 10),
      if (deadlineDate != null)
        'deadlineDate': deadlineDate.toIso8601String().substring(0, 10),
      if (notes != null) 'notes': notes,
      if (itemCondition != null) 'itemCondition': itemCondition,
      if (qtyReturned != null) 'qtyReturned': qtyReturned,
      if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      if (sourceTransactionId != null)
        'sourceTransactionId': sourceTransactionId,
    };
    await apiClient.post(ApiEndpoints.warehouse, data: body);
  }

  // ── setApprovalStatus ───────────────────────────────────────
  @override
  Future<void> setApprovalStatus({
    required String logId,
    required bool approved,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': approved ? 'approve' : 'reject',
        'userId': _userId,
        'logId': logId,
        'approved': approved,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (storageLocationId != null) 'storageLocationId': storageLocationId,
        if (locationDetail != null && locationDetail.isNotEmpty)
          'locationDetail': locationDetail,
      },
    );
  }

  // ── installItem ─────────────────────────────────────────────
  @override
  Future<void> installItem({required String logId, String? notes}) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'install',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  @override
  Future<void> markReady({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
    List<String>? photoUrls,
  }) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'ready',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (storageLocationId != null) 'storageLocationId': storageLocationId,
        if (locationDetail != null && locationDetail.isNotEmpty)
          'locationDetail': locationDetail,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      },
    );
  }

  @override
  Future<void> releaseItem({required String logId, String? notes}) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'release',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  // ── returnItem ──────────────────────────────────────────────
  @override
  Future<void> returnItem({
    required String logId,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
  }) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'return',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (itemCondition != null) 'itemCondition': itemCondition,
        if (qtyReturned != null) 'qtyReturned': qtyReturned,
      },
    );
  }

  @override
  Future<void> remindReturn({required String logId, String? notes}) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'remind_return',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  @override
  Future<void> storeItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'store',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (storageLocationId != null) 'storageLocationId': storageLocationId,
        if (locationDetail != null && locationDetail.isNotEmpty)
          'locationDetail': locationDetail,
      },
    );
  }

  @override
  Future<void> locateItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) async {
    await apiClient.put(
      ApiEndpoints.warehouse,
      data: {
        'action': 'locate',
        'userId': _userId,
        'logId': logId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (storageLocationId != null) 'storageLocationId': storageLocationId,
        if (locationDetail != null && locationDetail.isNotEmpty)
          'locationDetail': locationDetail,
      },
    );
  }

  @override
  Future<void> matchItem({
    required String logId,
    required String masterId,
    required String masterName,
  }) async {
    await apiClient.put(
      ApiEndpoints.warehouseMatchItem,
      data: {
        'userId': _userId,
        'logId': logId,
        'masterId': masterId,
        'masterName': masterName,
      },
    );
  }

  // ── uploadPhoto ─────────────────────────────────────────────
  @override
  Future<String?> uploadPhoto({
    required String userId,
    required String filePath,
    String? logId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final ext = filePath.split('.').last;
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'warehouse/${logId ?? "general"}/photo_$uniqueId.$ext';

      // 1. Get ticket
      final ticketRes = await apiClient.get(
        ApiEndpoints.warehouseUploadTicket,
        queryParameters: {'filename': fileName},
      );
      final ticketRaw = (ticketRes.data as Map<String, dynamic>?) ?? {};
      final dataTick = ticketRaw['data'] is Map
          ? ticketRaw['data'] as Map<String, dynamic>
          : ticketRaw;

      final uploadUrl = dataTick['upload_url']?.toString() ?? '';
      final publicUrl = dataTick['public_url']?.toString() ?? '';

      if (uploadUrl.isEmpty) {
        if (kDebugMode) {
          debugPrint('[Warehouse] Upload URL kosong');
        }
        return null;
      }

      // 2. Upload via http.StreamedRequest
      final length = file.lengthSync();
      final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
      request.headers['Content-Type'] = 'image/jpeg';
      request.headers['Content-Length'] = length.toString();

      // stream upload
      file.openRead().listen(
        (data) => request.sink.add(data),
        onDone: () => request.sink.close(),
        onError: (e) => request.sink.addError(e),
        cancelOnError: true,
      );

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Jika logId diteruskan, kita perlu append url foto manual ke transaksi
        // tapi implementasi backend saat multipart dulu yang simpan.
        // Sekarang simpan urlnya ditangani requester atau butuh extra call.
        // Wait, ini hanya retun url, jadi kita biarkan UI/bloc yang attach.
        return publicUrl;
      }

      if (kDebugMode) {
        debugPrint('[Warehouse] HTTP ${response.statusCode} saat upload S3');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Warehouse] upload photo gagal: $e');
      }
      return null;
    }
  }

  // ── helper ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _listOf(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
