/*
Tujuan: Kontrak domain untuk operasi task execution dan self-execution milik management.
Caller: StartJobUseCase, TaskBloc, dan flow task execution management.
Dependensi: Failure model domain, TaskEntity, TaskExecutionLog.
Main Functions: getTodaysTasks, startJobExecution, submitTaskExecution, recordBreak.
Side Effects: Tidak ada langsung; implementasi turunannya melakukan HTTP call dan upload flow.
*/
/// Abstract TaskRepository interface in the domain layer.
///
/// This is the central contract between the domain and data layers.
/// It defines all operations the domain layer expects from the data layer
/// using functional error handling (`Either` type from fpdart).
///
/// Implementation details are hidden from the domain layer, allowing for:
/// - Easy testing with mock implementations
/// - Swapping data sources without affecting business logic
/// - Clear separation of concerns
library;

import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/task_entity.dart';
import '../entities/task_execution_log.dart';

/// Abstract interface for task-related data operations.
///
/// All methods return `Either<Failure, Success>` following functional programming
/// paradigm. This forces callers to handle both success and failure cases explicitly.
/// No null safety workarounds - either you have data or you have a Failure.
///
/// The pattern is:
/// - Left = Failure (error occurred)
/// - Right = Success (data retrieved)
///
/// Usage in domain layer:
/// ```dart
/// final result = await taskRepository.getTaskById(taskId);
/// result.fold(
///   (failure) => // handle failure
///   (taskEntity) => // handle success
/// );
/// ```
abstract class TaskRepository {
  /// Fetches today's task assignments for the current mechanic.
  ///
  /// This is called on app startup to populate the mechanic's dashboard.
  /// Returns all daily assignments from ERP that match today's date.
  ///
  /// This method:
  /// - Makes an API call to retrieve today's tasks
  /// - Parses the response into a list of TaskEntity objects
  /// - Handles network errors, timeouts, and parsing failures
  /// - Returns `Either<Failure, List<TaskEntity>>`
  ///
  /// Returns:
  ///   - `Right(List<TaskEntity>)`: Successfully retrieved today's tasks
  ///   - `Left(NetworkFailure)`: Network connection failed
  ///   - `Left(TimeoutFailure)`: API response took too long
  ///   - `Left(ServerFailure)`: Server returned 5xx error
  ///   - `Left(ClientFailure)`: Server returned 4xx error
  ///   - `Left(DataParsingFailure)`: JSON parsing failed
  ///   - `Left(UnknownFailure)`: Unexpected error
  ///
  /// Example:
  /// ```dart
  /// final result = await repository.getTodaysTasks();
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (tasks) => print('Tasks: ${tasks.length}'),
  /// );
  /// ```
  Future<Either<Failure, List<TaskEntity>>> getTodaysTasks({
    required DateTime date,
    required bool isOvertime,
    bool forceOwnOnly = false,
  });

  /// Fetches a single task by its plandailyId along with its current panel lock status.
  ///
  /// **CRITICAL FOR BUSINESS RULE #1**: This must fetch the latest panel
  /// locking status to ensure the UI shows correct "Start" button state.
  ///
  /// This method:
  /// - Makes an API call to retrieve task details
  /// - Includes the current isPanelLocked status from ERP
  /// - Handles network errors, timeouts, and parsing failures
  /// - Returns `Either<Failure, TaskEntity>`
  ///
  /// Parameters:
  ///   - plandailyId: The daily assignment ID to retrieve
  ///
  /// Returns:
  ///   - `Right(TaskEntity)`: Successfully retrieved task with latest status
  ///   - `Left(NetworkFailure)`: Network connection failed
  ///   - `Left(TimeoutFailure)`: API response took too long
  ///   - `Left(ServerFailure)`: Server returned 5xx error
  ///   - `Left(ClientFailure)`: Server returned 4xx error
  ///   - `Left(DataParsingFailure)`: JSON parsing failed
  ///   - `Left(UnknownFailure)`: Unexpected error
  ///
  /// Example:
  /// ```dart
  /// final result = await repository.getTaskById('550e8400-e29b-41d4-a716-446655440001');
  /// result.fold(
  ///   (failure) => print('Error: ${failure.message}'),
  ///   (task) => print('Panel locked: ${task.isPanelLocked}'),
  /// );
  /// ```
  Future<Either<Failure, TaskEntity>> getTaskById(String plandailyId);

