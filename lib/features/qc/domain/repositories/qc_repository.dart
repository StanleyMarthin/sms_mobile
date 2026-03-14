library;

import '../entities/qc_item.dart';

abstract class QcRepository {
  Future<List<QcItem>> getQcItems({
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

  Future<QcItem?> findQcItemByCoreId(String coreId);
}