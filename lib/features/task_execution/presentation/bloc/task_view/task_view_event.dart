// Events for the TaskView BLoC.
//
// Handles loading, filtering, and pagination of the unified tasks view.
library;

import 'package:equatable/equatable.dart';

import '../../../domain/entities/task_filter.dart';

abstract class TaskViewEvent extends Equatable {
  const TaskViewEvent();

  @override
  List<Object?> get props => [];
}

/// Load tasks with the current filter.
/// Dispatched on initial load or when filter changes.
class LoadViewTasks extends TaskViewEvent {
  final TaskFilter? filter;
  const LoadViewTasks({this.filter});

  @override
  List<Object?> get props => [filter];
}

/// Change the task type filter (daily/overtime/plan).
class ChangeTaskType extends TaskViewEvent {
  final TaskType type;
  const ChangeTaskType({required this.type});

  @override
  List<Object?> get props => [type];
}

/// Change the date filter.
class ChangeTaskDate extends TaskViewEvent {
  final DateTime date;
  const ChangeTaskDate({required this.date});

  @override
  List<Object?> get props => [date];
}

/// Change the division filter (ADV/PM only).
class ChangeTaskDivision extends TaskViewEvent {
  /// Pass null to clear the filter.
  final String? divisionId;
  const ChangeTaskDivision({this.divisionId});

  @override
  List<Object?> get props => [divisionId];
}

/// Change the unit filter (ADV/PM only).
class ChangeTaskUnit extends TaskViewEvent {
  /// Pass null to clear the filter.
  final String? unitId;
  const ChangeTaskUnit({this.unitId});

  @override
  List<Object?> get props => [unitId];
}

/// Refresh the current task list (pull-to-refresh).
class RefreshViewTasks extends TaskViewEvent {
  const RefreshViewTasks();
}

class SaveTaskCheckpoint extends TaskViewEvent {
  final String planDailyId;
  final String startWorkTime;
  final String finishWorkTime;
  final int progress;
  final String checkpointTime;
  final String jobStatus;

  const SaveTaskCheckpoint({
    required this.planDailyId,
    required this.startWorkTime,
    required this.finishWorkTime,
    required this.progress,
    required this.checkpointTime,
    required this.jobStatus,
  });

  @override
  List<Object?> get props => [
        planDailyId,
        startWorkTime,
        finishWorkTime,
        progress,
        checkpointTime,
        jobStatus,
      ];
}

class UpdateTaskCheckpointSession extends TaskViewEvent {
  final String planDailyId;
  final int sessionNumber;
  final String startWorkTime;
  final String finishWorkTime;
  final int progress;
  final String checkpointTime;
  final String jobStatus;

  const UpdateTaskCheckpointSession({
    required this.planDailyId,
    required this.sessionNumber,
    required this.startWorkTime,
    required this.finishWorkTime,
    required this.progress,
    required this.checkpointTime,
    required this.jobStatus,
  });

  @override
  List<Object?> get props => [
        planDailyId,
        sessionNumber,
        startWorkTime,
        finishWorkTime,
        progress,
        checkpointTime,
        jobStatus,
      ];
}

class ValidateCheckpointSession extends TaskViewEvent {
  final String planDailyId;
  final int sessionNumber;

  const ValidateCheckpointSession({
    required this.planDailyId,
    required this.sessionNumber,
  });

  @override
  List<Object?> get props => [planDailyId, sessionNumber];
}

class ValidateTaskFinal extends TaskViewEvent {
  final String planDailyId;
  final String note;

  const ValidateTaskFinal({
    required this.planDailyId,
    required this.note,
  });

  @override
  List<Object?> get props => [planDailyId, note];
}
