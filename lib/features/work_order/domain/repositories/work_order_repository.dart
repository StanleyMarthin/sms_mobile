import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_order.dart';

/// Repository contract for Work Order operations.
///
/// Unified for all roles — RBAC controls which actions are available.
abstract class WorkOrderRepository {
  /// Get all work orders (for KD/ADV/PM management view).
  Future<Either<Failure, List<WorkOrder>>> getAllWorkOrders();

  /// Get work orders owned by the current user (for OP view).
  Future<Either<Failure, List<WorkOrder>>> getMyWorkOrders();

  /// Submit a new Work Order (WO or WOV).
  Future<Either<Failure, WorkOrder>> submitWorkOrder(WorkOrder wo);

  /// Update a draft WO before submission.
  Future<Either<Failure, WorkOrder>> updateWorkOrder(WorkOrder wo);

  /// Delete a draft WO (only DRAFT status allowed).
  Future<Either<Failure, void>> deleteWorkOrder(String woId);

  /// Approve a WO (advisor: PENDING_ADVISOR→PENDING_PM, pm: PENDING_PM→APPROVED).
  Future<Either<Failure, WorkOrder>> approveWorkOrder(
      String woId, String approverName);

  /// Reject a WO at any approval step.
  Future<Either<Failure, WorkOrder>> rejectWorkOrder(
      String woId, String rejectedBy, String? reason);

  /// Extend deadline (only requesting KD).
  Future<Either<Failure, WorkOrder>> extendDeadline(
      String woId, String newDeadline, String reason);

    /// Request revision from advisor/pm with new estimate + deadline.
    Future<Either<Failure, WorkOrder>> requestRevision({
        required String woId,
        required double requestedEstimatedHours,
        required String requestedDeadline,
        required String reason,
        required String reviewerName,
    });

    /// Approve/reject requested revision at current stage.
    Future<Either<Failure, WorkOrder>> respondRevision({
        required String woId,
        required bool approve,
        required String reviewerName,
        String? note,
    });

    /// Request deadline extension by KD.
    Future<Either<Failure, WorkOrder>> requestDeadlineExtension({
        required String woId,
        required String newDeadline,
        required String reason,
        required String requesterName,
    });

    /// Approve/reject extension request by advisor/pm.
    Future<Either<Failure, WorkOrder>> respondDeadlineExtension({
        required String woId,
        required bool approve,
        required String reviewerName,
        String? note,
    });
}
