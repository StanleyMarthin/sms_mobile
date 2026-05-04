import 'package:equatable/equatable.dart';

abstract class WorkOrderEvent extends Equatable {
  const WorkOrderEvent();
  @override
  List<Object?> get props => [];
}

class LoadWorkOrders extends WorkOrderEvent {
  final String view; // ACTIVE | DONE
  const LoadWorkOrders({this.view = 'ACTIVE'});
  @override
  List<Object?> get props => [view];
}

class RefreshWorkOrders extends WorkOrderEvent {
  const RefreshWorkOrders();
}

class LoadWorkOrderDetail extends WorkOrderEvent {
  final String woId;
  const LoadWorkOrderDetail(this.woId);
  @override
  List<Object?> get props => [woId];
}

class CreateWorkOrder extends WorkOrderEvent {
  final String  carId;
  final String  targetDivId;
  final String  jobDetail;
  final String  targetDate;
  final String? panelName;
  final String? sectionName;
  final String? panelCategory;
  final bool    addPanelToMaster;
  final double? targetHours;

  const CreateWorkOrder({
    required this.carId,
    required this.targetDivId,
    required this.jobDetail,
    required this.targetDate,
    this.panelName,
    this.sectionName,
    this.panelCategory,
    this.addPanelToMaster = false,
    this.targetHours,
  });

  @override
  List<Object?> get props => [carId, targetDivId, jobDetail, targetDate];
}

class ApproveWo extends WorkOrderEvent {
  final String woId;
  final double? estimatedHours; // wajib untuk KD_TARGET
  final String? notes;

  const ApproveWo({required this.woId, this.estimatedHours, this.notes});

  @override
  List<Object?> get props => [woId, estimatedHours, notes];
}

class RejectWo extends WorkOrderEvent {
  final String woId;
  final String rejectReason;

  const RejectWo({required this.woId, required this.rejectReason});

  @override
  List<Object?> get props => [woId, rejectReason];
}

class RequestDlExtension extends WorkOrderEvent {
  final String woId;
  final String newDeadline;
  final String reason;
  const RequestDlExtension({required this.woId, required this.newDeadline, required this.reason});
  @override
  List<Object?> get props => [woId, newDeadline, reason];
}

class RespondDlExtension extends WorkOrderEvent {
  final String woId;
  final bool approve;
  final String? note;
  const RespondDlExtension({required this.woId, required this.approve, this.note});
  @override
  List<Object?> get props => [woId, approve];
}

class RequestHourExtension extends WorkOrderEvent {
  final String woId;
  final double requestedHours;
  final String reason;
  const RequestHourExtension({required this.woId, required this.requestedHours, required this.reason});
  @override
  List<Object?> get props => [woId, requestedHours, reason];
}

class RespondHourExtension extends WorkOrderEvent {
  final String woId;
  final bool approve;
  const RespondHourExtension({required this.woId, required this.approve});
  @override
  List<Object?> get props => [woId, approve];
}
