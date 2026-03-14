library;

import '../../domain/entities/qc_item.dart';
import '../../domain/repositories/qc_repository.dart';
import '../datasources/local_qc_datasource.dart';

class QcRepositoryImpl implements QcRepository {
  const QcRepositoryImpl({required this.dataSource});

  final QcDataSource dataSource;

  @override
  Future<List<QcItem>> getQcItems({
    required String date,
    required String division,
    required bool canValidate,
  }) async {
    final items = await dataSource.getQcItems(
      date: date,
      division: division,
      canValidate: canValidate,
    );
    return items
        .map(_mapItem)
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
    await dataSource.submitQc(
      qcId: qcId,
      passed: passed,
      notes: notes,
      kdRemainingHours: kdRemainingHours,
      estimatedReworkHours: estimatedReworkHours,
      reworkDeadlineDate: reworkDeadlineDate,
      kdCheckpointBy: kdCheckpointBy,
      kdCheckpointAt: kdCheckpointAt,
    );
  }

  @override
  Future<void> validateQc({
    required String qcId,
    required String validatorRole,
    required String validatorName,
    required String validatorAt,
    required String notes,
  }) async {
    await dataSource.validateQc(
      qcId: qcId,
      validatorRole: validatorRole,
      validatorName: validatorName,
      validatorAt: validatorAt,
      notes: notes,
    );
  }

  @override
  Future<QcItem?> findQcItemByCoreId(String coreId) async {
    final item = await dataSource.findQcItemByCoreId(coreId);
    if (item == null) {
      return null;
    }
    return _mapItem(item);
  }

  QcItem _mapItem(Map<String, dynamic> item) {
    final checklist = (item['qcChecklist'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (entry) => QcChecklistItem(
            item: entry['item'] as String,
            passed: entry['passed'] as bool?,
          ),
        )
        .toList();

    return QcItem(
      qcId: item['qcId'] as String,
      coreId: item['coreId'] as String,
      unitName: item['unitName'] as String,
      panelName: item['panelName'] as String,
      jobName: item['jobName'] as String,
      mechanicName: item['mechanicName'] as String,
      mechanicDivision: item['mechanicDivision'] as String,
      totalActualHours: (item['totalActualHours'] as num).toDouble(),
      targetHoursRevised: (item['targetHoursRevised'] as num).toDouble(),
      qcChecklist: checklist,
      validationStatus: item['validationStatus'] as String,
      resultStatus: item['resultStatus'] as String?,
      qcNotes: item['qcNotes'] as String?,
      kdRemainingHours: (item['kdRemainingHours'] as num?)?.toDouble(),
      estimatedReworkHours:
          (item['estimatedReworkHours'] as num?)?.toDouble(),
      reworkDeadlineDate: item['reworkDeadlineDate'] as String?,
      finalRemainingHours: (item['finalRemainingHours'] as num?)?.toDouble(),
      advNotes: item['advNotes'] as String?,
      pmNotes: item['pmNotes'] as String?,
      kdCheckpointBy: item['kdCheckpointBy'] as String?,
      advValidatedBy: item['advValidatedBy'] as String?,
      pmValidatedBy: item['pmValidatedBy'] as String?,
      kdCheckpointAt: item['kdCheckpointAt'] as String?,
      advValidatedAt: item['advValidatedAt'] as String?,
      pmValidatedAt: item['pmValidatedAt'] as String?,
    );
  }
}