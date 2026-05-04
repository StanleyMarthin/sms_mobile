library;

abstract class WarehouseDataSource {
  Future<List<Map<String, dynamic>>> getLogs({
    String? approvalStatus,
    String? itemStatus,
    String? transactionType,
  });

  Future<List<Map<String, dynamic>>> getMyItems();

  Future<List<Map<String, dynamic>>> getPendingApprovals();

  Future<List<Map<String, dynamic>>> getStockCard({String? carId});

  Future<List<Map<String, dynamic>>> getStorageLocations();

  Future<List<Map<String, dynamic>>> searchItems({
    required String query,
    String? category,
  });

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
  });

  Future<void> setApprovalStatus({
    required String logId,
    required bool approved,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  });

  Future<void> installItem({required String logId, String? notes});

  Future<void> markReady({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
    List<String>? photoUrls,
  });

  Future<void> releaseItem({required String logId, String? notes});

  Future<void> returnItem({
    required String logId,
    String? notes,
    String? itemCondition,
    double? qtyReturned,
  });

  Future<void> storeItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  });

  Future<void> locateItem({
    required String logId,
    String? notes,
    int? storageLocationId,
    String? locationDetail,
  });

  Future<String?> uploadPhoto({
    required String userId,
    required String filePath,
    String? logId,
  });
}
