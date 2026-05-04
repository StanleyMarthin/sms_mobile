import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/task_filter.dart';
import '../models/view_task_model.dart';
import 'view_task_datasource.dart';

/// Real API implementation of [ViewTaskDataSource].
///
/// Calls GET /tasks with query parameters from [TaskFilter].
/// Backend automatically filters data based on JWT role.
class ApiViewTaskDataSource implements ViewTaskDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  const ApiViewTaskDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  @override
  Future<List<ViewTaskModel>> getViewTasks(TaskFilter filter) async {
    final date =
        '${filter.date.year}-${filter.date.month.toString().padLeft(2, '0')}-${filter.date.day.toString().padLeft(2, '0')}';
    final userId = sessionManager.userId ?? sessionManager.employeeId ?? '';
    final params = <String, dynamic>{
      'userId': userId,
      'date': date,
      if (filter.divisionId != null) 'divisionID': filter.divisionId,
      if (filter.unitId != null) 'unitID': filter.unitId,
    };

    if (filter.type == TaskType.overtime) {
      params['isOvertime'] = 1;
    } else if (filter.type == TaskType.daily) {
      params['isOvertime'] = 0;
    } else if (filter.type == TaskType.plan) {
      params['status'] = 'PLAN';
    }

    final response = await apiClient.get(
      ApiEndpoints.tasks,
      queryParameters: params,
    );

    final rawData = response.data;
    final List<dynamic> items;
    if (rawData is List) {
      items = rawData;
    } else if (rawData is Map) {
      final inner = rawData['data'];
      if (inner is List) {
        items = inner;
      } else if (inner is Map) {
        items = (inner['data'] as List<dynamic>?) ?? const [];
      } else {
        items = const [];
      }
    } else {
      items = const [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((json) => ViewTaskModel.fromJson(json))
        .toList();
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
    final userId = sessionManager.userId ?? sessionManager.employeeId ?? '';
    final normalizedStatus =
        jobStatus.toUpperCase() == 'DONE' ? 'done' : 'pending';
    final payload = <String, dynamic>{
      'action': 'checkpoint',
      'plandailyId': planDailyId,
      'userId': userId,
      'progressSeen': progress,
      'status': normalizedStatus,
      'note': 'Checkpoint $checkpointTime ($startWorkTime-$finishWorkTime)',
    };
    if (normalizedStatus == 'done') {
      payload['progressFinal'] = progress;
    }

    await apiClient.post(
      ApiEndpoints.taskCheckpoint,
      data: payload,
    );

    return _fetchTaskById(planDailyId);
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
    // Backend does not expose update checkpoint session; append as new checkpoint.
    return saveCheckpoint(
      planDailyId: planDailyId,
      startWorkTime: startWorkTime,
      finishWorkTime: finishWorkTime,
      progress: progress,
      checkpointTime: checkpointTime,
      jobStatus: jobStatus,
    );
  }

  @override
  Future<ViewTaskModel> validateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
  }) async {
    // Backend does not expose dedicated validate-checkpoint endpoint.
    return _fetchTaskById(planDailyId);
  }

  @override
  Future<ViewTaskModel> validateTask({
    required String planDailyId,
    required bool approved,
    required String note,
  }) async {
    return _fetchTaskById(planDailyId);
  }

  Future<ViewTaskModel> _fetchTaskById(String planDailyId) async {
    final tasks = await getViewTasks(
      TaskFilter(type: TaskType.daily, date: DateTime.now()),
    );
    return tasks.firstWhere(
      (item) => item.planDailyId == planDailyId,
      orElse: () => throw StateError('Task $planDailyId tidak ditemukan'),
    );
  }
}
