import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/session/session_manager.dart';
import '../datasources/work_order_datasource.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/repositories/work_order_repository.dart';

/// Implementation of [WorkOrderRepository].
///
class WorkOrderRepositoryImpl implements WorkOrderRepository {
  const WorkOrderRepositoryImpl({
    required this.dataSource,
    required this.sessionManager,
  });

  final WorkOrderDataSource dataSource;
  final SessionManager sessionManager;

  String get _userId => sessionManager.employeeId ?? '';

  @override
  Future<Either<Failure, List<WorkOrder>>> getAllWorkOrders() async {
    try {
      final items = await dataSource.getAllWorkOrders();
      return Right(items);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 404));
    }
  }

  @override
  Future<Either<Failure, List<WorkOrder>>> getMyWorkOrders() async {
    final allItems = await dataSource.getAllWorkOrders();
    final myWOs = allItems.where((wo) => wo.requestedById == _userId).toList();
    return Right(myWOs);
  }

  @override
  Future<Either<Failure, WorkOrder>> submitWorkOrder(WorkOrder wo) async {
    final saved = await dataSource.submitWorkOrder(wo);
    return Right(saved);
  }

  @override
  Future<Either<Failure, WorkOrder>> updateWorkOrder(WorkOrder wo) async {
    try {
      final updated = await dataSource.updateWorkOrder(wo);
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 404));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWorkOrder(String woId) async {
    await dataSource.deleteWorkOrder(woId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, WorkOrder>> approveWorkOrder(
      String woId, String approverName) async {
    try {
      final updated = await dataSource.approveWorkOrder(woId, approverName);
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 400));
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> rejectWorkOrder(
      String woId, String rejectedBy, String? reason) async {
    try {
      final updated = await dataSource.rejectWorkOrder(woId, rejectedBy, reason);
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 404));
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> extendDeadline(
      String woId, String newDeadline, String reason) async {
    try {
      final updated = await dataSource.extendDeadline(woId, newDeadline, reason);
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 404));
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> requestRevision({
    required String woId,
    required double requestedEstimatedHours,
    required String requestedDeadline,
    required String reason,
    required String reviewerName,
  }) async {
    try {
      final updated = await dataSource.requestRevision(
        woId: woId,
        requestedEstimatedHours: requestedEstimatedHours,
        requestedDeadline: requestedDeadline,
        reason: reason,
        reviewerName: reviewerName,
      );
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 400));
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> respondRevision({
    required String woId,
    required bool approve,
    required String reviewerName,
    String? note,
  }) async {
    try {
      final updated = await dataSource.respondRevision(
        woId: woId,
        approve: approve,
        reviewerName: reviewerName,
        note: note,
      );
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 400));
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> requestDeadlineExtension({
    required String woId,
    required String newDeadline,
    required String reason,
    required String requesterName,
  }) async {
    try {
      final updated = await dataSource.requestDeadlineExtension(
        woId: woId,
        newDeadline: newDeadline,
        reason: reason,
        requesterName: requesterName,
      );
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 400));
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> respondDeadlineExtension({
    required String woId,
    required bool approve,
    required String reviewerName,
    String? note,
  }) async {
    try {
      final updated = await dataSource.respondDeadlineExtension(
        woId: woId,
        approve: approve,
        reviewerName: reviewerName,
        note: note,
      );
      return Right(updated);
    } on StateError catch (e) {
      return Left(ClientFailure(message: e.message, statusCode: 400));
    }
  }
}
