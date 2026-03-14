library;

import '../../../../core/data/dummy_data.dart';
import '../../domain/entities/work_order.dart';
import 'work_order_datasource.dart';

class LocalWorkOrderDataSource implements WorkOrderDataSource {
  final List<WorkOrder> _workOrders = [];
  bool _seeded = false;

  void _seedIfNeeded() {
    if (_seeded) return;
    _seeded = true;
    _workOrders.addAll(
      DummyWorkOrders.seedRecords().map(
        (item) => WorkOrder(
          id: item['id'] as String,
          woNumber: item['woNumber'] as String,
          woType: item['woType'] as String,
          carId: item['carId'] as String,
          unitName: item['unitName'] as String,
          ownerName: item['ownerName'] as String,
          panelName: item['panelName'] as String,
          partName: item['partName'] as String?,
          jobdescName: item['jobdescName'] as String?,
          coreId: item['coreId'] as String,
          description: item['description'] as String,
          fromDivision: item['fromDivision'] as String,
          toDivision: item['toDivision'] as String,
          estimatedHours: (item['estimatedHours'] as num).toDouble(),
          priority: item['priority'] as String,
          status: item['status'] as String,
          notes: item['notes'] as String,
          requestedById: item['requestedById'] as String,
          requestedByName: item['requestedByName'] as String,
          createdAt: item['createdAt'] as String,
          deadline: item['deadline'] as String?,
          advisorApprovedAt: item['advisorApprovedAt'] as String?,
          advisorApprovedBy: item['advisorApprovedBy'] as String?,
          pmApprovedAt: item['pmApprovedAt'] as String?,
          pmApprovedBy: item['pmApprovedBy'] as String?,
          rejectedReason: item['rejectedReason'] as String?,
          rejectedBy: item['rejectedBy'] as String?,
          previousDeadline: item['previousDeadline'] as String?,
          extensionReason: item['extensionReason'] as String?,
          approvedAt: item['approvedAt'] as String?,
          revisionRequestStatus: item['revisionRequestStatus'] as String?,
          requestedEstimatedHours:
              (item['requestedEstimatedHours'] as num?)?.toDouble(),
          requestedDeadline: item['requestedDeadline'] as String?,
          revisionReason: item['revisionReason'] as String?,
          revisionReviewedBy: item['revisionReviewedBy'] as String?,
          extensionRequestStatus: item['extensionRequestStatus'] as String?,
          extensionRequestedDeadline:
              item['extensionRequestedDeadline'] as String?,
          extensionRequestedReason: item['extensionRequestedReason'] as String?,
          extensionReviewedBy: item['extensionReviewedBy'] as String?,
        ),
      ),
    );
  }