  /// Starts the execution of a task by locking its panel and initiating timer.
  ///
  /// **IMPLEMENTS ALL THREE BUSINESS RULES**:
  /// 1. Validates panel lock status before proceeding
  /// 2. Locks the panel and starts the execution timer on backend
  /// 3. Returns updated TaskEntity with new status
  ///
  /// This method should NOT be called if isPanelLocked == true, but the backend
  /// will also enforce this validation. Always check task.canStart before calling.
  ///
  /// This method:
  /// - Makes a POST request to the API to start the job
  /// - Sends plandailyId to the backend
  /// - Backend creates execution log entry in trx_jobdesc_actual
  /// - Returns the updated task with status = "PROSES", isPanelLocked=true
  /// - Handles all error scenarios gracefully
  /// - May return LockingFailure if backend enforces lock rules
  ///
  /// Parameters:
  ///   - plandailyId: The daily assignment ID to start
  ///
  /// Returns:
  ///   - `Right(TaskEntity)`: Successfully started, panel now locked
  ///   - `Left(LockingFailure)`: Panel is locked - start not permitted
  ///   - `Left(NetworkFailure)`: Network connection failed
  ///   - `Left(TimeoutFailure)`: API response took too long
  ///   - `Left(ServerFailure)`: Server error occurred
  ///   - `Left(ClientFailure)`: Invalid task ID or missing data
  ///   - `Left(DataParsingFailure)`: Response parsing failed
  ///   - `Left(UnknownFailure)`: Unexpected error
  ///
  /// Example:
  /// ```dart
  /// final task = ...;
  /// if (task.canStart) {
  ///   final result = await repository.startJobExecution(task.plandailyId);
  ///   result.fold(
  ///     (failure) => _showErrorDialog(failure.message),
  ///     (updatedTask) => print('Task started: ${updatedTask.status}'),
  ///   );
  /// }
  /// ```
  Future<Either<Failure, TaskEntity>> startJobExecution(
    String plandailyId, {
    String? photoBefore1Path,
    String? photoBefore2Path,
  });

  /// Finishes job execution and unlocks the panel.
  ///
  /// Called when a mechanic finishes work. This:
  /// - Marks completion time in the execution log
  /// - Unlocks the panel for other workers
  /// - Updates remaining hours based on actual time spent
  /// - Records completion timestamp
  ///
  /// Parameters:
  ///   - plandailyId: The daily assignment ID to finish
  ///
  /// Returns:
  ///   - `Right(TaskEntity)`: Successfully finished, panel now unlocked
  ///   - `Left(Failure)`: Various failure scenarios
  ///
  /// Expected backend behavior:
  /// - Find latest trx_jobdesc_actual without finish_time
  /// - Set finish_time = now
  /// - Calculate elapsed time and update remaining hours
  /// - ATOMICALLY unlock the panel
  /// - Update task status based on remaining hours (DONE if 0, otherwise PROSES)
  Future<Either<Failure, TaskEntity>> finishJobExecution(String plandailyId);

  /// Submits a full task execution log from the mechanic's execution sheet.
  ///
  /// This is the main method for the enhanced execution flow where the mechanic
  /// inputs start/end times, progress percentage, notes, and photos.
  ///
  /// Business logic:
  /// - If the task hasn't started yet → starts the job (locks panel) + saves execution log
  /// - If progress is 100% → finishes the job (unlocks panel)
  /// - Otherwise → saves an execution update log
  ///
  /// Parameters:
  ///   - executionLog: Full execution data including times, progress, photos
  ///
  /// Returns:
  ///   - `Right(TaskEntity)`: Successfully saved, returns updated task
  ///   - `Left(LockingFailure)`: Panel is locked by another mechanic
  ///   - `Left(Failure)`: Various error scenarios
  Future<Either<Failure, TaskEntity>> submitTaskExecution(
    TaskExecutionLog executionLog,
  );

  /// Record break duration on active task session.
  Future<Either<Failure, TaskEntity>> recordBreak(
    String plandailyId, {
    required int breakDurationMinutes,
  });

  /// Upload progress photo metadata during active task execution.
  Future<Either<Failure, TaskEntity>> uploadProgressPhoto(
    String plandailyId, {
    required String photoUrl,
    String photoType = 'progress',
  });

  /// Retrieve pre-signed direct upload URL for task photos.
  Future<Either<Failure, String>> getUploadTicket({required String filename});
}
