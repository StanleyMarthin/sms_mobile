library;

import '../entities/warehouse_log.dart';

abstract class WarehouseRepository {
  Future<List<WarehouseLog>> getLogs();

  Future<void> createTransaction({
    required String transactionType,
    required String itemCategory,
    required String itemName,
    required int qty,
    required String requester,
    required String division,
    required int divisionId,
    required String employeeId,
    required String notes,
  });

  Future<void> returnItem({required String logId});

  Future<void> setApprovalStatus({required String logId, required bool approved});
}