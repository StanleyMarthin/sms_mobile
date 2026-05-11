library;

import '../../domain/entities/warehouse_log.dart';
import '../../domain/entities/warehouse_item_suggestion.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../datasources/warehouse_request_datasource.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  const WarehouseRepositoryImpl({required this.dataSource});
  final WarehouseDataSource dataSource;

  // ── getLogs ─────────────────────────────────────────────────
  @override
  Future<List<WarehouseLog>> getLogs({
    String? approvalStatus,
    String? itemStatus,
    String? transactionType,
  }) async {
    final rows = await dataSource.getLogs(
      approvalStatus: approvalStatus,
      itemStatus: itemStatus,
      transactionType: transactionType,
    );
    return rows.map(_mapLog).toList();
  }

  // ── getMyItems ──────────────────────────────────────────────
  @override
  Future<List<WarehouseLog>> getMyItems() async {
    final rows = await dataSource.getMyItems();
    return rows.map(_mapLog).toList();
  }

  // ── getPendingApprovals ────────────────────────────────────
  @override
  Future<List<WarehouseLog>> getPendingApprovals() async {
    final rows = await dataSource.getPendingApprovals();
    return rows.map(_mapLog).toList();
  }

  // ── getStockCard ────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getStockCard({String? carId}) =>
      dataSource.getStockCard(carId: carId);

  // ── getStorageLocations ─────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getStorageLocations() =>
      dataSource.getStorageLocations();

  @override
  Future<List<WarehouseItemSuggestion>> searchItems({
    required String query,
    String? category,
  }) async {
    final rows = await dataSource.searchItems(query: query, category: category);
    return rows.map(_mapSuggestion).toList();
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
    bool installToUnit = false,
    DateTime? targetSearchDate,
    DateTime? deadlineDate,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
    List<String>? photoUrls,
    String? sourceTransactionId,
  }) => dataSource.createTransaction(
    transactionType: transactionType,
    itemCategory: itemCategory,
    itemName: itemName,
    qty: qty,
    uom: uom,
    requester: requester,
    division: division,
    divisionId: divisionId,
    employeeId: employeeId,
    carId: carId,
    coreId: coreId,
    unitName: unitName,
    panelName: panelName,
    jobdesc: jobdesc,
    stockCardId: stockCardId,
    itemMasterId: itemMasterId,
    installToUnit: installToUnit,
    targetSearchDate: targetSearchDate,
    deadlineDate: deadlineDate,
    notes: notes,
    itemCondition: itemCondition,
    qtyReturned: qtyReturned,
    photoUrls: photoUrls,
    sourceTransactionId: sourceTransactionId,
  );

  // ── setApprovalStatus ───────────────────────────────────────
  @override
  Future<void> setApprovalStatus({
    required String logId,
    required bool approved,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) => dataSource.setApprovalStatus(
    logId: logId,
    approved: approved,
    notes: notes,
    storageLocationId: storageLocationId,
    locationDetail: locationDetail,
  );

  // ── installItem ─────────────────────────────────────────────
  @override
  Future<void> installItem({required String logId, String? notes}) =>
      dataSource.installItem(logId: logId, notes: notes);

  @override
  Future<void> markReady({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
    List<String>? photoUrls,
  }) => dataSource.markReady(
    logId: logId,
    notes: notes,
    storageLocationId: storageLocationId,
    locationDetail: locationDetail,
    photoUrls: photoUrls,
  );

  @override
  Future<void> releaseItem({required String logId, String? notes}) =>
      dataSource.releaseItem(logId: logId, notes: notes);

  // ── returnItem ──────────────────────────────────────────────
  @override
  Future<void> returnItem({
    required String logId,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
  }) => dataSource.returnItem(
    logId: logId,
    notes: notes,
    itemCondition: itemCondition,
    qtyReturned: qtyReturned,
  );

  @override
  Future<void> remindReturn({required String logId, String? notes}) =>
      dataSource.remindReturn(logId: logId, notes: notes);

  @override
  Future<void> storeItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) => dataSource.storeItem(
    logId: logId,
    notes: notes,
    storageLocationId: storageLocationId,
    locationDetail: locationDetail,
  );

  @override
  Future<void> locateItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) => dataSource.locateItem(
    logId: logId,
    notes: notes,
    storageLocationId: storageLocationId,
    locationDetail: locationDetail,
  );

  // ── uploadPhoto ─────────────────────────────────────────────
  @override
  Future<String?> uploadPhoto({
    required String userId,
    required String filePath,
    String? logId,
  }) =>
      dataSource.uploadPhoto(userId: userId, filePath: filePath, logId: logId);

  // ── mapper ──────────────────────────────────────────────────
  WarehouseLog _mapLog(Map<String, dynamic> m) {
    final qty = (m['qty'] as num?)?.toDouble() ?? 0;
    return WarehouseLog(
      id: '${m['id'] ?? ''}',
      transactionType: '${m['transactionType'] ?? ''}',
      itemCategory: '${m['itemCategory'] ?? ''}',
      itemName: '${m['itemName'] ?? ''}',
      qty: qty,
      uom: '${m['uom'] ?? 'PCS'}',
      requestDate: _parseDate(m['requestDate']) ?? DateTime.now(),
      itemStatus: '${m['itemStatus'] ?? ''}',
      approvalStatus: '${m['approvalStatus'] ?? ''}',
      requester: '${m['requester'] ?? ''}',
      division: '${m['division'] ?? ''}',
      employeeId: m['employeeId'] as String?,
      divisionId: (m['divisionId'] as num?)?.toInt(),
      itemMasterId: m['itemMasterId'] as String?,
      itemAliasUsed: m['itemAliasUsed'] as String?,
      carId: m['carId'] as String?,
      coreId: m['coreId'] as String?,
      unitName: m['unitName'] as String?,
      panelName: m['panelName'] as String?,
      jobdesc: m['jobdesc'] as String?,
      stockCardId: m['stockCardId'] as String?,
      itemCondition: m['itemCondition'] as String?,
      qtyReturned: (m['qtyReturned'] as num?)?.toDouble(),
      storageLocationId: (m['storageLocationId'] as num?)?.toInt(),
      locationDetail: m['locationDetail'] as String?,
      picWarehouseName: m['picWarehouseName'] as String?,
      accKdName: m['accKdName'] as String?,
      targetSearchDate: _parseDate(m['targetSearchDate']),
      actualReleaseDate: _parseDate(m['actualReleaseDate']),
      deadlineDate: _parseDate(m['deadlineDate']),
      actualReturnDate: _parseDate(m['actualReturnDate']),
      photoUrls: _parsePhotoUrls(m['photoUrls']),
      notes: m['notes'] as String?,
      approvalHistory: _parseApprovalHistory(m['approvalHistory']),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  List<String>? _parsePhotoUrls(dynamic v) {
    if (v == null) return null;
    if (v is List) return v.map((e) => '$e').toList();
    return null;
  }

  List<WarehouseApprovalStep> _parseApprovalHistory(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return WarehouseApprovalStep(
        stage: '${item['stage'] ?? ''}',
        action: '${item['action'] ?? ''}',
        userId: item['userId'] as String?,
        name: item['name'] as String?,
        notes: item['notes'] as String?,
        timestamp: _parseDate(item['timestamp']),
      );
    }).toList();
  }

  WarehouseItemSuggestion _mapSuggestion(Map<String, dynamic> m) {
    return WarehouseItemSuggestion(
      id: '${m['id'] ?? ''}',
      itemName: '${m['itemName'] ?? ''}',
      itemCode: '${m['itemCode'] ?? ''}',
      itemCategory: '${m['itemCategory'] ?? ''}',
      uom: '${m['uom'] ?? 'PCS'}',
      matchedAlias: m['matchedAlias'] as String?,
      photoUrls: _parsePhotoUrls(m['photoUrls']) ?? const [],
      lastLocation: m['lastLocation'] as String?,
      stockQty: (m['stockQty'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> matchItem({
    required String logId,
    required String masterId,
    required String masterName,
  }) => dataSource.matchItem(
    logId: logId,
    masterId: masterId,
    masterName: masterName,
  );
}
