/// Local dummy data source for MVP development and testing.
///
/// Implements [RemoteTaskDataSource] with in-memory data based on
/// the SM Restoration ERD seed data. Simulates network latency
/// and demonstrates all three task states:
/// 1. In Progress — panel locked by current user
/// 2. To Do — panel available (can start)
/// 3. To Do — panel locked by another mechanic (cannot start)
library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';
import '../../../../core/session/session_manager.dart';
import '../models/task_model.dart';
import 'remote_task_datasource.dart';
import '../../domain/entities/task_execution_log.dart';

/// Local data source that returns dummy task data without network calls.
///
/// Task data references real master data from [DummyCars], [DummyPanels],
/// [DummyJobTypes], [DummyEmployees] defined in `data/dummy_data.dart`.
///
/// Demonstrates mechanic tasks for **Adam Hafiyan** (ADAM, Mechanic div)
/// across 3 different cars with varying states:
///   1. In Progress — JAGUAR XK120, Ganti Timing Chain Kit
///   2. To Do, available — FERRARI F355, Skir Klep & Ganti Seal
///   3. To Do, locked — MB 190 SL, Ganti Shockbreaker (locked by Aries)
///   4. Completed — PORSCHE 911, Kuras Oli Mesin & Ganti Filter
class LocalTaskDataSource implements RemoteTaskDataSource {
  LocalTaskDataSource({
    required this.store,
    required this.sessionManager,
  });

  final LocalMockApiStore store;
  final SessionManager sessionManager;

  @override
  Future<List<TaskModel>> getTodaysTasks({
    required DateTime date,
    required bool isOvertime,
  }) async {
    // Simulate network latency.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final tasks = await _loadTasks();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final overtimeTaskIds = tasks
        .where((task) => (task['isOvertime'] as bool?) == true)
        .map((item) => item['plandailyId'] as String)
        .toSet();
    final currentUserId = sessionManager.userId;
    final role = sessionManager.role;
    final visibleTasks = tasks.where((task) {
      if (role == 'op' && currentUserId != null && currentUserId.isNotEmpty) {
        return task['assignedUserId'] == currentUserId;
      }
      return true;
    });
    return visibleTasks.map(TaskModel.fromJson).where((task) {
      final matchesDate = task.taskDate == dateStr;
      final taskIsOvertime = overtimeTaskIds.contains(task.plandailyId);
      return matchesDate && taskIsOvertime == isOvertime;
    }).toList();
  }

