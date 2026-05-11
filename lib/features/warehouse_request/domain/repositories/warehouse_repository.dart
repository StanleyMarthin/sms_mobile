library;

import '../entities/warehouse_log.dart';
import '../entities/warehouse_item_suggestion.dart';

abstract class WarehouseRepository {
  // ── Queries ────────────────────────────────────────────────
  Future<List<WarehouseLog>> getLogs({
    String? approvalStatus,
    String? itemStatus,
    String? transactionType,
  });

  Future<List<WarehouseLog>> getMyItems();

  Future<List<WarehouseLog>> getPendingApprovals();

  Future<List<Map<String, dynamic>>> getStockCard({String? carId});

  Future<List<Map<String, dynamic>>> getStorageLocations();

  Future<List<WarehouseItemSuggestion>> searchItems({
    required String query,
    String? category,
  });

  // ── Create ─────────────────────────────────────────────────
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
    bool installToUnit = false,
    DateTime? targetSearchDate,
    DateTime? deadlineDate,
    String? notes,
    // Penyimpanan
    String? itemCondition,
    double? qtyReturned,
    List<String>? photoUrls,
    String? sourceTransactionId,
  });

  // ── Update ─────────────────────────────────────────────────
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

  Future<void> remindReturn({required String logId, String? notes});

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

  // ── Photo ──────────────────────────────────────────────────
  Future<String?> uploadPhoto({
    required String userId,
    required String filePath,
    String? logId,
  });
}
