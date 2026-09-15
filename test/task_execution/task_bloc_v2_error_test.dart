/*
Tujuan: Mengunci refresh pattern TaskBloc saat command Job Plan V2 conflict.
Caller: Flutter test runner.
Dependensi: TaskBloc, TaskRepository fake, StartJobUseCase.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/core/services/upload_service.dart';
import 'package:sm_system/features/task_execution/data/datasources/task_draft_storage.dart';
import 'package:sm_system/features/task_execution/domain/entities/task_draft.dart';
import 'package:sm_system/features/task_execution/domain/entities/task_entity.dart';
import 'package:sm_system/features/task_execution/domain/repositories/task_repository.dart';
import 'package:sm_system/features/task_execution/domain/usecases/start_job_usecase.dart';
import 'package:sm_system/features/task_execution/presentation/bloc/task_bloc.dart';
import 'package:sm_system/features/task_execution/presentation/bloc/task_event.dart';
import 'package:sm_system/features/task_execution/presentation/bloc/task_state.dart';

void main() {
  test('V2 start conflict refreshes tasks and keeps mutation failed', () async {
    final repo = _Repo();
    final bloc = TaskBloc(
      taskRepository: repo,
      startJobUseCase: StartJobUseCase(repository: repo),
      taskDraftStorage: _DraftStorage(),
      uploadService: _UploadService(),
    );

    bloc.add(LoadTodaysTasksEvent(date: DateTime(2026, 9, 15)));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<TaskLoading>(), isA<TaskLoaded>()]),
    );

    bloc.add(const StartJobEvent(plandailyId: 'plan-v2-1'));
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<TaskActionLoading>(),
        predicate<TaskActionError>((state) {
          return state.message.contains('PIC masih menjalankan') &&
              state.tasks.single.version == 8;
        }),
      ]),
    );
    await bloc.close();
  });
}

class _Repo implements TaskRepository {
  int loads = 0;

  @override
  Future<Either<Failure, List<TaskEntity>>> getTodaysTasks({
    required DateTime date,
    required bool isOvertime,
    bool forceOwnOnly = false,
  }) async {
    loads += 1;
    return right([_task(version: loads == 1 ? 7 : 8)]);
  }

  @override
  Future<Either<Failure, TaskEntity>> startJobExecution(
    String plandailyId, {
    String? photoBefore1Path,
    String? photoBefore2Path,
    bool isV2 = false,
    String? commandId,
    int? expectedVersion,
    String? v2Action,
  }) async {
    return left(const ClientFailure(errorCode: 'ERR_EMPLOYEE_ALREADY_RUNNING'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DraftStorage extends TaskDraftStorage {
  @override
  Future<Map<String, TaskDraft>> getAllDrafts() async => {};
}

class _UploadService implements UploadService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TaskEntity _task({required int version}) {
  return TaskEntity(
    plandailyId: 'plan-v2-1',
    coreId: 'core-1',
    carId: 'unit-1',
    unitName: 'MB220S',
    panelName: 'Dashboard',
    jobName: 'Repair',
    divisionName: 'Interior',
    status: 'PLAN',
    isPanelLocked: false,
    dailyTargetHours: 4,
    targetHoursRevised: 4,
    remainingHours: 4,
    taskDate: '2026-09-15',
    createdAt: '2026-09-15T08:00:00+07:00',
    taskCategory: 'COUNTDOWN',
    jobDescription: 'Repair',
    ownerName: 'SM',
    totalActualHours: 0,
    approvalState: 'APPROVED',
    executionState: 'NOT_STARTED',
    ledgerState: 'UNMATERIALIZED',
    projectionReady: true,
    version: version,
  );
}
