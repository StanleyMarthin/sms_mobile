// Repository implementation for the View Tasks feature.
//
// Bridges the domain and data layers, converting exceptions
// to typed failures following the fpdart Either pattern.
library;

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/task_filter.dart';
import '../../domain/entities/view_task_entity.dart';
import '../../domain/repositories/view_task_repository.dart';
import '../datasources/remote_task_datasource.dart';
import '../datasources/view_task_datasource.dart';

class ViewTaskRepositoryImpl implements ViewTaskRepository {
  final ViewTaskDataSource dataSource;

  const ViewTaskRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, ViewTaskResponse>> getViewTasks(
      TaskFilter filter) async {
    try {
      final models = await dataSource.getViewTasks(filter);
      final entities = models.map((m) => m.toEntity()).toList();

      final dateStr =
          '${filter.date.year}-${filter.date.month.toString().padLeft(2, '0')}-${filter.date.day.toString().padLeft(2, '0')}';

      final response = ViewTaskResponse(
        type: filter.type.value,
        date: dateStr,
        divisionId: filter.divisionId,
        unitId: filter.unitId,
        tasks: entities,
      );

      return Right(response);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on DataFormatException catch (e) {
      return Left(DataParsingFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(
        message: 'Gagal memuat daftar tugas: $e',
      ));
    }
  }

  @override
  Future<Either<Failure, ViewTaskEntity>> saveCheckpoint({
    required String planDailyId,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  }) async {
    try {
      final model = await dataSource.saveCheckpoint(
        planDailyId: planDailyId,
        startWorkTime: startWorkTime,
        finishWorkTime: finishWorkTime,
        progress: progress,
        checkpointTime: checkpointTime,
        jobStatus: jobStatus,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on DataFormatException catch (e) {
      return Left(DataParsingFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(
        message: 'Gagal menyimpan check progress: $e',
      ));
    }
  }

  @override
  Future<Either<Failure, ViewTaskEntity>> updateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  }) async {
    try {
      final model = await dataSource.updateCheckpointSession(
        planDailyId: planDailyId,
        sessionNumber: sessionNumber,
        startWorkTime: startWorkTime,
        finishWorkTime: finishWorkTime,
        progress: progress,
        checkpointTime: checkpointTime,
        jobStatus: jobStatus,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on DataFormatException catch (e) {
      return Left(DataParsingFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: 'Gagal mengubah check progress: $e'));
    }
  }

  @override
  Future<Either<Failure, ViewTaskEntity>> validateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
  }) async {
    try {
      final model = await dataSource.validateCheckpointSession(
        planDailyId: planDailyId,
        sessionNumber: sessionNumber,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on DataFormatException catch (e) {
      return Left(DataParsingFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: 'Gagal memvalidasi check progress: $e'));
    }
  }

  @override
  Future<Either<Failure, ViewTaskEntity>> validateTask({
    required String planDailyId,
    required bool approved,
    required String note,
  }) async {
    try {
      final model = await dataSource.validateTask(
        planDailyId: planDailyId,
        approved: approved,
        note: note,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on DataFormatException catch (e) {
      return Left(DataParsingFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(
        message: 'Gagal memvalidasi task: $e',
      ));
    }
  }

  Failure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return TimeoutFailure(message: 'Request timeout: ${e.message}');
      case DioExceptionType.connectionError:
        return NetworkFailure(message: 'Koneksi gagal: ${e.message}');
      default:
        return NetworkFailure(message: 'Network error: ${e.message}');
    }
  }
}
