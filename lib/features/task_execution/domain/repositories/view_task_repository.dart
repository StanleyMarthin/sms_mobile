// Abstract repository for the unified View Tasks feature.
//
// Provides data access for GET /api/v1/tasks endpoint,
// supporting all roles (OP, KD, ADV, PM).
library;

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/task_filter.dart';
import '../entities/view_task_entity.dart';

/// Repository contract for viewing tasks across all roles.
///
/// The implementation delegates role-based filtering to the backend
/// (or simulates it locally in dev mode).
abstract class ViewTaskRepository {
  /// Fetch tasks based on [filter] parameters.
  ///
  /// Backend automatically applies role-based data scoping:
  /// - OP: Only own tasks
  /// - KD: Division tasks
  /// - ADV: Supervised division tasks (filterable)
  /// - PM: All tasks (filterable)
  Future<Either<Failure, ViewTaskResponse>> getViewTasks(TaskFilter filter);

  Future<Either<Failure, ViewTaskEntity>> saveCheckpoint({
    required String planDailyId,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  });

  Future<Either<Failure, ViewTaskEntity>> updateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  });

  Future<Either<Failure, ViewTaskEntity>> validateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
  });

  Future<Either<Failure, ViewTaskEntity>> validateTask({
    required String planDailyId,
    required bool approved,
    required String note,
  });
}
