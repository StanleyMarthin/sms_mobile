// Tujuan: Menyediakan pemfilteran log warehouse berdasarkan satu tanggal kalender.
// Caller: WarehouseRequestPage dan test unit warehouse request.
// Dependensi: WarehouseLog.
// Main Functions: warehouseLogsForDate.
// Side Effects: Tidak ada.

import '../../domain/entities/warehouse_log.dart';

List<WarehouseLog> warehouseLogsForDate(
  Iterable<WarehouseLog> logs,
  DateTime selectedDate,
) {
  return logs.where((log) {
    final requestDate = log.requestDate;
    return requestDate.year == selectedDate.year &&
        requestDate.month == selectedDate.month &&
        requestDate.day == selectedDate.day;
  }).toList();
}
