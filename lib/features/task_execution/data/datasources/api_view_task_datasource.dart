import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/task_filter.dart';
import '../models/view_task_model.dart';
import 'view_task_datasource.dart';

/// Real API implementation of [ViewTaskDataSource].
///
/// Calls GET /tasks with query parameters from [TaskFilter].
/// Backend automatically filters data based on JWT role.
class ApiViewTaskDataSource implements ViewTaskDataSource {
  final ApiClient apiClient;

  const ApiViewTaskDataSource({required this.apiClient});

  @override
  Future<List<ViewTaskModel>> getViewTasks(TaskFilter filter) async {
    final response = await apiClient.get(
      ApiEndpoints.tasks,
      queryParameters: filter.toQueryParams(),
    );

    final rawData = response.data;
    final List<dynamic> items =
        rawData is List ? rawData : (rawData is Map ? (rawData['data'] as List? ?? []) : []);

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
  }) {
    throw UnimplementedError('saveCheckpoint is not implemented for API data source yet');
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
  }) {
    throw UnimplementedError('updateCheckpointSession is not implemented for API data source yet');
  }

  @override
  Future<ViewTaskModel> validateCheckpointSession({
    required String planDailyId,
    required int sessionNumber,
  }) {
    throw UnimplementedError('validateCheckpointSession is not implemented for API data source yet');
  }

  @override
  Future<ViewTaskModel> validateTask({
    required String planDailyId,
    required bool approved,
    required String note,
  }) {
    throw UnimplementedError('validateTask is not implemented for API data source yet');
  }
}
