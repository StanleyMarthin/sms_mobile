library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';

abstract class QcDataSource {
  Future<List<Map<String, dynamic>>> getQcItems({
    required String date,
    required String division,
    required bool canValidate,
  });

  Future<void> submitQc({
    required String qcId,
    required bool passed,
    required String notes,
    required double kdRemainingHours,
    required double estimatedReworkHours,
    required String? reworkDeadlineDate,
    required String kdCheckpointBy,
    required String kdCheckpointAt,
  });

  Future<void> validateQc({
    required String qcId,
    required String validatorRole,
    required String validatorName,
    required String validatorAt,
    required String notes,
  });

  Future<Map<String, dynamic>?> findQcItemByCoreId(String coreId);
}

class LocalQcDataSource implements QcDataSource {
  LocalQcDataSource({required this.store});

  final LocalMockApiStore store;

  @override
  Future<List<Map<String, dynamic>>> getQcItems({
    required String date,
    required String division,
    required bool canValidate,
  }) async {
    final items = await _loadItems();
    return items
        .where((item) => item['date'] == date)
        .where((item) => canValidate || item['mechanicDivision'] == division)
        .map(_copyItem)
        .toList();
  }

  @override
  Future<void> submitQc({
    required String qcId,
    required bool passed,
    required String notes,
    required double kdRemainingHours,
    required double estimatedReworkHours,
    required String? reworkDeadlineDate,
    required String kdCheckpointBy,
    required String kdCheckpointAt,
  }) async {
    final items = await _loadItems();
    final item = _findById(items, qcId);
    item['resultStatus'] = passed ? 'LOLOS' : 'TIDAK_LOLOS';
    item['validationStatus'] = 'KD_DONE';
    item['kdRemainingHours'] = kdRemainingHours;
    item['estimatedReworkHours'] = estimatedReworkHours;
    item['reworkDeadlineDate'] = reworkDeadlineDate;
    item['finalRemainingHours'] = kdRemainingHours;
    item['advNotes'] = null;
    item['pmNotes'] = null;
    item['qcNotes'] = notes;
    item['kdCheckpointBy'] = kdCheckpointBy;
    item['kdCheckpointAt'] = kdCheckpointAt;
    item['advValidatedBy'] = null;
    item['advValidatedAt'] = null;
    item['pmValidatedBy'] = null;
    item['pmValidatedAt'] = null;
    item['qcStatus'] = passed ? 'KD_PASS' : 'KD_FAIL';
    await _saveItems(items);
  }

  @override
  Future<void> validateQc({
    required String qcId,
    required String validatorRole,
    required String validatorName,
    required String validatorAt,
    required String notes,
  }) async {
    final items = await _loadItems();
    final item = _findById(items, qcId);
    if (item['kdCheckpointBy'] == null) {
      return;
    }
    if (validatorRole == 'adv') {
      item['validationStatus'] = 'KD_DONE';
      item['advValidatedBy'] = validatorName;
      item['advValidatedAt'] = validatorAt;
      item['advNotes'] = notes;
      item['qcStatus'] = item['pmValidatedBy'] == null ? 'KD_ADV_DONE' : 'KD_ADV_PM_DONE';
      await _saveItems(items);
      return;
    }

    item['validationStatus'] = 'KD_DONE';
    item['finalRemainingHours'] = item['kdRemainingHours'];
    item['pmValidatedBy'] = validatorName;
    item['pmValidatedAt'] = validatorAt;
    item['pmNotes'] = notes;
    item['qcStatus'] = item['advValidatedBy'] == null ? 'KD_PM_DONE' : 'KD_ADV_PM_DONE';
    await _saveItems(items);
  }

