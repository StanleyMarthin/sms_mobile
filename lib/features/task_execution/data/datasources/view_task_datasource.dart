// Abstract interface for the View Tasks data source.
//
// Defines the contract for fetching tasks from the API.
// Implementations: LocalViewTaskDataSource (dev), RemoteViewTaskDataSource (prod).
library;

import '../../domain/entities/task_filter.dart';
import '../models/view_task_model.dart';

/// Data source contract for the unified View Tasks feature.
abstract class ViewTaskDataSource {
  /// Fetch tasks based on [filter] parameters.
  ///
  /// Production: Calls GET /api/v1/tasks with query params.
  /// Dev/Local: Returns dummy data filtered by session role.
  Future<List<ViewTaskModel>> getViewTasks(TaskFilter filter);

  /// Record a management checkpoint for a task in progress.
  Future<ViewTaskModel> saveCheckpoint({
    required String planDailyId,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  });

  Future<ViewTaskModel> updateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  });

  Future<ViewTaskModel> validateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
  });

  /// Validate or reject a completed task.
  Future<ViewTaskModel> validateTask({
    required String planDailyId,
    required bool approved,
    required String note,
  });
}
