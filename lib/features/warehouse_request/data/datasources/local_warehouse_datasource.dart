library;

import '../../../../core/data/dummy_data.dart';

abstract class WarehouseDataSource {
  Future<List<Map<String, dynamic>>> getLogs();

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

class LocalWarehouseDataSource implements WarehouseDataSource {
  LocalWarehouseDataSource()
      : _logs = DummyWarehouseData.seedLogs();

  final List<Map<String, dynamic>> _logs;

  @override
  Future<List<Map<String, dynamic>>> getLogs() async =>
      _logs.map((item) => Map<String, dynamic>.from(item)).toList();

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
    final needsApproval = itemCategory != 'TOOLS';
    _logs.insert(0, {
      'id': 'wh-${DateTime.now().millisecondsSinceEpoch}',
      'transactionType': transactionType,
      'itemCategory': itemCategory,
      'carId': null,
      'coreId': null,
      'employeeId': employeeId,
      'requester': requester,
      'divisionId': divisionId,
      'division': division,
      'itemName': itemName,
      'qty': qty,
      'uom': 'PCS',
      'requestDate': DateTime.now(),
      'itemStatus': needsApproval ? 'OPEN' : 'RELEASED',
      'approvalStatus': needsApproval ? 'PENDING_KD' : 'APPROVED',
      'notes': notes,
    });
  }

  @override
  Future<void> returnItem({required String logId}) async {
    final log = _findById(logId);
    log['itemStatus'] = 'RETURNED';
    log['returnDate'] = DateTime.now();
  }

  @override
  Future<void> setApprovalStatus({required String logId, required bool approved}) async {
    final log = _findById(logId);
    log['approvalStatus'] = approved ? 'APPROVED' : 'REJECTED';
    log['itemStatus'] = approved ? 'RELEASED' : 'REJECTED';
  }

  Map<String, dynamic> _findById(String logId) {
    return _logs.firstWhere((item) => item['id'] == logId);
  }
}