  @override
  Future<Map<String, dynamic>?> findQcItemByCoreId(String coreId) async {
    final items = await _loadItems();
    for (final item in items) {
      if (item['coreId'] == coreId) {
        return _copyItem(item);
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    var items = await store.readList(
      key: LocalMockApiStore.qcItemsKey,
      seedBuilder: QcDummyData.seedAll,
    );
    if (items.isEmpty) {
      final seeded = QcDummyData.seedAll();
      if (seeded.isNotEmpty) {
        await _saveItems(seeded);
        items = seeded;
      }
    }
    return items.map(_normalize).toList();
  }

  Future<void> _saveItems(List<Map<String, dynamic>> items) {
    return store.writeList(
      key: LocalMockApiStore.qcItemsKey,
      value: items,
    );
  }

  Map<String, dynamic> _findById(List<Map<String, dynamic>> items, String qcId) {
    return items.firstWhere((item) => item['qcId'] == qcId);
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> source) {
    final item = _copyItem(source);
    final qcStatus = item['qcStatus'] as String? ?? 'PENDING';
    if (qcStatus == 'APPROVED') {
      item['resultStatus'] = 'LOLOS';
      item['validationStatus'] = 'KD_DONE';
      item['kdRemainingHours'] = 0.0;
      item['estimatedReworkHours'] = 0.0;
      item['reworkDeadlineDate'] = null;
      item['finalRemainingHours'] = 0.0;
      item['advNotes'] = item['advNotes'] ?? 'Checkpoint ADV tervalidasi';
      item['pmNotes'] = item['pmNotes'] ?? 'Checkpoint PM selesai';
      item['kdCheckpointBy'] = item['kdCheckpointBy'] ?? 'KD';
      item['advValidatedBy'] = item['advValidatedBy'] ?? 'ADV';
      item['pmValidatedBy'] = item['pmValidatedBy'] ?? 'PM';
    } else if (qcStatus == 'REWORK') {
      item['resultStatus'] = 'TIDAK_LOLOS';
      item['validationStatus'] = 'KD_DONE';
      item['kdRemainingHours'] = 2.0;
      item['estimatedReworkHours'] = 2.0;
      item['reworkDeadlineDate'] = item['reworkDeadlineDate'] ?? '2026-02-24';
      item['finalRemainingHours'] = 3.0;
      item['advNotes'] = item['advNotes'] ?? 'Checkpoint ADV reject tervalidasi';
      item['pmNotes'] = item['pmNotes'] ?? 'Lanjutkan rework sesuai jadwal';
      item['kdCheckpointBy'] = item['kdCheckpointBy'] ?? 'KD';
      item['advValidatedBy'] = item['advValidatedBy'] ?? 'ADV';
      item['pmValidatedBy'] = item['pmValidatedBy'] ?? 'PM';
    } else if (qcStatus == 'VALIDATED_ADV') {
      item['validationStatus'] = 'KD_DONE';
      item['resultStatus'] = item['resultStatus'] ?? 'LOLOS';
      item['kdCheckpointBy'] = item['kdCheckpointBy'] ?? 'KD';
      item['kdCheckpointAt'] = item['kdCheckpointAt'] ?? item['inspectionDate'];
      item['advValidatedBy'] = item['advValidatedBy'] ?? 'ADV';
      item['advValidatedAt'] = item['advValidatedAt'] ?? item['inspectionDate'];
      item['advNotes'] = item['advNotes'] ?? 'QC ADV sudah dilakukan';
      item['pmValidatedBy'] = item['pmValidatedBy'];
      item['pmValidatedAt'] = item['pmValidatedAt'];
    } else if (qcStatus == 'KD_PASS' || qcStatus == 'SUBMITTED_PASS') {
      item['validationStatus'] = 'KD_DONE';
      item['resultStatus'] = 'LOLOS';
      item['finalRemainingHours'] = item['kdRemainingHours'] ?? 0.0;
    } else if (qcStatus == 'KD_FAIL' || qcStatus == 'SUBMITTED_FAIL') {
      item['validationStatus'] = 'KD_DONE';
      item['resultStatus'] = 'TIDAK_LOLOS';
      item['finalRemainingHours'] = item['kdRemainingHours'];
    } else if (qcStatus == 'KD_ADV_DONE') {
      item['validationStatus'] = 'KD_DONE';
      item['resultStatus'] = item['resultStatus'] ?? 'LOLOS';
      item['advValidatedBy'] = item['advValidatedBy'] ?? 'ADV';
      item['advValidatedAt'] = item['advValidatedAt'] ?? item['inspectionDate'];
    } else if (qcStatus == 'KD_PM_DONE') {
      item['validationStatus'] = 'KD_DONE';
      item['resultStatus'] = item['resultStatus'] ?? 'LOLOS';
      item['pmValidatedBy'] = item['pmValidatedBy'] ?? 'PM';
      item['pmValidatedAt'] = item['pmValidatedAt'] ?? item['inspectionDate'];
    } else if (qcStatus == 'KD_ADV_PM_DONE') {
      item['validationStatus'] = 'KD_DONE';
      item['resultStatus'] = item['resultStatus'] ?? 'LOLOS';
      item['advValidatedBy'] = item['advValidatedBy'] ?? 'ADV';
      item['advValidatedAt'] = item['advValidatedAt'] ?? item['inspectionDate'];
      item['pmValidatedBy'] = item['pmValidatedBy'] ?? 'PM';
      item['pmValidatedAt'] = item['pmValidatedAt'] ?? item['inspectionDate'];
    } else {
      item['resultStatus'] = null;
      item['validationStatus'] = 'WAITING_KD';
      item['kdRemainingHours'] = null;
      item['estimatedReworkHours'] = null;
      item['reworkDeadlineDate'] = null;
      item['finalRemainingHours'] = null;
      item['advNotes'] = null;
      item['pmNotes'] = null;
      item['kdCheckpointBy'] = null;
      item['advValidatedBy'] = null;
      item['pmValidatedBy'] = null;
      item['kdCheckpointAt'] = null;
      item['advValidatedAt'] = null;
      item['pmValidatedAt'] = null;
    }
    return item;
  }

  static Map<String, dynamic> _copyItem(Map<String, dynamic> item) {
    final copy = Map<String, dynamic>.from(item);
    final checklist = item['qcChecklist'];
    if (checklist is List) {
      copy['qcChecklist'] = checklist
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    }
    return copy;
  }
}