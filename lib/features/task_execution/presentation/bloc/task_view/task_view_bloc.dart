// TaskView BLoC — manages the unified tasks view for all roles.
//
// Handles loading, filtering by type/date/division/unit,
// and role-based UI state (canFilterDivision flag).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/session/session_manager.dart';
import '../../../domain/entities/task_filter.dart';
import '../../../domain/repositories/view_task_repository.dart';
import 'task_view_event.dart';
import 'task_view_state.dart';

class TaskViewBloc extends Bloc<TaskViewEvent, TaskViewState> {
  final ViewTaskRepository repository;

  TaskViewBloc({required this.repository}) : super(TaskViewInitial()) {
    on<LoadViewTasks>(_onLoadViewTasks);
    on<ChangeTaskType>(_onChangeTaskType);
    on<ChangeTaskDate>(_onChangeTaskDate);
    on<ChangeTaskDivision>(_onChangeTaskDivision);
    on<ChangeTaskUnit>(_onChangeTaskUnit);
    on<RefreshViewTasks>(_onRefreshViewTasks);
    on<SaveTaskCheckpoint>(_onSaveTaskCheckpoint);
    on<UpdateTaskCheckpointSession>(_onUpdateTaskCheckpointSession);
    on<ValidateCheckpointSession>(_onValidateCheckpointSession);
    on<ValidateTaskFinal>(_onValidateTaskFinal);
  }

  /// Get the current filter from state, or create a default one.
  TaskFilter _currentFilter() {
    final currentState = state;
    if (currentState is TaskViewLoaded) return currentState.filter;
    if (currentState is TaskViewLoading) return currentState.filter;
    if (currentState is TaskViewError) return currentState.filter;
    return TaskFilter(date: DateTime.now());
  }

  /// Whether the user can filter by divisionId/unitId (ADV or PM).
  bool get _canFilterDivision {
    final session = sl<SessionManager>();
    return session.canViewAssignedUnits || session.canViewAllUnits;
  }

  String get _role => sl<SessionManager>().role ?? 'op';

  String _normalizeCheckpointFailureMessage(String? message) {
    final raw = (message ?? '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('belum') &&
        (lower.contains('mulai') ||
            lower.contains('dimulai') ||
            lower.contains('start') ||
            lower.contains('proses'))) {
      return 'jobdesc belum dimulai';
    }
    if (lower.contains('not started') ||
        lower.contains('not in progress') ||
        lower.contains('must be started')) {
      return 'jobdesc belum dimulai';
    }
    return raw.isNotEmpty ? raw : 'Gagal menyimpan monitoring';
  }

  Future<void> _onLoadViewTasks(
    LoadViewTasks event,
    Emitter<TaskViewState> emit,
  ) async {
    final filter = event.filter ?? _currentFilter();
    emit(TaskViewLoading(filter: filter));

    await _loadTasksForFilter(filter, emit);
  }

  Future<void> _loadTasksForFilter(
    TaskFilter filter,
    Emitter<TaskViewState> emit, {
    String? feedbackMessage,
    bool isFeedbackError = false,
  }) async {
    final result = await repository.getViewTasks(filter);
    result.fold(
      (failure) => emit(
        TaskViewError(
          message: failure.message ?? 'Gagal memuat daftar tugas',
          filter: filter,
        ),
      ),
      (response) => emit(
        TaskViewLoaded(
          filter: filter,
          response: response,
          canFilterDivision: _canFilterDivision,
          role: _role,
          feedbackMessage: feedbackMessage,
          isFeedbackError: isFeedbackError,
        ),
      ),
    );
  }

  Future<void> _onChangeTaskType(
    ChangeTaskType event,
    Emitter<TaskViewState> emit,
  ) async {
    final newFilter = _currentFilter().copyWith(type: event.type, page: 1);
    add(LoadViewTasks(filter: newFilter));
  }

  Future<void> _onChangeTaskDate(
    ChangeTaskDate event,
    Emitter<TaskViewState> emit,
  ) async {
    final newFilter = _currentFilter().copyWith(date: event.date, page: 1);
    add(LoadViewTasks(filter: newFilter));
  }

  Future<void> _onChangeTaskDivision(
    ChangeTaskDivision event,
    Emitter<TaskViewState> emit,
  ) async {
    final newFilter = event.divisionId != null
        ? _currentFilter().copyWith(divisionId: event.divisionId, page: 1)
        : _currentFilter().copyWith(clearDivisionId: true, page: 1);
    add(LoadViewTasks(filter: newFilter));
  }

