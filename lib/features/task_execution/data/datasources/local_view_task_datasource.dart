// Local/dummy implementation of ViewTaskDataSource.
//
// Simulates the GET /api/v1/tasks endpoint by generating
// tasks from master data and filtering based on session role.
library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/task_filter.dart';
import '../models/view_task_model.dart';
import 'remote_task_datasource.dart';
import 'view_task_datasource.dart';

String _todayFallbackDate() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

/// Local datasource that simulates BE role-based task filtering.
///
/// Filtering rules (mirrors backend logic):
/// - **OP**: plan_daily.user_id = token.user_id
/// - **KD**: plan_daily.division_id = token.division_id
/// - **ADV**: All tasks in supervised divisions (filterable)
/// - **PM**: All tasks (filterable)
class LocalViewTaskDataSource implements ViewTaskDataSource {
  LocalViewTaskDataSource({required this.store});

  final LocalMockApiStore store;

  @override
  Future<List<ViewTaskModel>> getViewTasks(TaskFilter filter) async {
    // Simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final session = sl<SessionManager>();
    final role = session.role;
    final userId = session.userId;
    final divisionId = session.divisionId;
    final rawTasks = await _loadRawTasks();
    final overtimeTaskIds = _overtimeTaskIds(rawTasks);
    final taskDates = _taskDates(rawTasks);

    // Start with all tasks and apply role-based filtering
    List<ViewTaskModel> result = List.from(_allTasks(rawTasks));

    // ── Role-based filtering (simulates BE logic) ──────────
    switch (role) {
      case 'op':
        // OP: Only sees own tasks
        result = result
            .where((t) => t.employee.employeeId == userId)
            .toList();
        break;

      case 'kd':
        // KD: Sees all tasks in their division
        result = result
            .where((t) =>
                t.division.divisionId == divisionId.toString())
            .toList();
        break;

      case 'adv':
        // ADV: Sees supervised divisions (for demo: MECHANIC, BODY WORK, INTERIOR)
        // In production, this comes from a supervisor-division mapping table
        final supervisedDivisions = _getAdvisorDivisions(divisionId);
        result = result
            .where((t) => supervisedDivisions
                .contains(int.tryParse(t.division.divisionId)))
            .toList();

        // Apply optional filters
        if (filter.divisionId != null) {
          result = result
              .where((t) => t.division.divisionId == filter.divisionId)
              .toList();
        }
        if (filter.unitId != null) {
          result = result
              .where((t) => t.unit.unitId == filter.unitId)
              .toList();
        }
        break;

      case 'pm':
        // PM: Sees all tasks, apply optional filters
        if (filter.divisionId != null) {
          result = result
              .where((t) => t.division.divisionId == filter.divisionId)
              .toList();
        }
        if (filter.unitId != null) {
          result = result
              .where((t) => t.unit.unitId == filter.unitId)
              .toList();
        }
        break;
    }

    // ── Filter by task type ────────────────────────────────
    final dateStr =
        '${filter.date.year}-${filter.date.month.toString().padLeft(2, '0')}-${filter.date.day.toString().padLeft(2, '0')}';
    result = result
      .where((task) => taskDates[task.planDailyId] == dateStr)
        .toList();

    switch (filter.type) {
      case TaskType.daily:
        result = result
        .where((task) => !overtimeTaskIds.contains(task.planDailyId))
            .toList();
        break;
      case TaskType.overtime:
        result = result
        .where((task) => overtimeTaskIds.contains(task.planDailyId))
            .toList();
        break;
      case TaskType.plan:
        result = result.where((task) => task.status == 'PLAN').toList();
        break;
    }

    return result;
  }

