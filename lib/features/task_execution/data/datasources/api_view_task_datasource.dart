/*
Tujuan: Data source task monitoring management untuk baca task view dan simpan checkpoint ke API.
Caller: ViewTaskRepositoryImpl.
Dependensi: ApiClient, ApiEndpoints, SessionManager, ViewTaskModel.
Main Functions: getViewTasks, saveCheckpoint, updateCheckpointSession, validateCheckpointSession.
Side Effects: HTTP GET/POST ke service task monitoring.
*/
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
    final payload = _buildCheckpointPayload(
      planDailyId: planDailyId,
      startWorkTime: startWorkTime,
      finishWorkTime: finishWorkTime,
      progress: progress,
      checkpointTime: checkpointTime,
      jobStatus: jobStatus,
    );
    await apiClient.post(ApiEndpoints.taskCheckpoint, data: payload);

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
    final payload = _buildCheckpointPayload(
      planDailyId: planDailyId,
      startWorkTime: startWorkTime,
      finishWorkTime: finishWorkTime,
      progress: progress,
      checkpointTime: checkpointTime,
      jobStatus: jobStatus,
      sessionNumber: sessionNumber,
    );

    await apiClient.post(ApiEndpoints.taskCheckpoint, data: payload);

    return _fetchTaskById(planDailyId);
  }

  Map<String, dynamic> _buildCheckpointPayload({
    required String planDailyId,
    required String startWorkTime,
    required String finishWorkTime,
    required int progress,
    required String checkpointTime,
    required String jobStatus,
    int? sessionNumber,
  }) {
    final userId = sessionManager.userId ?? sessionManager.employeeId ?? '';
    final normalizedJobStatus = jobStatus.trim().toUpperCase();
    final normalizedStatus = switch (normalizedJobStatus) {
      'DONE' => 'done',
      'PENDING' => 'pending',
      _ => 'monitoring',
    };
    final note = 'Checkpoint $checkpointTime ($startWorkTime-$finishWorkTime)';

    return <String, dynamic>{
      'action': 'checkpoint',
      'plandailyId': planDailyId,
      'userId': userId,
      'progressSeen': progress,
      'status': normalizedStatus,
      'jobStatus': normalizedJobStatus,
      'note': note,
      if (normalizedStatus == 'done') 'progressFinal': progress,
      if (sessionNumber != null) 'sessionNumber': sessionNumber,
      if (sessionNumber != null)
        'monitoringCheckpoints': [
          {
            'sessionNumber': sessionNumber,
            'time': checkpointTime,
            'progress': progress,
            'note': note,
          },
        ],
    };
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