  Future<void> _onChangeTaskUnit(
    ChangeTaskUnit event,
    Emitter<TaskViewState> emit,
  ) async {
    final newFilter = event.unitId != null
        ? _currentFilter().copyWith(unitId: event.unitId, page: 1)
        : _currentFilter().copyWith(clearUnitId: true, page: 1);
    add(LoadViewTasks(filter: newFilter));
  }

  Future<void> _onRefreshViewTasks(
    RefreshViewTasks event,
    Emitter<TaskViewState> emit,
  ) async {
    add(LoadViewTasks(filter: _currentFilter()));
  }

  Future<void> _onSaveTaskCheckpoint(
    SaveTaskCheckpoint event,
    Emitter<TaskViewState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TaskViewLoaded) return;

    emit(
      currentState.copyWith(
        actionTaskId: event.planDailyId,
        clearFeedback: true,
        isFeedbackError: false,
      ),
    );

    final result = await repository.saveCheckpoint(
      planDailyId: event.planDailyId,
      startWorkTime: event.startWorkTime,
      finishWorkTime: event.finishWorkTime,
      progress: event.progress,
      checkpointTime: event.checkpointTime,
      jobStatus: event.jobStatus,
    );

    await result.fold(
      (failure) async {
        emit(
          currentState.copyWith(
            clearActionTaskId: true,
            feedbackMessage: _normalizeCheckpointFailureMessage(
              failure.message,
            ),
            isFeedbackError: true,
          ),
        );
      },
      (_) async {
        await _loadTasksForFilter(
          currentState.filter,
          emit,
          feedbackMessage: 'Check progress berhasil disimpan',
        );
      },
    );
  }

  Future<void> _onUpdateTaskCheckpointSession(
    UpdateTaskCheckpointSession event,
    Emitter<TaskViewState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TaskViewLoaded) return;

    emit(
      currentState.copyWith(
        actionTaskId: event.planDailyId,
        clearFeedback: true,
        isFeedbackError: false,
      ),
    );

    final result = await repository.updateCheckpointSession(
      planDailyId: event.planDailyId,
      sessionNumber: event.sessionNumber,
      startWorkTime: event.startWorkTime,
      finishWorkTime: event.finishWorkTime,
      progress: event.progress,
      checkpointTime: event.checkpointTime,
      jobStatus: event.jobStatus,
    );

    await result.fold(
      (failure) async {
        emit(
          currentState.copyWith(
            clearActionTaskId: true,
            feedbackMessage: failure.message ?? 'Gagal mengubah check progress',
            isFeedbackError: true,
          ),
        );
      },
      (_) async {
        await _loadTasksForFilter(
          currentState.filter,
          emit,
          feedbackMessage: 'Check progress berhasil diubah',
        );
      },
    );
  }

  Future<void> _onValidateCheckpointSession(
    ValidateCheckpointSession event,
    Emitter<TaskViewState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TaskViewLoaded) return;

    emit(
      currentState.copyWith(
        actionTaskId: event.planDailyId,
        clearFeedback: true,
        isFeedbackError: false,
      ),
    );

    final result = await repository.validateCheckpointSession(
      planDailyId: event.planDailyId,
      sessionNumber: event.sessionNumber,
    );

    await result.fold(
      (failure) async {
        emit(
          currentState.copyWith(
            clearActionTaskId: true,
            feedbackMessage:
                failure.message ?? 'Gagal memvalidasi check progress',
            isFeedbackError: true,
          ),
        );
      },
      (_) async {
        await _loadTasksForFilter(
          currentState.filter,
          emit,
          feedbackMessage: 'Check progress berhasil divalidasi',
        );
      },
    );
  }

  Future<void> _onValidateTaskFinal(
    ValidateTaskFinal event,
    Emitter<TaskViewState> emit,
  ) async {
    final currentState = state;
    if (currentState is! TaskViewLoaded) return;

    emit(
      currentState.copyWith(
        actionTaskId: event.planDailyId,
        clearFeedback: true,
        isFeedbackError: false,
      ),
    );

    final result = await repository.validateTask(
      planDailyId: event.planDailyId,
      approved: true,
      note: event.note,
    );

    await result.fold(
      (failure) async {
        emit(
          currentState.copyWith(
            clearActionTaskId: true,
            feedbackMessage: failure.message ?? 'Gagal memvalidasi final task',
            isFeedbackError: true,
          ),
        );
      },
      (_) async {
        await _loadTasksForFilter(
          currentState.filter,
          emit,
          feedbackMessage: 'Validasi final task berhasil disimpan',
        );
      },
    );
  }
}
