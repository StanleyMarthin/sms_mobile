import 'package:equatable/equatable.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_entity.dart';

/// States emitted by the TaskBloc.
///
/// Each state represents a distinct UI view:
/// - TaskInitial: Nothing loaded yet
/// - TaskLoading: Fetching data (show spinner)
/// - TaskLoaded: Data ready (show task list)
/// - TaskError: Something went wrong (show error message)
/// - TaskActionLoading: A specific task action is in progress
/// - TaskActionSuccess: A task action completed successfully
/// - TaskActionError: A task action failed
abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded.
class TaskInitial extends TaskState {
  const TaskInitial();
}

/// Loading state while fetching tasks from API.
class TaskLoading extends TaskState {
  const TaskLoading();
}

/// Success state with today's task list.
///
/// Also carries a map of saved drafts (plandailyId → TaskDraft)
/// so the UI can show which tasks have been "started" locally.
class TaskLoaded extends TaskState {
  final List<TaskEntity> tasks;
  final Map<String, TaskDraft> drafts;

  const TaskLoaded({required this.tasks, this.drafts = const {}});

  @override
  List<Object?> get props => [tasks, drafts];
}

/// Error state when task loading fails.
class TaskError extends TaskState {
  final String message;

  const TaskError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Loading state for a specific action (start/finish job).
/// Keeps current tasks visible while action is in progress.
class TaskActionLoading extends TaskState {
  final List<TaskEntity> tasks;
  final Map<String, TaskDraft> drafts;
  final String actionTaskId;

  const TaskActionLoading({
    required this.tasks,
    this.drafts = const {},
    required this.actionTaskId,
  });

  @override
  List<Object?> get props => [tasks, drafts, actionTaskId];
}

/// Success state after a task action (start/finish) completes.
class TaskActionSuccess extends TaskState {
  final List<TaskEntity> tasks;
  final Map<String, TaskDraft> drafts;
  final String message;

  const TaskActionSuccess({
    required this.tasks,
    this.drafts = const {},
    required this.message,
  });

  @override
  List<Object?> get props => [tasks, drafts, message];
}

/// Error state for a failed task action.
/// Keeps current tasks visible so user can retry.
class TaskActionError extends TaskState {
  final List<TaskEntity> tasks;
  final Map<String, TaskDraft> drafts;
  final String message;

  const TaskActionError({
    required this.tasks,
    this.drafts = const {},
    required this.message,
  });

  @override
  List<Object?> get props => [tasks, drafts, message];
}
