/*
Tujuan: Implementasi repository task execution yang menjembatani domain ke datasource.
Caller: TaskBloc dan StartJobUseCase.
Dependensi: RemoteTaskDataSource, Failure mapper, TaskEntity.
Main Functions: getTodaysTasks, startJobExecution, submitTaskExecution.
Side Effects: HTTP call ke datasource remote dan konversi exception ke failure.
*/
/// TaskRepositoryImpl is the data layer repository implementation.
///
/// This is the critical bridge between the domain and data layers:
/// - Receives `Either<Failure, Entity>` requests from domain
/// - Calls data sources (RemoteTaskDataSource)
/// - Catches low-level exceptions and maps to domain Failures
/// - Transforms models to entities for domain layer
/// - Returns `Either<Failure, Entity>` to domain
///
/// This class ensures:
/// - Pure domain logic never touches data/network details
/// - Consistent error handling across the app
/// - Single responsibility: translate between layers
library;

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/entities/task_execution_log.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/remote_task_datasource.dart';

/// Implementation of TaskRepository using remote API as the data source.
///
/// This repository:
/// 1. Calls the remote data source (Dio)
/// 2. Catches low-level exceptions (DioException, ServerException, etc.)
/// 3. Maps exceptions to domain Failure objects
/// 4. Converts TaskModel to TaskEntity
/// 5. Returns `Either<Failure, TaskEntity>` to the domain
///
/// Pattern for all methods:
/// ```dart
/// try {
///   final model = await remoteDataSource.operation(...);
///   return Right(model.toEntity());
/// } on SpecificException catch (e) {
///   return Left(MappedFailure(...));
/// } ...
/// ```
///
/// This ensures:
/// - Domain layer never sees low-level exceptions
/// - All errors are consistently represented as Failure objects
/// - Tests can easily mock the data source
/// - Implementation can be swapped (local cache, multiple APIs, etc.)
class TaskRepositoryImpl implements TaskRepository {
  /// The data source that handles API calls.
  /// Injected via constructor (dependency injection).
  /// Can be mocked in tests or swapped for a different implementation.
  final RemoteTaskDataSource remoteDataSource;

  /// Creates a TaskRepositoryImpl instance.
  ///
  /// Parameters:
  ///   - remoteDataSource: Implementation of RemoteTaskDataSource
  ///
  /// Example:
  /// ```dart
  /// final dio = Dio()
  ///   ..options.baseUrl = 'https://api.example.com';
  ///
  /// final dataSource = RemoteTaskDataSourceImpl(
  ///   dio: dio,
  ///   baseUrl: 'https://api.example.com',
  /// );
  ///
  /// final repository = TaskRepositoryImpl(dataSource);
  /// ```
  TaskRepositoryImpl({required this.remoteDataSource});

  /// Maps exceptions to appropriate Failure objects.
  ///
  /// This centralized error mapping ensures consistent failure handling
  /// across all repository methods.
  ///
  /// Exception hierarchy:
  /// - DioException: Network-level errors
  ///   - timeout: TimeoutFailure
  ///   - connection error: NetworkFailure
  ///   - other: NetworkFailure
  /// - ServerException: HTTP 5xx errors
  /// - ClientException: HTTP 4xx errors
  ///   - 423 (Locked): LockingFailure
  ///   - others: ClientFailure
  /// - CacheException: Data parsing errors
  /// - Other: UnknownFailure
  ///
  /// Parameters:
  ///   - exception: The exception that occurred
  ///
  /// Returns: Appropriate Failure subclass for the exception
  Failure _mapExceptionToFailure(dynamic exception) {
    if (exception is DioException) {
      return ApiClient.mapDioError(exception);
    }

    if (exception is ServerException) {
      return ServerFailure(
        message: exception.message,
        statusCode: exception.statusCode,
      );
    }

    if (exception is ClientException) {
      /// Special handling for 423 Locked status code
      if (exception.statusCode == 423) {
        return LockingFailure(message: exception.message);
      }
      return ClientFailure(
        message: exception.message,
        statusCode: exception.statusCode,
      );
    }

    if (exception is DataFormatException) {
      return DataParsingFailure(message: exception.message);
    }

    /// Fallback for unmapped exceptions
    return UnknownFailure();
  }

  @override
  Future<Either<Failure, List<TaskEntity>>> getTodaysTasks({
    required DateTime date,
    required bool isOvertime,
    bool forceOwnOnly = false,
  }) async {
    try {
      /// Fetch task models from API for today's date
      final taskModels = await remoteDataSource.getTodaysTasks(
        date: date,
        isOvertime: isOvertime,
        forceOwnOnly: forceOwnOnly,
      );

      /// Convert all models to entities and return success
      final taskEntities = taskModels.map((model) => model.toEntity()).toList();

      return Right(taskEntities);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, TaskEntity>> getTaskById(String plandailyId) async {
    try {
      /// Call data source to fetch task from API with latest lock status
      final taskModel = await remoteDataSource.getTaskById(plandailyId);

      /// Convert model to entity and return success
      return Right(taskModel.toEntity());
    } catch (e) {
      /// Map exception to Failure and return error
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, TaskEntity>> startJobExecution(
    String plandailyId, {
    String? photoBefore1Path,
    String? photoBefore2Path,
  }) async {
    try {
      /// Call data source to start job on backend
      /// Backend will:
      /// 1. Validate panel is not locked
      /// 2. ATOMICALLY lock the panel
      /// 3. Create execution log entry
      /// 4. Return updated task with isPanelLocked=true, startedAt=now
      final taskModel = await remoteDataSource.startJobExecution(
        plandailyId,
        photoBefore1Path: photoBefore1Path,
        photoBefore2Path: photoBefore2Path,
      );

      /// Convert model to entity and return success
      return Right(taskModel.toEntity());
    } catch (e) {
      /// Map exception to Failure
      /// If panel is locked, this will be LockingFailure
      /// If network error, this will be NetworkFailure
      /// etc.
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, TaskEntity>> finishJobExecution(
    String plandailyId,
  ) async {
    try {
      /// Call data source to finish job (unlock panel)
      final taskModel = await remoteDataSource.finishJobExecution(plandailyId);
      return Right(taskModel.toEntity());
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, TaskEntity>> submitTaskExecution(
    TaskExecutionLog executionLog,
  ) async {
    try {
      /// Call data source to submit full execution log
      /// This handles starting, updating progress, and finishing a job
      /// including time logging, progress %, notes, and photos
      final taskModel = await remoteDataSource.submitTaskExecution(
        executionLog,
      );
      return Right(taskModel.toEntity());
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, TaskEntity>> recordBreak(
    String plandailyId, {
    required int breakDurationMinutes,
  }) async {
    try {
      final taskModel = await remoteDataSource.recordBreak(
        plandailyId,
        breakDurationMinutes: breakDurationMinutes,
      );
      return Right(taskModel.toEntity());
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, TaskEntity>> uploadProgressPhoto(
    String plandailyId, {
    required String photoUrl,
    String photoType = 'PROCESS',
  }) async {
    try {
      final taskModel = await remoteDataSource.uploadProgressPhoto(
        plandailyId,
        photoUrl: photoUrl,
        photoType: photoType,
      );
      return Right(taskModel.toEntity());
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }

  @override
  Future<Either<Failure, String>> getUploadTicket({
    required String filename,
  }) async {
    try {
      final uploadUrl = await remoteDataSource.getUploadTicket(
        filename: filename,
      );
      return Right(uploadUrl);
    } catch (e) {
      return Left(_mapExceptionToFailure(e));
    }
  }
}
