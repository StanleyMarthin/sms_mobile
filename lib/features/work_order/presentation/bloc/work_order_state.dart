import 'package:equatable/equatable.dart';
import '../../domain/entities/work_order.dart';

abstract class WorkOrderState extends Equatable {
  const WorkOrderState();
  @override
  List<Object?> get props => [];
}

class WorkOrderInitial extends WorkOrderState {
  const WorkOrderInitial();
}

class WorkOrderLoading extends WorkOrderState {
  const WorkOrderLoading();
}

class WorkOrderLoaded extends WorkOrderState {
  final List<WorkOrder> workOrders;
  final String view;
  const WorkOrderLoaded({required this.workOrders, this.view = 'ACTIVE'});
  @override
  List<Object?> get props => [workOrders, view];
}

class WorkOrderDetailLoaded extends WorkOrderState {
  final WorkOrder workOrder;
  const WorkOrderDetailLoaded(this.workOrder);
  @override
  List<Object?> get props => [workOrder];
}

class WorkOrderActionLoading extends WorkOrderState {
  const WorkOrderActionLoading();
}

class WorkOrderActionSuccess extends WorkOrderState {
  final List<WorkOrder> workOrders;
  final String message;
  final String view;
  const WorkOrderActionSuccess({required this.workOrders, required this.message, this.view = 'ACTIVE'});
  @override
  List<Object?> get props => [workOrders, message];
}

class WorkOrderError extends WorkOrderState {
  final String message;
  const WorkOrderError({required this.message});
  @override
  List<Object?> get props => [message];
}