  @override
  Future<TaskModel> getTaskById(String plandailyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final tasks = await _loadTasks();
    final task = tasks.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['plandailyId'] == plandailyId,
          orElse: () => null,
        );
    if (task == null) {
      throw DataFormatException(message: 'Task tidak ditemukan: $plandailyId');
    }
    return TaskModel.fromJson(task);
  }

  @override
  Future<TaskModel> startJobExecution(
    String plandailyId, {
    String? photoBefore1Path,
    String? photoBefore2Path,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final tasks = await _loadTasks();
    final index = tasks.indexWhere((t) => t['plandailyId'] == plandailyId);
    if (index == -1) {
      throw DataFormatException(message: 'Task tidak ditemukan: $plandailyId');
    }

    final task = TaskModel.fromJson(tasks[index]);

    // Business Rule #2: Cannot start if panel is locked by another mechanic.
    if (task.isPanelLocked && task.lockedByName != null) {
      throw ClientException(
        statusCode: 423,
        message: 'Panel dikunci oleh ${task.lockedByName}',
      );
    }

    final updated = task.copyWith(
      status: 'PROSES',
      isPanelLocked: true,
      startedAt: DateTime.now().toIso8601String(),
      completedAt: null,
      hasMonitoringRecord: false,
    );
    tasks[index] = {
      ...updated.toJson(),
      'assignedUserId': tasks[index]['assignedUserId'],
      'assignedTo': tasks[index]['assignedTo'],
    };
    await _saveTasks(tasks);
    await _syncViewTaskStatus(plandailyId: plandailyId, status: 'PROSES');
    return updated;
  }

  @override
  Future<TaskModel> finishJobExecution(
    String plandailyId, {
    int breakDurationMinutes = 60,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final tasks = await _loadTasks();
    final index = tasks.indexWhere((t) => t['plandailyId'] == plandailyId);
    if (index == -1) {
      throw DataFormatException(message: 'Task tidak ditemukan: $plandailyId');
    }

    final task = TaskModel.fromJson(tasks[index]);
    final nowStr = DateTime.now().toIso8601String();
    final newRemaining =
        (task.remainingHours - task.dailyTargetHours).clamp(0.0, 9999.0);

    final updated = task.copyWith(
      status: newRemaining <= 0 ? 'DONE' : 'PROSES',
      isPanelLocked: false,
      completedAt: nowStr,
      remainingHours: newRemaining,
    );
    tasks[index] = {
      ...updated.toJson(),
      'assignedUserId': tasks[index]['assignedUserId'],
      'assignedTo': tasks[index]['assignedTo'],
    };
    await _saveTasks(tasks);
    await _syncViewTaskStatus(
      plandailyId: plandailyId,
      status: newRemaining <= 0 ? 'DONE' : 'PROSES',
    );
    return updated;
  }

  @override
  Future<TaskModel> submitTaskExecution(TaskExecutionLog executionLog) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final tasks = await _loadTasks();
    final index =
        tasks.indexWhere((t) => t['plandailyId'] == executionLog.plandailyId);
    if (index == -1) {
      throw DataFormatException(
          message: 'Task tidak ditemukan: ${executionLog.plandailyId}');
    }

    final taskRow = tasks[index];
    final task = TaskModel.fromJson(taskRow);

    if (task.hasMonitoringRecord) {
      throw ClientException(
        statusCode: 409,
        message:
            'Progress task ini sudah tercatat dan tidak bisa diinput ulang.',
      );
    }

    // If starting a new job, check panel lock
    if (task.startedAt == null) {
      if (task.isPanelLocked && task.lockedByName != null) {
        throw ClientException(
          statusCode: 423,
          message: 'Panel dikunci oleh ${task.lockedByName}',
        );
      }
    }

    final normalizedStatus = executionLog.status.trim().toLowerCase();
    final isCancelled = normalizedStatus == 'cancel';
    final isCompleted =
        normalizedStatus == 'done' || executionLog.progressPercent >= 100;

    // Calculate new remaining hours based on progress
    final newRemaining =
        task.targetHoursRevised * (1 - executionLog.progressPercent / 100);

    final TaskModel updated;
    if (isCancelled || isCompleted) {
      // Finishing or cancelling: unlock panel and stop further execution on this task.
      updated = task.copyWith(
        status: isCancelled ? 'CANCEL' : 'DONE',
        isPanelLocked: false,
        startedAt: task.startedAt ?? executionLog.startTime,
        completedAt: executionLog.finishTime,
        remainingHours: 0.0,
        hasMonitoringRecord: true,
      );
    } else {
      // Progress recorded once, then locked for monitoring only.
      updated = task.copyWith(
        status: 'PROSES',
        isPanelLocked: true,
        startedAt: task.startedAt ?? executionLog.startTime,
        completedAt: null,
        remainingHours: newRemaining.clamp(0.0, task.targetHoursRevised),
        hasMonitoringRecord: true,
      );
    }
    tasks[index] = {
      ...updated.toJson(),
      'assignedUserId': taskRow['assignedUserId'],
      'assignedTo': taskRow['assignedTo'],
    };
    await _saveTasks(tasks);
    await _syncViewTaskStatus(
      plandailyId: executionLog.plandailyId,
      status: isCancelled ? 'CANCEL' : (isCompleted ? 'SUBMITTED' : 'PROSES'),
    );
    await _syncCountdownAndQc(
      taskRow: tasks[index],
      executionLog: executionLog,
    );
    return updated;
  }

  @override
  Future<TaskModel> recordBreak(
    String plandailyId, {
    required int breakDurationMinutes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return getTaskById(plandailyId);
  }

  @override
  Future<TaskModel> uploadProgressPhoto(
    String plandailyId, {
    required String photoUrl,
    String photoType = 'progress',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return getTaskById(plandailyId);
  }

  @override
  Future<String> getUploadTicket({required String filename}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return 'https://example.local/upload/$filename';
  }

  Future<List<Map<String, dynamic>>> _loadTasks() {
    return store.readList(
      key: LocalMockApiStore.taskExecutionKey,
      seedBuilder: DummyTaskExecutionData.seedTasks,
    );
  }

  Future<void> _saveTasks(List<Map<String, dynamic>> tasks) {
    return store.writeList(
      key: LocalMockApiStore.taskExecutionKey,
      value: tasks,
    );
  }

  Future<void> _syncViewTaskStatus({
    required String plandailyId,
    required String status,
  }) async {
    final viewTasks = await store.readList(
      key: LocalMockApiStore.taskViewKey,
      seedBuilder: DummyTaskViewData.seedTasks,
    );
    final index =
        viewTasks.indexWhere((item) => item['planDailyId'] == plandailyId);
    if (index == -1) return;
    viewTasks[index]['status'] = status;
    await store.writeList(
      key: LocalMockApiStore.taskViewKey,
      value: viewTasks,
    );
  }

  Future<void> _syncCountdownAndQc({
    required Map<String, dynamic> taskRow,
    required TaskExecutionLog executionLog,
  }) async {
    final coreId = taskRow['coreId'] as String? ?? '';
    if (coreId.isEmpty) return;

    final countdowns = await store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );
    final details = await store.readGroupedList(
      key: LocalMockApiStore.countdownDetailsKey,
      seedBuilder: DummyCountdownData.seedDetails,
    );
    final units = await store.readList(
      key: LocalMockApiStore.countdownUnitsKey,
      seedBuilder: DummyCountdownData.units,
    );

    String? carId;
    Map<String, dynamic>? countdownItem;
    for (final entry in countdowns.entries) {
      final matchIndex = entry.value.indexWhere((item) => item['id'] == coreId);
      if (matchIndex >= 0) {
        carId = entry.key;
        countdownItem = entry.value[matchIndex];
        final targetHours =
            (countdownItem['targetHoursRevised'] as num).toDouble();
        final durationHours = _calculateWorkedHours(executionLog);
        final actualHours =
            executionLog.isDone || executionLog.progressPercent >= 100
                ? targetHours
                : (targetHours * (executionLog.progressPercent / 100))
                    .clamp(0.0, targetHours);
        countdownItem['totalActualHours'] =
            actualHours > 0 ? actualHours : durationHours;
        countdownItem['remainingHours'] = (targetHours -
                (countdownItem['totalActualHours'] as num).toDouble())
            .clamp(0.0, targetHours);
        countdownItem['actualProgressPercent'] =
            executionLog.progressPercent.round().clamp(0, 100);
        countdownItem['status'] =
            executionLog.isDone || executionLog.progressPercent >= 100
                ? 'DONE'
                : 'PROSES';

        final detailList = details[coreId] ?? <Map<String, dynamic>>[];
        detailList.add({
          'id': 'detail-${DateTime.now().millisecondsSinceEpoch}',
          'countdownId': coreId,
          'employeeName': taskRow['assignedTo'] as String? ?? '-',
          'job': taskRow['divisionName'] as String? ?? '-',
          'detailJob': taskRow['customDescription'] as String? ?? '-',
          'workDate': taskRow['taskDate'] as String? ?? '',
          'startTime': _clockFromIso(executionLog.startTime),
          'finishTime': _clockFromIso(executionLog.finishTime),
          'targetHours':
              (taskRow['dailyTargetHours'] as num?)?.toDouble() ?? 0.0,
          'durationHours': durationHours,
          'remainingHours': countdownItem['remainingHours'],
          'overtimeHours':
              (taskRow['isOvertime'] == true) ? durationHours : 0.0,
          'percentage': executionLog.progressPercent,
          'status': executionLog.isDone ? 'DONE' : 'PROSES',
        });
        details[coreId] = detailList;
        break;
      }
    }

    if (carId == null || countdownItem == null) return;

    await store.writeGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      value: countdowns,
    );
    await store.writeGroupedList(
      key: LocalMockApiStore.countdownDetailsKey,
      value: details,
    );

    _recalculateUnit(units, carId, countdowns[carId] ?? const []);
    await store.writeList(
      key: LocalMockApiStore.countdownUnitsKey,
      value: units,
    );

    if (executionLog.isDone || executionLog.progressPercent >= 100) {
      final qcItems = await store.readList(
        key: LocalMockApiStore.qcItemsKey,
        seedBuilder: QcDummyData.seedAll,
      );
      final existingQc = qcItems.indexWhere((item) => item['coreId'] == coreId);
      if (existingQc == -1) {
        qcItems.insert(0, _qcItemFromTask(taskRow));
        await store.writeList(
          key: LocalMockApiStore.qcItemsKey,
          value: qcItems,
        );
      }
    }
  }

  void _recalculateUnit(
    List<Map<String, dynamic>> units,
    String carId,
    List<Map<String, dynamic>> countdownItems,
  ) {
    final unitIndex = units.indexWhere((item) => item['carId'] == carId);
    if (unitIndex == -1 || countdownItems.isEmpty) return;
    final totalProgress = countdownItems.fold<int>(
      0,
      (sum, item) =>
          sum + ((item['actualProgressPercent'] as num?)?.toInt() ?? 0),
    );
    final average = (totalProgress / countdownItems.length).round();
    units[unitIndex]['progress'] = average;
    units[unitIndex]['status'] =
        countdownItems.every((item) => item['status'] == 'DONE')
            ? 'DONE'
            : 'PROSES';
  }

  Map<String, dynamic> _qcItemFromTask(Map<String, dynamic> taskRow) {
    final division = taskRow['divisionName'] as String? ?? '-';
    final kd = DummyEmployees.all.firstWhere(
      (item) => item['role'] == 'kd' && item['division'] == division,
      orElse: () => <String, dynamic>{},
    );
    final advisor = DummyEmployees.all.firstWhere(
      (item) => item['role'] == 'adv',
      orElse: () => <String, dynamic>{},
    );
    return {
      'qcId': 'qc-${DateTime.now().millisecondsSinceEpoch}',
      'coreId': taskRow['coreId'] as String,
      'carId': taskRow['carId'] as String? ?? '',
      'unitName': taskRow['unitName'] as String? ?? '-',
      'panelName': taskRow['panelName'] as String? ?? '-',
      'jobName': taskRow['jobName'] as String? ?? '-',
      'mechanicId': taskRow['assignedUserId'] as String? ?? '',
      'mechanicName': taskRow['assignedTo'] as String? ?? '-',
      'mechanicDivision': division,
      'inspectorId': kd['id'] as String?,
      'advisorId': advisor['id'] as String?,
      'inspectionDate': DateTime.now().toIso8601String(),
      'totalActualHours':
          (taskRow['targetHoursRevised'] as num?)?.toDouble() ?? 0.0,
      'targetHoursRevised':
          (taskRow['targetHoursRevised'] as num?)?.toDouble() ?? 0.0,
      'qcStatus': 'PENDING',
      'date': taskRow['taskDate'] as String? ?? '',
      'qcChecklist': [
        {'item': 'Finishing visual', 'passed': null},
        {'item': 'Kerapihan pemasangan', 'passed': null},
        {'item': 'Kesesuaian fungsi', 'passed': null},
      ],
      'qcNotes': null,
    };
  }

  double _calculateWorkedHours(TaskExecutionLog log) {
    final start = DateTime.tryParse(log.startTime);
    final finish = DateTime.tryParse(log.finishTime);
    if (start == null || finish == null || !finish.isAfter(start)) {
      return 0.0;
    }
    final workedMinutes =
        finish.difference(start).inMinutes - log.breakDurationMinutes;
    return (workedMinutes <= 0 ? 0 : workedMinutes / 60).toDouble();
  }

  String _clockFromIso(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '00:00';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
