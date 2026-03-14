import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/task_draft_storage.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/start_job_usecase.dart';
import 'task_event.dart';
import 'task_state.dart';
import '../../domain/entities/task_entity.dart';

/// TaskBloc manages the state of the mechanic's task execution feature.
///
/// Two-step flow:
/// 1. **Mulai** → saves [TaskDraft] locally (startTime + photoBefore) — NO API call
/// 2. **Submit** → fills remaining fields → POST to API → deletes draft
///
/// Dependencies:
/// - [TaskRepository]: For loading tasks and finishing jobs
/// - [StartJobUseCase]: For starting job execution (with business rule validation)
/// - [TaskDraftStorage]: For persisting/loading local drafts
class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository taskRepository;
  final StartJobUseCase startJobUseCase;
  final TaskDraftStorage taskDraftStorage;
  DateTime _selectedDate = DateTime.now();
  bool _isOvertime = false;

  TaskBloc({
    required this.taskRepository,
    required this.startJobUseCase,
    required this.taskDraftStorage,
  }) : super(const TaskInitial()) {
    on<LoadTodaysTasksEvent>(_onLoadTodaysTasks);
    on<RefreshTasksEvent>(_onRefreshTasks);
    on<StartJobEvent>(_onStartJob);
    on<StartTaskFlowEvent>(_onStartTaskFlow);
    on<FinishJobEvent>(_onFinishJob);
    on<SaveDraftEvent>(_onSaveDraft);
    on<LoadDraftsEvent>(_onLoadDrafts);
    on<SubmitExecutionEvent>(_onSubmitExecution);
  }

  // ─────────────────────────────────────────────────
  // DRAFT HELPERS
  // ─────────────────────────────────────────────────

  /// Current drafts map from state.
  Map<String, TaskDraft> _getCurrentDrafts() {
    final s = state;
    if (s is TaskLoaded) return s.drafts;
    if (s is TaskActionLoading) return s.drafts;
    if (s is TaskActionSuccess) return s.drafts;
    if (s is TaskActionError) return s.drafts;
    return {};
  }

  // ─────────────────────────────────────────────────
  // LOAD TASKS
  // ─────────────────────────────────────────────────

  /// Handles loading today's tasks from the API.
  /// Also loads saved drafts from local storage.
  Future<void> _onLoadTodaysTasks(
    LoadTodaysTasksEvent event,
    Emitter<TaskState> emit,
  ) async {
    _selectedDate = event.date;
    _isOvertime = event.isOvertime;
    emit(const TaskLoading());

    final results = await Future.wait([
      taskRepository.getTodaysTasks(
        date: _selectedDate,
        isOvertime: _isOvertime,
      ),
      taskDraftStorage.getAllDrafts(),
    ]);

    final taskResult = results[0] as dynamic;
    final drafts = results[1] as Map<String, TaskDraft>;

    taskResult.fold(
      (failure) => emit(TaskError(message: failure.message ?? 'Gagal memuat tugas')),
      (tasks) => emit(TaskLoaded(tasks: tasks as List<TaskEntity>, drafts: drafts)),
    );
  }

  /// Handles pull-to-refresh.
  Future<void> _onRefreshTasks(
    RefreshTasksEvent event,
    Emitter<TaskState> emit,
  ) async {
    final currentDrafts = _getCurrentDrafts();
    final result = await taskRepository.getTodaysTasks(
      date: _selectedDate,
      isOvertime: _isOvertime,
    );
    // Also refresh drafts
    final drafts = await taskDraftStorage.getAllDrafts();

    result.fold(
      (failure) {
        final currentState = state;
        if (currentState is TaskLoaded) {
          emit(TaskActionError(
            tasks: currentState.tasks,
            drafts: currentDrafts,
            message: failure.message ?? 'Gagal memperbarui tugas',
          ));
        } else {
          emit(TaskError(message: failure.message ?? 'Gagal memperbarui tugas'));
        }
      },
      (tasks) => emit(TaskLoaded(tasks: tasks, drafts: drafts)),
    );
  }

  // ─────────────────────────────────────────────────
  // DRAFT FLOW
  // ─────────────────────────────────────────────────

  /// Saves a local draft when mechanic presses "Mulai".
  /// No API call — just saves startTime + photoBefore locally.
  Future<void> _onSaveDraft(
    SaveDraftEvent event,
    Emitter<TaskState> emit,
  ) async {
    final currentTasks = _getCurrentTasks();
    final currentDrafts = _getCurrentDrafts();

    try {
      await taskDraftStorage.saveDraft(event.draft);

      final updatedDrafts = Map<String, TaskDraft>.from(currentDrafts)
        ..[event.draft.plandailyId] = event.draft;

      emit(TaskActionSuccess(
        tasks: currentTasks,
        drafts: updatedDrafts,
        message: 'Pekerjaan dimulai — draft tersimpan',
      ));
    } catch (e) {
      emit(TaskActionError(
        tasks: currentTasks,
        drafts: currentDrafts,
        message: 'Gagal menyimpan draft: $e',
      ));
    }
  }

  /// Loads all drafts from local storage (e.g. on startup).
  Future<void> _onLoadDrafts(
    LoadDraftsEvent event,
    Emitter<TaskState> emit,
  ) async {
    final currentTasks = _getCurrentTasks();
    final drafts = await taskDraftStorage.getAllDrafts();
    emit(TaskLoaded(tasks: currentTasks, drafts: drafts));
  }

  // ─────────────────────────────────────────────────
  // JOB ACTIONS
  // ─────────────────────────────────────────────────

  /// Handles starting a job execution.
  Future<void> _onStartJob(
    StartJobEvent event,
    Emitter<TaskState> emit,
  ) async {
    final currentTasks = _getCurrentTasks();
    final currentDrafts = _getCurrentDrafts();

    emit(TaskActionLoading(
      tasks: currentTasks,
      drafts: currentDrafts,
      actionTaskId: event.plandailyId,
    ));

    final result = await startJobUseCase(
      StartJobParams(plandailyId: event.plandailyId),
    );

    await result.fold(
      (failure) async {
        emit(TaskActionError(
          tasks: currentTasks,
          drafts: currentDrafts,
          message: failure.message ?? 'Gagal memulai pekerjaan',
        ));
      },
      (updatedTask) async {
        final refreshResult = await taskRepository.getTodaysTasks(
          date: _selectedDate,
          isOvertime: _isOvertime,
        );
        refreshResult.fold(
          (failure) {
            final updatedTasks = _updateTaskInList(currentTasks, updatedTask);
            emit(TaskActionSuccess(
              tasks: updatedTasks,
              drafts: currentDrafts,
              message: 'Pekerjaan dimulai: ${updatedTask.jobName}',
            ));
          },
          (freshTasks) {
            emit(TaskActionSuccess(
              tasks: freshTasks,
              drafts: currentDrafts,
              message: 'Pekerjaan dimulai: ${updatedTask.jobName}',
            ));
          },
        );
      },
    );
  }

  Future<void> _onStartTaskFlow(
    StartTaskFlowEvent event,
    Emitter<TaskState> emit,
  ) async {
    final currentTasks = _getCurrentTasks();
    final currentDrafts = _getCurrentDrafts();

    emit(TaskActionLoading(
      tasks: currentTasks,
      drafts: currentDrafts,
      actionTaskId: event.plandailyId,
    ));

    final result = await startJobUseCase(
      StartJobParams(plandailyId: event.plandailyId),
    );

    await result.fold(
      (failure) async {
        emit(TaskActionError(
          tasks: currentTasks,
          drafts: currentDrafts,
          message: failure.message ?? 'Gagal memulai pekerjaan',
        ));
      },
      (updatedTask) async {
        await taskDraftStorage.saveDraft(event.draft);
        final updatedDrafts = Map<String, TaskDraft>.from(currentDrafts)
          ..[event.draft.plandailyId] = event.draft;

        final refreshResult = await taskRepository.getTodaysTasks(
          date: _selectedDate,
          isOvertime: _isOvertime,
        );

        refreshResult.fold(
          (failure) {
            final updatedTasks = _updateTaskInList(currentTasks, updatedTask);
            emit(TaskActionSuccess(
              tasks: updatedTasks,
              drafts: updatedDrafts,
              message: 'Pekerjaan dimulai: ${updatedTask.jobName}',
            ));
          },
          (freshTasks) {
            emit(TaskActionSuccess(
              tasks: freshTasks,
              drafts: updatedDrafts,
              message: 'Pekerjaan dimulai: ${updatedTask.jobName}',
            ));
          },
        );
      },
    );
  }

  /// Handles finishing a job execution.
  Future<void> _onFinishJob(
    FinishJobEvent event,
    Emitter<TaskState> emit,
  ) async {
    final currentTasks = _getCurrentTasks();
    final currentDrafts = _getCurrentDrafts();

    emit(TaskActionLoading(
      tasks: currentTasks,
      drafts: currentDrafts,
      actionTaskId: event.plandailyId,
    ));

    final result = await taskRepository.finishJobExecution(event.plandailyId);

    await result.fold(
      (failure) async {
        emit(TaskActionError(
          tasks: currentTasks,
          drafts: currentDrafts,
          message: failure.message ?? 'Gagal menyelesaikan pekerjaan',
        ));
      },
      (updatedTask) async {
        final refreshResult = await taskRepository.getTodaysTasks(
          date: _selectedDate,
          isOvertime: _isOvertime,
        );
        refreshResult.fold(
          (failure) {
            final updatedTasks = _updateTaskInList(currentTasks, updatedTask);
            emit(TaskActionSuccess(
              tasks: updatedTasks,
              drafts: currentDrafts,
              message: 'Pekerjaan selesai: ${updatedTask.jobName}',
            ));
          },
          (freshTasks) {
            emit(TaskActionSuccess(
              tasks: freshTasks,
              drafts: currentDrafts,
              message: 'Pekerjaan selesai: ${updatedTask.jobName}',
            ));
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // SUBMIT EXECUTION (POST TO API + DELETE DRAFT)
  // ─────────────────────────────────────────────────

  /// Submits the full execution log to the API.
  /// On success, deletes the local draft for this task.
  Future<void> _onSubmitExecution(
    SubmitExecutionEvent event,
    Emitter<TaskState> emit,
  ) async {
    final log = event.executionLog;
    final currentTasks = _getCurrentTasks();
    final currentDrafts = _getCurrentDrafts();

    emit(TaskActionLoading(
      tasks: currentTasks,
      drafts: currentDrafts,
      actionTaskId: log.plandailyId,
    ));

    final result = await taskRepository.submitTaskExecution(log);

    await result.fold(
      (failure) async {
        emit(TaskActionError(
          tasks: currentTasks,
          drafts: currentDrafts,
          message: failure.message ?? 'Gagal menyimpan eksekusi',
        ));
      },
      (updatedTask) async {
        // Delete local draft after successful API submission
        await taskDraftStorage.deleteDraft(log.plandailyId);
        final updatedDrafts = Map<String, TaskDraft>.from(currentDrafts)
          ..remove(log.plandailyId);

        final String msg;
        if (log.isDone) {
          msg = 'Pekerjaan selesai: ${updatedTask.jobName}';
        } else if (log.status == 'cancel') {
          msg = 'Pekerjaan dibatalkan: ${updatedTask.jobName}';
        } else {
          msg = 'Eksekusi disimpan: ${updatedTask.jobName} (${log.progressPercent.toInt()}%)';
        }

        final refreshResult = await taskRepository.getTodaysTasks(
          date: _selectedDate,
          isOvertime: _isOvertime,
        );
        refreshResult.fold(
          (failure) {
            final updatedTasks = _updateTaskInList(currentTasks, updatedTask);
            emit(TaskActionSuccess(
              tasks: updatedTasks,
              drafts: updatedDrafts,
              message: msg,
            ));
          },
          (freshTasks) {
            emit(TaskActionSuccess(
              tasks: freshTasks,
              drafts: updatedDrafts,
              message: msg,
            ));
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────

  /// Extracts current task list from the current state.
  List<TaskEntity> _getCurrentTasks() {
    final currentState = state;
    if (currentState is TaskLoaded) return currentState.tasks;
    if (currentState is TaskActionLoading) return currentState.tasks;
    if (currentState is TaskActionSuccess) return currentState.tasks;
    if (currentState is TaskActionError) return currentState.tasks;
    return [];
  }

  /// Updates a single task in the list by plandailyId.
  List<TaskEntity> _updateTaskInList(
    List<TaskEntity> tasks,
    TaskEntity updatedTask,
  ) {
    return tasks.map((task) {
      if (task.plandailyId == updatedTask.plandailyId) {
        return updatedTask;
      }
      return task;
    }).toList();
  }
}
