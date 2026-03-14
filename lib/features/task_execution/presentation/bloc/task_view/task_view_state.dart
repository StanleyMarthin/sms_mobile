// States for the TaskView BLoC.
//
// Represents the different UI states for the unified tasks view page.
library;

import 'package:equatable/equatable.dart';

import '../../../domain/entities/task_filter.dart';
import '../../../domain/entities/view_task_entity.dart';

abstract class TaskViewState extends Equatable {
  const TaskViewState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded.
class TaskViewInitial extends TaskViewState {
  const TaskViewInitial();
}

/// Loading state while fetching tasks.
class TaskViewLoading extends TaskViewState {
  /// Current filter being applied.
  final TaskFilter filter;
  const TaskViewLoading({required this.filter});

  @override
  List<Object?> get props => [filter];
}

/// Successfully loaded task list.
class TaskViewLoaded extends TaskViewState {
  /// Current filter that was applied.
  final TaskFilter filter;

  /// The task response with metadata.
  final ViewTaskResponse response;

  /// Whether the user can filter by division/unit (ADV/PM).
  final bool canFilterDivision;

  /// User's role for conditional UI rendering.
  final String role;

  /// Task currently being processed by a management action.
  final String? actionTaskId;

  /// One-shot feedback for snackbar notifications.
  final String? feedbackMessage;

  /// Whether the feedback is an error.
  final bool isFeedbackError;

  const TaskViewLoaded({
    required this.filter,
    required this.response,
    required this.canFilterDivision,
    required this.role,
    this.actionTaskId,
    this.feedbackMessage,
    this.isFeedbackError = false,
  });

  List<ViewTaskEntity> get tasks => response.tasks;
  int get taskCount => response.tasks.length;

  TaskViewLoaded copyWith({
    TaskFilter? filter,
    ViewTaskResponse? response,
    bool? canFilterDivision,
    String? role,
    String? actionTaskId,
    String? feedbackMessage,
    bool? isFeedbackError,
    bool clearActionTaskId = false,
    bool clearFeedback = false,
  }) {
    return TaskViewLoaded(
      filter: filter ?? this.filter,
      response: response ?? this.response,
      canFilterDivision: canFilterDivision ?? this.canFilterDivision,
      role: role ?? this.role,
      actionTaskId: clearActionTaskId ? null : (actionTaskId ?? this.actionTaskId),
      feedbackMessage: clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
      isFeedbackError: isFeedbackError ?? this.isFeedbackError,
    );
  }

  @override
  List<Object?> get props => [
        filter,
        response,
        canFilterDivision,
        role,
        actionTaskId,
        feedbackMessage,
        isFeedbackError,
      ];
}

/// Error state when task loading fails.
class TaskViewError extends TaskViewState {
  /// Error message to display.
  final String message;

  /// Current filter (preserved for retry).
  final TaskFilter filter;

  const TaskViewError({
    required this.message,
    required this.filter,
  });

  @override
  List<Object?> get props => [message, filter];
}
