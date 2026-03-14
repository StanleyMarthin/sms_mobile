import 'package:equatable/equatable.dart';
import '../../domain/entities/work_order.dart';

/// States for the Mechanic Work Order BLoC.
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

  const WorkOrderLoaded({required this.workOrders});

  @override
  List<Object?> get props => [workOrders];
}

class WorkOrderError extends WorkOrderState {
  final String message;

  const WorkOrderError({required this.message});

  @override
  List<Object?> get props => [message];
}

class WorkOrderActionSuccess extends WorkOrderState {
  final List<WorkOrder> workOrders;
  final String message;

  const WorkOrderActionSuccess({
    required this.workOrders,
    required this.message,
  });

  @override
  List<Object?> get props => [workOrders, message];
}
