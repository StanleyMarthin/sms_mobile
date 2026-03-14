library;

import '../../domain/entities/work_order.dart';

abstract class WorkOrderDataSource {
  Future<List<WorkOrder>> getAllWorkOrders();
  Future<WorkOrder> submitWorkOrder(WorkOrder wo);
  Future<WorkOrder> updateWorkOrder(WorkOrder wo);
  Future<void> deleteWorkOrder(String woId);
  Future<WorkOrder> approveWorkOrder(String woId, String approverName);
  Future<WorkOrder> rejectWorkOrder(String woId, String rejectedBy, String? reason);
  Future<WorkOrder> extendDeadline(String woId, String newDeadline, String reason);
  Future<WorkOrder> requestRevision({
    required String woId,
    required double requestedEstimatedHours,
    required String requestedDeadline,
    required String reason,
    required String reviewerName,
  });
  Future<WorkOrder> respondRevision({
    required String woId,
    required bool approve,
    required String reviewerName,
    String? note,
  });
  Future<WorkOrder> requestDeadlineExtension({
    required String woId,
    required String newDeadline,
    required String reason,
    required String requesterName,
  });
  Future<WorkOrder> respondDeadlineExtension({
    required String woId,
    required bool approve,
    required String reviewerName,
    String? note,
  });
}