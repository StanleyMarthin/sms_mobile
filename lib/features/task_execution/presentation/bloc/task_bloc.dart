import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/alarm_timer_service.dart';
import '../../../../core/services/upload_service.dart';
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
  final UploadService uploadService;
  DateTime _selectedDate = DateTime.now();
  bool _isOvertime = false;

  Timer? _jobTimer;
  final Map<String, Set<int>> _playedAlarms = {};

  TaskBloc({
    required this.taskRepository,
    required this.startJobUseCase,
    required this.taskDraftStorage,
    required this.uploadService,
  }) : super(const TaskInitial()) {
    on<LoadTodaysTasksEvent>(_onLoadTodaysTasks);
    on<RefreshTasksEvent>(_onRefreshTasks);
    on<StartJobEvent>(_onStartJob);
    on<StartTaskFlowEvent>(_onStartTaskFlow);
    on<FinishJobEvent>(_onFinishJob);
    on<SaveDraftEvent>(_onSaveDraft);
    on<LoadDraftsEvent>(_onLoadDrafts);
    on<SubmitExecutionEvent>(_onSubmitExecution);

    // Mulai background polling untuk alarm (Cek setiap 15 detik)
    _jobTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkAlarms());
  }

  @override
  Future<void> close() {
    _jobTimer?.cancel();
    return super.close();
  }

  void _checkAlarms() {
    final s = state;
    // Hanya bisa membaca tasks saat state Loaded / Success dengan array TaskEntity di dalamnya.
    List<TaskEntity> tasks = [];
    if (s is TaskLoaded) tasks = s.tasks;
    if (s is TaskActionSuccess) tasks = s.tasks;
    if (s is TaskActionError) tasks = s.tasks;

    if (tasks.isEmpty) return;

    for (var task in tasks) {
      if (task.isInProgress && task.startedAt != null) {
        final start = DateTime.tryParse(task.startedAt!);
        if (start != null) {
          final now = DateTime.now().toUtc();
          // Gunakan UTC difference
          final diffMinutes = now.difference(start).inMinutes;

          final targetMinutes = (task.dailyTargetHours * 60).toInt();
          if (targetMinutes <= 0) continue;

          final remaining = targetMinutes - diffMinutes;

          // Threshold check
          if (remaining <= 10 && remaining > 5) {
            _triggerAlarm(task.plandailyId, 10, 1);
          } else if (remaining <= 5 && remaining > 0) {
            _triggerAlarm(task.plandailyId, 5, 2);
          } else if (remaining <= 0) {
            _triggerAlarm(task.plandailyId, 0, 3);
          }
        }
      }
    }
  }

  void _triggerAlarm(String taskId, int minuteMark, int times) {
    _playedAlarms.putIfAbsent(taskId, () => <int>{});
    if (!_playedAlarms[taskId]!.contains(minuteMark)) {
      _playedAlarms[taskId]!.add(minuteMark);
      AlarmTimerService().playReminder(times);
    }
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
      (failure) =>
          emit(TaskError(message: failure.message ?? 'Gagal memuat tugas')),
      (tasks) =>
          emit(TaskLoaded(tasks: tasks as List<TaskEntity>, drafts: drafts)),
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
          emit(
              TaskError(message: failure.message ?? 'Gagal memperbarui tugas'));
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

    try {
      String? finalPhotoBeforePath = event.draft.photoBeforePath;

      // Upload if it's a local file (doesn't start with http/https)
      if (finalPhotoBeforePath != null &&
          !finalPhotoBeforePath.startsWith('http')) {
        final task = currentTasks.firstWhere(
          (t) => t.plandailyId == event.plandailyId,
          orElse: () => currentTasks.first,
        );
        final uploadedUrl = await uploadService.uploadPhoto(
          localPath: finalPhotoBeforePath,
          unit: task.unitName,
          division: task.divisionName,
          job: task.jobName,
          panel: task.panelName,
          type: 'bef',
        );
        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          throw Exception('Upload foto before gagal.');
        }
        finalPhotoBeforePath = uploadedUrl;
      }

      final result = await startJobUseCase(
        StartJobParams(
          plandailyId: event.plandailyId,
          photoBefore1Path: finalPhotoBeforePath,
        ),
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
          final storedDraft = event.draft.copyWith(
            photoBeforePath: finalPhotoBeforePath,
          );
          await taskDraftStorage.saveDraft(storedDraft);
          final updatedDrafts = Map<String, TaskDraft>.from(currentDrafts)
            ..[event.draft.plandailyId] = storedDraft;

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
    } catch (e) {
      emit(TaskActionError(
        tasks: currentTasks,
        drafts: currentDrafts,
        message: 'Terjadi kesalahan sistem saat memulai pekerjaan: $e',
      ));
    }
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

    try {
      final task = currentTasks.firstWhere(
        (t) => t.plandailyId == log.plandailyId,
        orElse: () => currentTasks.first,
      );

      String? processUrl = log.photoProcess;
      if (processUrl != null && !processUrl.startsWith('http')) {
        final uploaded = await uploadService.uploadPhoto(
          localPath: processUrl,
          unit: task.unitName,
          division: task.divisionName,
          job: task.jobName,
          panel: task.panelName,
          type: 'pro',
        );
        if (uploaded == null || uploaded.isEmpty) {
          throw Exception('Upload foto progress gagal.');
        }
        processUrl = uploaded;
      }

      String? afterUrl = log.photoAfter;
      if (afterUrl != null && !afterUrl.startsWith('http')) {
        final uploaded = await uploadService.uploadPhoto(
          localPath: afterUrl,
          unit: task.unitName,
          division: task.divisionName,
          job: task.jobName,
          panel: task.panelName,
          type: 'aft',
        );
        if (uploaded == null || uploaded.isEmpty) {
          throw Exception('Upload foto after gagal.');
        }
        afterUrl = uploaded;
      }

      String? beforeUrl = log.photoBefore;
      if (beforeUrl != null && !beforeUrl.startsWith('http')) {
        final uploaded = await uploadService.uploadPhoto(
          localPath: beforeUrl,
          unit: task.unitName,
          division: task.divisionName,
          job: task.jobName,
          panel: task.panelName,
          type: 'bef',
        );
        if (uploaded == null || uploaded.isEmpty) {
          throw Exception('Upload foto before gagal.');
        }
        beforeUrl = uploaded;
      }

      final updatedLog = log.copyWith(
        photoBefore: beforeUrl,
        photoProcess: processUrl,
        photoAfter: afterUrl,
      );

      final result = await taskRepository.submitTaskExecution(updatedLog);

      await result.fold(
        (failure) async {
          emit(TaskActionError(
            tasks: currentTasks,
            drafts: currentDrafts,
            message: failure.message ?? 'Gagal mensubmit pekerjaan',
          ));
        },
        (updatedTask) async {
          await taskDraftStorage.deleteDraft(log.plandailyId);
          final updatedDrafts = Map<String, TaskDraft>.from(currentDrafts)
            ..remove(log.plandailyId);

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
                message: 'Pekerjaan selesai disubmit: ${updatedTask.jobName}',
              ));
            },
            (freshTasks) {
              emit(TaskActionSuccess(
                tasks: freshTasks,
                drafts: updatedDrafts,
                message: 'Pekerjaan selesai disubmit: ${updatedTask.jobName}',
              ));
            },
          );
        },
      );
    } catch (e) {
      emit(TaskActionError(
        tasks: currentTasks,
        drafts: currentDrafts,
        message:
            'Kegagalan upload foto R2: Menghentikan submission otomatis untuk menghindari error referensi dummy local path. Error: $e',
      ));
    }
  }

  // ─────────────────────────────────────────────────
  // COMMON HELPERS
  // ─────────────────────────────────────────────────
  List<TaskEntity> _getCurrentTasks() {
    final s = state;
    if (s is TaskLoaded) return s.tasks;
    if (s is TaskActionLoading) return s.tasks;
    if (s is TaskActionSuccess) return s.tasks;
    if (s is TaskActionError) return s.tasks;
    return [];
  }

  List<TaskEntity> _updateTaskInList(
    List<TaskEntity> tasks,
    TaskEntity updatedTask,
  ) {
    return tasks
        .map((task) =>
            task.plandailyId == updatedTask.plandailyId ? updatedTask : task)
        .toList();
  }
}
