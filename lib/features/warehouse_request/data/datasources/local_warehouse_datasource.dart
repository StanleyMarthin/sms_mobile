library;

import 'warehouse_request_datasource.dart';

/// Dummy datasource — hanya untuk keperluan testing offline.
class LocalWarehouseDataSource implements WarehouseDataSource {
  const LocalWarehouseDataSource();

  @override
  Future<List<Map<String, dynamic>>> getLogs({
    String? approvalStatus,
    String? itemStatus,
    String? transactionType,
  }) async => [
    {
      'id': 'LOCAL-001',
      'transactionType': 'PEMINJAMAN',
      'itemCategory': 'TOOLS',
      'itemName': 'Kunci Torsi',
      'qty': 1,
      'uom': 'PCS',
      'requester': 'Dummy User',
      'division': 'Bengkel',
      'divisionId': 1,
      'employeeId': 'EMP001',
      'requestDate': DateTime.now().toIso8601String(),
      'itemStatus': 'OPEN',
      'approvalStatus': 'APPROVED',
      'notes': null,
      'photoUrls': [],
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getMyItems() async => [];

  @override
  Future<List<Map<String, dynamic>>> getPendingApprovals() async => [];

  @override
  Future<List<Map<String, dynamic>>> getStockCard({String? carId}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getStorageLocations() async => [];

  @override
  Future<List<Map<String, dynamic>>> searchItems({
    required String query,
    String? category,
  }) async => [];

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
    required bool installToUnit,
    DateTime? targetSearchDate,
    DateTime? deadlineDate,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
    List<String>? photoUrls,
    String? sourceTransactionId,
  }) async {}

  @override
  Future<void> setApprovalStatus({
    required String logId,
    required bool approved,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) async {}

  @override
  Future<void> installItem({required String logId, String? notes}) async {}

  @override
  Future<void> markReady({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
    List<String>? photoUrls,
  }) async {}

  @override
  Future<void> releaseItem({required String logId, String? notes}) async {}

  @override
  Future<void> returnItem({
    required String logId,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
  }) async {}

  @override
  Future<void> remindReturn({required String logId, String? notes}) async {}

  @override
  Future<void> storeItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) async {}

  @override
  Future<void> locateItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  }) async {}

  @override
  Future<String?> uploadPhoto({
    required String userId,
    required String filePath,
    String? logId,
  }) async => null;
}
