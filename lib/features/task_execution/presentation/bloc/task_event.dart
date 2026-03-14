import 'package:equatable/equatable.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_execution_log.dart';

/// Events that can be dispatched to the TaskBloc.
///
/// Following BLoC pattern, events represent user actions or system triggers
/// that cause state changes in the task execution feature.
abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered on app startup to load today's task assignments.
///
/// [isOvertime] filters for normal tasks (false) or overtime (true).
class LoadTodaysTasksEvent extends TaskEvent {
  final bool isOvertime;
  final DateTime date;

  const LoadTodaysTasksEvent({
    this.isOvertime = false,
    required this.date,
  });

  @override
  List<Object?> get props => [isOvertime, date];
}

/// Triggered when user pulls to refresh the task list.
class RefreshTasksEvent extends TaskEvent {
  const RefreshTasksEvent();
}

/// Triggered when user taps the "Start" button on a task.
///
/// Before dispatching this event, the UI should verify that
/// task.canStart == true (panel not locked AND status == 'PROSES').
class StartJobEvent extends TaskEvent {
  final String plandailyId;

  const StartJobEvent({required this.plandailyId});

  @override
  List<Object?> get props => [plandailyId];
}

/// Triggered when user taps the "Finish" button on an in-progress task.
class FinishJobEvent extends TaskEvent {
  final String plandailyId;

  const FinishJobEvent({required this.plandailyId});

  @override
  List<Object?> get props => [plandailyId];
}

/// Triggered when mechanic presses "Mulai" — saves draft locally (no API call).
class SaveDraftEvent extends TaskEvent {
  final TaskDraft draft;

  const SaveDraftEvent({required this.draft});

  @override
  List<Object?> get props => [draft];
}

/// Triggered when mechanic confirms "Mulai".
/// Starts the task and persists the draft in one synchronized flow.
class StartTaskFlowEvent extends TaskEvent {
  final String plandailyId;
  final TaskDraft draft;

  const StartTaskFlowEvent({
    required this.plandailyId,
    required this.draft,
  });

  @override
  List<Object?> get props => [plandailyId, draft];
}

/// Triggered on startup to load all saved drafts from local storage.
class LoadDraftsEvent extends TaskEvent {
  const LoadDraftsEvent();
}

/// Triggered when mechanic submits execution data from the TaskExecutionSheet.
///
/// Contains full execution details: start/end time, progress, notes, and photos.
/// After successful API POST, the local draft is automatically deleted.
class SubmitExecutionEvent extends TaskEvent {
  final TaskExecutionLog executionLog;

  const SubmitExecutionEvent({required this.executionLog});

  @override
  List<Object?> get props => [executionLog];
}
