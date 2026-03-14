library;

import '../../domain/entities/warehouse_log.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../datasources/local_warehouse_datasource.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  const WarehouseRepositoryImpl({required this.dataSource});

  final WarehouseDataSource dataSource;

  @override
  Future<List<WarehouseLog>> getLogs() async {
    final logs = await dataSource.getLogs();
    return logs.map(_mapLog).toList();
  }

  @override
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
  }) async {
    await dataSource.createTransaction(
      transactionType: transactionType,
      itemCategory: itemCategory,
      itemName: itemName,
      qty: qty,
      requester: requester,
      division: division,
      divisionId: divisionId,
      employeeId: employeeId,
      notes: notes,
    );
  }

  @override
  Future<void> returnItem({required String logId}) async {
    await dataSource.returnItem(logId: logId);
  }

  @override
  Future<void> setApprovalStatus({required String logId, required bool approved}) async {
    await dataSource.setApprovalStatus(logId: logId, approved: approved);
  }

  WarehouseLog _mapLog(Map<String, dynamic> item) {
    return WarehouseLog(
      id: item['id'] as String,
      transactionType: item['transactionType'] as String,
      itemCategory: item['itemCategory'] as String,
      itemName: item['itemName'] as String,
      qty: item['qty'] as int,
      uom: item['uom'] as String,
      requestDate: item['requestDate'] as DateTime,
      itemStatus: item['itemStatus'] as String,
      approvalStatus: item['approvalStatus'] as String,
      requester: item['requester'] as String,
      division: item['division'] as String,
      notes: item['notes'] as String?,
      returnDate: item['returnDate'] as DateTime?,
    );
  }
}