  @override
  Future<List<WorkOrder>> getAllWorkOrders() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seedIfNeeded();
    return List<WorkOrder>.unmodifiable(_workOrders);
  }

  @override
  Future<WorkOrder> submitWorkOrder(WorkOrder wo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seedIfNeeded();
    _workOrders.add(wo);
    return wo;
  }

  @override
  Future<WorkOrder> updateWorkOrder(WorkOrder wo) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == wo.id);
    if (idx == -1) throw StateError('WO not found');
    _workOrders[idx] = wo;
    return wo;
  }

  @override
  Future<void> deleteWorkOrder(String woId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _seedIfNeeded();
    _workOrders.removeWhere((w) => w.id == woId);
  }

  @override
  Future<WorkOrder> approveWorkOrder(String woId, String approverName) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final wo = _workOrders[idx];
    final now = DateTime.now().toIso8601String();

    final WorkOrder updated;
    if (wo.isPendingAdvisor) {
      updated = wo.copyWith(
        status: 'PENDING_PM',
        advisorApprovedAt: now,
        advisorApprovedBy: approverName,
      );
    } else if (wo.isPendingPm) {
      updated = wo.copyWith(
        status: 'APPROVED',
        pmApprovedAt: now,
        pmApprovedBy: approverName,
        approvedAt: now,
      );
    } else {
      throw StateError('WO status ${wo.status} tidak bisa diapprove');
    }

    _workOrders[idx] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> rejectWorkOrder(
      String woId, String rejectedBy, String? reason) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final updated = _workOrders[idx].copyWith(
      status: 'REJECTED',
      rejectedBy: rejectedBy,
      rejectedReason: reason,
    );
    _workOrders[idx] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> extendDeadline(
      String woId, String newDeadline, String reason) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final wo = _workOrders[idx];
    final updated = wo.copyWith(
      previousDeadline: wo.deadline,
      deadline: newDeadline,
      extensionReason: reason,
      extensionRequestStatus: 'APPROVED',
    );
    _workOrders[idx] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> requestRevision({
    required String woId,
    required double requestedEstimatedHours,
    required String requestedDeadline,
    required String reason,
    required String reviewerName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final wo = _workOrders[idx];
    if (!wo.isPendingAdvisor && !wo.isPendingPm) {
      throw StateError('WO status ${wo.status} tidak bisa diminta revisi');
    }

    final nextStatus = wo.isPendingAdvisor
        ? 'REVISION_REQUESTED_ADVISOR'
        : 'REVISION_REQUESTED_PM';
    final updated = wo.copyWith(
      status: nextStatus,
      revisionRequestStatus: 'PENDING',
      requestedEstimatedHours: requestedEstimatedHours,
      requestedDeadline: requestedDeadline,
      revisionReason: reason,
      revisionReviewedBy: reviewerName,
    );
    _workOrders[idx] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> respondRevision({
    required String woId,
    required bool approve,
    required String reviewerName,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final wo = _workOrders[idx];
    final isAdvisorStage = wo.status == 'REVISION_REQUESTED_ADVISOR';
    final isPmStage = wo.status == 'REVISION_REQUESTED_PM';
    if (!isAdvisorStage && !isPmStage) {
      throw StateError('WO tidak dalam status revisi');
    }

    final backStatus = isAdvisorStage ? 'PENDING_ADVISOR' : 'PENDING_PM';
    var updated = wo.copyWith(
      status: backStatus,
      revisionRequestStatus: approve ? 'APPROVED' : 'REJECTED',
      revisionReviewedBy: reviewerName,
    );

    if (approve) {
      updated = updated.copyWith(
        estimatedHours: wo.requestedEstimatedHours,
        deadline: wo.requestedDeadline,
      );
    }

    if (note != null && note.trim().isNotEmpty) {
      final merged = updated.notes.isEmpty
          ? note.trim()
          : '${updated.notes}\nCatatan revisi: ${note.trim()}';
      updated = updated.copyWith(notes: merged);
    }

    _workOrders[idx] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> requestDeadlineExtension({
    required String woId,
    required String newDeadline,
    required String reason,
    required String requesterName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final wo = _workOrders[idx];
    if (wo.isDone || wo.isRejected) {
      throw StateError('WO selesai/ditolak tidak bisa minta perpanjangan');
    }

    final updated = wo.copyWith(
      extensionRequestStatus: 'PENDING',
      extensionRequestedDeadline: newDeadline,
      extensionRequestedReason: reason,
      extensionReviewedBy: requesterName,
    );
    _workOrders[idx] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> respondDeadlineExtension({
    required String woId,
    required bool approve,
    required String reviewerName,
    String? note,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _seedIfNeeded();
    final idx = _workOrders.indexWhere((w) => w.id == woId);
    if (idx == -1) throw StateError('WO not found');
    final wo = _workOrders[idx];
    if (wo.extensionRequestStatus != 'PENDING') {
      throw StateError('Tidak ada request perpanjangan aktif');
    }

    var updated = wo.copyWith(
      extensionRequestStatus: approve ? 'APPROVED' : 'REJECTED',
      extensionReviewedBy: reviewerName,
    );

    if (approve) {
      updated = updated.copyWith(
        previousDeadline: wo.deadline,
        deadline: wo.extensionRequestedDeadline,
        extensionReason: wo.extensionRequestedReason,
      );
    }

    if (note != null && note.trim().isNotEmpty) {
      final merged = updated.notes.isEmpty
          ? note.trim()
          : '${updated.notes}\nCatatan perpanjangan: ${note.trim()}';
      updated = updated.copyWith(notes: merged);
    }

    _workOrders[idx] = updated;
    return updated;
  }
}
