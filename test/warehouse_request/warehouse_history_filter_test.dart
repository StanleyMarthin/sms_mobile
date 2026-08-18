// Tujuan: Memverifikasi filter tanggal untuk daftar riwayat warehouse.
// Caller: Pengembangan dan CI Flutter.
// Dependensi: warehouse_history_filter.dart, WarehouseLog.
// Main Functions: warehouseLogsForDate.
// Side Effects: Tidak ada.

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/warehouse_request/domain/entities/warehouse_log.dart';
import 'package:sm_system/features/warehouse_request/presentation/utils/warehouse_history_filter.dart';

void main() {
  test('returns only logs requested on the selected calendar date', () {
    final logs = [
      _log(id: 'same-day-morning', date: DateTime(2026, 8, 18, 8)),
      _log(id: 'same-day-night', date: DateTime(2026, 8, 18, 23, 59)),
      _log(id: 'previous-day', date: DateTime(2026, 8, 17, 23, 59)),
    ];

    final filtered = warehouseLogsForDate(logs, DateTime(2026, 8, 18));

    expect(filtered.map((log) => log.id), [
      'same-day-morning',
      'same-day-night',
    ]);
  });
}

WarehouseLog _log({required String id, required DateTime date}) => WarehouseLog(
  id: id,
  transactionType: 'PENGAMBILAN',
  itemCategory: 'TOOLS',
  itemName: 'Kunci',
  qty: 1,
  uom: 'PCS',
  requestDate: date,
  itemStatus: 'SELESAI',
  approvalStatus: 'DISETUJUI',
  requester: 'Tester',
  division: 'Mekanik',
);
