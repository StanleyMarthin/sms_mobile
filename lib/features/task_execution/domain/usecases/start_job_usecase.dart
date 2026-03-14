/// StartJobUseCase orchestrates the business logic for starting a mechanic's job.
///
/// Use Cases represent specific business actions and are the primary entry points
/// for the domain layer. They:
/// - Accept input parameters
/// - Coordinate repository calls
/// - Apply business logic and validation
/// - Return Either<Failure, Result> for functional error handling
///
/// This use case implements Business Rules #2 and #3:
/// - Rule #2: Clicking "Start" fires event -> UseCase -> Repository -> API
/// - Rule #3: Handle Loading, Success, and Failure states gracefully
library;

import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/task_entity.dart';
import '../repositories/task_repository.dart';

/// Represents the parameters needed to start a job execution.
///
/// Using a dedicated params class provides several benefits:
/// - Easy to extend with additional parameters in the future
/// - Clear documentation of what inputs are required
/// - Single parameter in use case method (cleaner API)
/// - Better testability (can mock/stub params easily)
class StartJobParams {
  /// The daily assignment ID (from trx_jobdesc_plandaily.id).
  /// This is the primary identifier for mechanic work assignments in the ERP.
  final String plandailyId;

  /// Creates a new StartJobParams instance.
  ///
  /// Parameters:
  ///   - plandailyId: Must not be empty. Backend will validate existence.
  StartJobParams({
    required this.plandailyId,
  });
}

/// Use case for starting job execution with panel locking validation.
///
/// This use case encapsulates the entire business logic flow for starting a job:
///
/// **Pre-Conditions (Enforced by UI):**
/// 1. Must call `GetTaskDetailsUseCase` first to fetch panel lock status
/// 2. Must verify that task.canStart == true
/// 3. Button should be disabled if task.canStart == false
///
/// **Main Flow:**
/// 1. Receive taskId parameter
/// 2. Call repository.startJobExecution(taskId)
/// 3. Repository handles:
///    - Validation on backend (panel lock check)
///    - API call to set panel lock + start timer
///    - State synchronization
/// 4. Return Either<Failure, TaskEntity>
///
/// **Post-Conditions (on Success):**
/// 1. Task status changes from "pending" to "in_progress"
/// 2. Panel becomes locked for other workers
/// 3. Timer starts recording elapsed time
/// 4. UI updates to show "in progress" state
///
/// **Error Handling:**
/// - Network errors: Graceful retry UI
/// - Panel locked: Show red warning (LockingFailure)
/// - Invalid task ID: Show error message (ClientFailure)
/// - Server errors: Retry with exponential backoff
/// - Unknown errors: Log and show generic message
///
/// Example usage in BLoC:
/// ```dart
/// // In BLoC event handler
/// final result = await startJobUseCase(StartJobParams(taskId: taskId));
/// result.fold(
///   (failure) => emit(JobStartFailure(failure.message)),
///   (updatedTask) => emit(JobStartSuccess(updatedTask)),
/// );
/// ```
class StartJobUseCase {
  /// The repository instance for data access.
  /// Injected via constructor (dependency injection).
  final TaskRepository repository;

  /// Creates a StartJobUseCase instance.
  ///
  /// Parameters:
  ///   - repository: The task repository implementation (usually injected by GetIt)
  const StartJobUseCase({required this.repository});

  /// Executes the use case to start a job.
  ///
  /// This method:
  /// 1. Validates input parameters (via params object)
  /// 2. Delegates to repository.startJobExecution()
  /// 3. Returns functional response (Either)
  /// 4. Leaves state management to the BLoC
  ///
  /// Parameters:
  ///   - params: Contains plandailyId and any other required parameters
  ///
  /// Returns:
  ///   - Right(TaskEntity): Job started successfully
  ///   - Left(LockingFailure): Panel is locked
  ///   - Left(NetworkFailure): No network connection
  ///   - Left(TimeoutFailure): API response timeout
  ///   - Left(ServerFailure): Server error (5xx)
  ///   - Left(ClientFailure): Client error (4xx)
  ///   - Left(DataParsingFailure): Invalid response format
  ///   - Left(UnknownFailure): Unexpected error
  ///
  /// Note: This method is async because it makes a network call.
  /// The BLoC will handle the async nature via bloc event handling.
  ///
  /// Example:
  /// ```dart
  /// final useCase = StartJobUseCase(repository: repository);
  /// final result = await useCase(StartJobParams(plandailyId: '550e8400-e29b-41d4-a716-446655440001'));
  /// ```
  Future<Either<Failure, TaskEntity>> call(StartJobParams params) async {
    // The repository handles all implementation details:
    // - Network calls via Dio
    // - Error handling and mapping
    // - JSON parsing
    // - Data transformation
    // - ERP integration
    // The use case simply delegates and returns the result.
    return await repository.startJobExecution(params.plandailyId);
  }
}