  @override
  Future<ViewTaskModel> saveCheckpoint({
    required String planDailyId,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final rawTasks = await _loadRawTasks();
    final task = rawTasks.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['planDailyId'] == planDailyId,
          orElse: () => null,
        );
    if (task == null) {
      throw ServerException(message: 'Task tidak ditemukan');
    }

    final normalizedProgress = progress.clamp(0, 100);
    final taskModel = ViewTaskModel.fromJson(task);
    final session = sl<SessionManager>();
    final history = List<Map<String, dynamic>>.from(
      (task['checkpointHistory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
    if (history.isNotEmpty && history.last['jobStatus'] == 'DONE') {
      throw ServerException(
        message: 'Sesi check progress sudah selesai, tidak bisa input sesi berikutnya',
      );
    }
    if (history.length >= taskModel.maxCheckpointSessions) {
      throw ServerException(message: 'Sesi check progress maksimal sudah tercapai');
    }

    history.add({
      'sessionNumber': history.length + 1,
      'startWorkTime': startWorkTime,
      'finishWorkTime': finishWorkTime,
      'progress': normalizedProgress,
      'checkpointTime': checkpointTime,
      'jobStatus': jobStatus,
      'actorRole': session.role ?? 'kd',
      'actorName': session.fullName ?? 'SYSTEM',
      'isValidated': false,
      'reviewers': const <Map<String, dynamic>>[],
    });
    task['checkpointHistory'] = history;

    _syncTaskStatusFromHistory(task, history);
    await _saveRawTasks(rawTasks);

    return ViewTaskModel.fromJson(task);
  }

  @override
  Future<ViewTaskModel> updateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final rawTasks = await _loadRawTasks();
    final task = rawTasks.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['planDailyId'] == planDailyId,
          orElse: () => null,
        );
    if (task == null) {
      throw ServerException(message: 'Task tidak ditemukan');
    }

    final normalizedProgress = progress.clamp(0, 100);
    final history = List<Map<String, dynamic>>.from(
      (task['checkpointHistory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
    final sessionIndex = history.indexWhere((item) => item['sessionNumber'] == sessionNumber);
    if (sessionIndex == -1) {
      throw ServerException(message: 'Sesi check progress tidak ditemukan');
    }

    final existing = history[sessionIndex];
    history[sessionIndex] = {
      ...existing,
      'startWorkTime': startWorkTime,
      'finishWorkTime': finishWorkTime,
      'progress': normalizedProgress,
      'checkpointTime': checkpointTime,
      'jobStatus': jobStatus,
      'isValidated': false,
      'reviewers': const <Map<String, dynamic>>[],
    };
    task['checkpointHistory'] = history;

    _syncTaskStatusFromHistory(task, history);
    await _saveRawTasks(rawTasks);

    return ViewTaskModel.fromJson(task);
  }

  @override
  Future<ViewTaskModel> validateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final rawTasks = await _loadRawTasks();
    final task = rawTasks.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['planDailyId'] == planDailyId,
          orElse: () => null,
        );
    if (task == null) {
      throw ServerException(message: 'Task tidak ditemukan');
    }

    final session = sl<SessionManager>();
    final history = List<Map<String, dynamic>>.from(
      (task['checkpointHistory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
    final sessionIndex = history.indexWhere((item) => item['sessionNumber'] == sessionNumber);
    if (sessionIndex == -1) {
      throw ServerException(message: 'Sesi check progress tidak ditemukan');
    }

    final current = history[sessionIndex];
    final reviewers = List<Map<String, dynamic>>.from(
      (current['reviewers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
    final currentRole = session.role ?? 'adv';
    final reviewerIndex = reviewers.indexWhere(
      (item) => (item['role'] as String?)?.toLowerCase() == currentRole.toLowerCase(),
    );
    if (reviewerIndex >= 0) {
      reviewers[reviewerIndex] = {
        'role': currentRole,
        'name': session.fullName ?? 'SYSTEM',
      };
    } else {
      reviewers.add({
        'role': currentRole,
        'name': session.fullName ?? 'SYSTEM',
      });
    }

    history[sessionIndex] = {
      ...current,
      'isValidated': reviewers.isNotEmpty,
      'reviewers': reviewers,
    };
    task['checkpointHistory'] = history;

    _syncTaskStatusFromHistory(task, history);
    await _saveRawTasks(rawTasks);

    return ViewTaskModel.fromJson(task);
  }

  void _syncTaskStatusFromHistory(
    Map<String, dynamic> task,
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) return;

    final latest = history.last;
    final latestStatus = latest['jobStatus'] as String? ?? 'ON_PROGRESS';
    final latestProgress = (latest['progress'] as num?)?.toInt() ?? 0;

    if (latestStatus == 'DONE' || latestProgress >= 100) {
      task['status'] = 'DONE';
    } else if (latestStatus == 'CANCEL') {
      task['status'] = 'CANCEL';
    } else {
      task['status'] = 'CHECK_PROGRESS';
    }
  }

  @override
  Future<ViewTaskModel> validateTask({
    required String planDailyId,
    required bool approved,
    required String note,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final rawTasks = await _loadRawTasks();
    final task = rawTasks.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['planDailyId'] == planDailyId,
          orElse: () => null,
        );
    if (task == null) {
      throw ServerException(message: 'Task tidak ditemukan');
    }

    final session = sl<SessionManager>();
    final currentRole = session.role ?? 'adv';
    final currentName = session.fullName ?? 'SYSTEM';
    final validationTime = DateTime.now().toIso8601String();
    final validations = List<Map<String, dynamic>>.from(
      (task['finalValidations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
    final validationIndex = validations.indexWhere(
      (item) => (item['role'] as String?)?.toLowerCase() == currentRole.toLowerCase(),
    );
    final validationData = {
      'role': currentRole,
      'name': currentName,
      'note': note,
      'time': validationTime,
      'approved': approved,
    };

    if (validationIndex >= 0) {
      validations[validationIndex] = validationData;
    } else {
      validations.add(validationData);
    }

    task['finalValidations'] = validations;
    task['validation'] = validationData;
    task['status'] = approved ? 'VALIDATED' : 'REWORK';
    await _saveRawTasks(rawTasks);

    return ViewTaskModel.fromJson(task);
  }

  Future<List<Map<String, dynamic>>> _loadRawTasks() {
    return store.readList(
      key: LocalMockApiStore.taskViewKey,
      seedBuilder: DummyTaskViewData.seedTasks,
    );
  }

  Future<void> _saveRawTasks(List<Map<String, dynamic>> rawTasks) {
    return store.writeList(
      key: LocalMockApiStore.taskViewKey,
      value: rawTasks,
    );
  }

  List<ViewTaskModel> _allTasks(List<Map<String, dynamic>> rawTasks) =>
      rawTasks.map(ViewTaskModel.fromJson).toList();

  Set<String> _overtimeTaskIds(List<Map<String, dynamic>> rawTasks) => rawTasks
      .where((item) => item['isOvertime'] == true)
      .map((item) => item['planDailyId'] as String)
      .toSet();

  Map<String, String> _taskDates(List<Map<String, dynamic>> rawTasks) {
    return {
      for (final item in rawTasks)
        item['planDailyId'] as String:
            (item['taskDate'] as String?) ?? _todayFallbackDate(),
    };
  }

  /// Returns division IDs supervised by an advisor.
  /// In production, this comes from a mapping table.
  static List<int> _getAdvisorDivisions(int? divisionId) {
    if (divisionId == 1) return [6, 7, 8, 9, 10, 11, 12, 14];
    if (divisionId == 6 || divisionId == 7 || divisionId == 8 || divisionId == 9) {
      return [6, 7, 8, 9, 10, 12];
    }
    return [divisionId ?? 6];
  }
}
