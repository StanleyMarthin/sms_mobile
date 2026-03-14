import 'package:equatable/equatable.dart';
import '../../domain/entities/work_order.dart';

/// Events for the Work Order BLoC.
abstract class WorkOrderEvent extends Equatable {
  const WorkOrderEvent();

  @override
  List<Object?> get props => [];
}

/// Load all WOs (management view — KD/ADV/PM).
class LoadAllWorkOrders extends WorkOrderEvent {
  const LoadAllWorkOrders();
}

/// Load WOs owned by the current user (OP view).
class LoadMyWorkOrders extends WorkOrderEvent {
  const LoadMyWorkOrders();
}

/// Submit a new WO or WOV.
class SubmitWorkOrder extends WorkOrderEvent {
  final WorkOrder workOrder;

  const SubmitWorkOrder({required this.workOrder});

  @override
  List<Object?> get props => [workOrder];
}

/// Update an existing draft WO.
class UpdateWorkOrder extends WorkOrderEvent {
  final WorkOrder workOrder;

  const UpdateWorkOrder({required this.workOrder});

  @override
  List<Object?> get props => [workOrder];
}

/// Delete a draft WO.
class DeleteWorkOrder extends WorkOrderEvent {
  final String woId;

  const DeleteWorkOrder({required this.woId});

  @override
  List<Object?> get props => [woId];
}

/// Approve a WO (advisor or PM).
class ApproveWo extends WorkOrderEvent {
  final String woId;
  final String approverName;

  const ApproveWo({required this.woId, required this.approverName});

  @override
  List<Object?> get props => [woId, approverName];
}

/// Reject a WO.
class RejectWo extends WorkOrderEvent {
  final String woId;
  final String rejectedBy;
  final String? reason;

  const RejectWo({required this.woId, required this.rejectedBy, this.reason});

  @override
  List<Object?> get props => [woId, rejectedBy, reason];
}

/// Extend a WO deadline.
class ExtendWoDeadline extends WorkOrderEvent {
  final String woId;
  final String newDeadline;
  final String reason;

  const ExtendWoDeadline({
    required this.woId,
    required this.newDeadline,
    required this.reason,
  });

  @override
  List<Object?> get props => [woId, newDeadline, reason];
}

class RequestWoRevision extends WorkOrderEvent {
  final String woId;
  final double requestedEstimatedHours;
  final String requestedDeadline;
  final String reason;
  final String reviewerName;

  const RequestWoRevision({
    required this.woId,
    required this.requestedEstimatedHours,
    required this.requestedDeadline,
    required this.reason,
    required this.reviewerName,
  });

  @override
  List<Object?> get props => [
        woId,
        requestedEstimatedHours,
        requestedDeadline,
        reason,
        reviewerName,
      ];
}

class RespondWoRevision extends WorkOrderEvent {
  final String woId;
  final bool approve;
  final String reviewerName;
  final String? note;

  const RespondWoRevision({
    required this.woId,
    required this.approve,
    required this.reviewerName,
    this.note,
  });

  @override
  List<Object?> get props => [woId, approve, reviewerName, note];
}

class RequestWoExtension extends WorkOrderEvent {
  final String woId;
  final String newDeadline;
  final String reason;
  final String requesterName;

  const RequestWoExtension({
    required this.woId,
    required this.newDeadline,
    required this.reason,
    required this.requesterName,
  });

  @override
  List<Object?> get props => [woId, newDeadline, reason, requesterName];
}

class RespondWoExtension extends WorkOrderEvent {
  final String woId;
  final bool approve;
  final String reviewerName;
  final String? note;

  const RespondWoExtension({
    required this.woId,
    required this.approve,
    required this.reviewerName,
    this.note,
  });

  @override
  List<Object?> get props => [woId, approve, reviewerName, note];
}
