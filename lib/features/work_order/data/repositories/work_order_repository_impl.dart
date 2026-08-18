/*
Tujuan: Implementasi repository Work Order yang menjembatani bloc/domain dengan remote datasource.
Caller: Dependency injection untuk WorkOrderRepository.
Dependensi: WorkOrderRemoteDataSource, SessionManager, ApiClient failure mapper, WorkOrder entity.
Main Functions: getWorkOrders, getWorkOrderById, createWorkOrder, approveWorkOrder, rejectWorkOrder.
Side Effects: Menjalankan HTTP request ke datasource dan memetakan error ke Failure.
*/
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../datasources/work_order_datasource.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/repositories/work_order_repository.dart';

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  WorkOrderRepositoryImpl({
    required this.dataSource,
    required this.sessionManager,
  });

  final WorkOrderRemoteDataSource dataSource;
  final SessionManager sessionManager;

  Either<Failure, T> _handle<T>(Object error, StackTrace stackTrace) {
    if (error is DioException) {
      return Left(ApiClient.mapDioError(error));
    }
    if (error is StateError) {
      return Left(ClientFailure(message: error.message, statusCode: 400));
    }
    if (error is FormatException) {
      return Left(DataParsingFailure(message: error.message));
    }
    return Left(UnknownFailure(message: friendlyMessage(error)));
  }

  @override
  Future<Either<Failure, List<WorkOrder>>> getWorkOrders({
    String view = 'ACTIVE',
    int page = 1,
    int limit = 30,
  }) async {
    try {
      return Right(
        await dataSource.getWorkOrders(view: view, page: page, limit: limit),
      );
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> getWorkOrderById(String woId) async {
    try {
      return Right(await dataSource.getWorkOrderById(woId));
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, WorkOrder>> createWorkOrder({
    required String carId,
    required String targetDivId,
    required String jobDetail,
    String? notes,
    required String targetDate,
    String? panelName,
    String? sectionName,
    String? panelCategory,
    bool addPanelToMaster = false,
    double? targetHours,
  }) async {
    try {
      return Right(
        await dataSource.createWorkOrder(
          carId: carId,
          targetDivId: targetDivId,
          jobDetail: jobDetail,
          notes: notes,
          targetDate: targetDate,
          panelName: panelName,
          sectionName: sectionName,
          panelCategory: panelCategory,
          addPanelToMaster: addPanelToMaster,
          targetHours: targetHours,
        ),
      );
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createWorkOrdersBatch({
    required String carId,
    required String targetDivId,
    required String targetDate,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      return Right(
        await dataSource.createWorkOrdersBatch(
          carId: carId,
          targetDivId: targetDivId,
          targetDate: targetDate,
          items: items,
        ),
      );
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> approveWorkOrder({
    required String woId,
    double? estimatedHours,
    String? notes,
    String? picId,
  }) async {
    try {
      return Right(
        await dataSource.approveWorkOrder(
          woId: woId,
          estimatedHours: estimatedHours,
          notes: notes,
          picId: picId,
        ),
      );
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, void>> rejectWorkOrder({
    required String woId,
    required String rejectReason,
  }) async {
    try {
      await dataSource.rejectWorkOrder(woId: woId, rejectReason: rejectReason);
      return Right(null);
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, void>> requestDeadlineExtension({
    required String woId,
    required String newDeadline,
    required String reason,
  }) async {
    try {
      await dataSource.requestDeadlineExtension(
        woId: woId,
        newDeadline: newDeadline,
        reason: reason,
      );
      return Right(null);
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, void>> respondDeadlineExtension({
    required String woId,
    required bool approve,
    String? note,
  }) async {
    try {
      await dataSource.respondDeadlineExtension(
        woId: woId,
        approve: approve,
        note: note,
      );
      return Right(null);
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, void>> requestHourExtension({
    required String woId,
    required double requestedHours,
    required String reason,
  }) async {
    try {
      await dataSource.requestHourExtension(
        woId: woId,
        hours: requestedHours,
        reason: reason,
      );
      return Right(null);
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, void>> respondHourExtension({
    required String woId,
    required bool approve,
  }) async {
    try {
      await dataSource.respondHourExtension(woId: woId, approve: approve);
      return Right(null);
    } catch (e, s) {
      return _handle(e, s);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDropdowns({
    String? carId,
    String? divisionId,
  }) async {
    try {
      return Right(
        await dataSource.getDropdowns(carId: carId, divisionId: divisionId),
      );
    } catch (e, s) {
      return _handle(e, s);
    }
  }
}
