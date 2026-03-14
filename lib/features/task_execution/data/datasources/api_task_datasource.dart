import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/task_execution_log.dart';
import '../models/task_model.dart';
import 'remote_task_datasource.dart';

/// Real API implementation of [RemoteTaskDataSource].
///
/// Connects to:
/// - GET /tasks (mechanic's own tasks for today)
/// - POST /tasks/start (multipart: plandailyId, userId, start_time, photoBefore)
/// - POST /tasks/submit (multipart: plandailyId, finishTime, progress, photos, etc.)
class ApiTaskDataSource implements RemoteTaskDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  const ApiTaskDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  @override
  Future<List<TaskModel>> getTodaysTasks({
    required DateTime date,
    required bool isOvertime,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final response = await apiClient.get(
      ApiEndpoints.tasks,
      queryParameters: {
        'type': isOvertime ? 'overtime' : 'daily',
        'date': dateStr,
      },
    );

    final rawData = response.data;
    final List<dynamic> items =
        rawData is List ? rawData : (rawData is Map ? (rawData['data'] as List? ?? []) : []);

    return items
        .whereType<Map<String, dynamic>>()
        .map(_viewTaskJsonToTaskModel)
        .toList();
  }

  @override
  Future<TaskModel> getTaskById(String plandailyId) async {
    // GET /tasks filtered by the specific ID, then find matching one
    final tasks = await getTodaysTasks(
      date: DateTime.now(),
      isOvertime: false,
    );
    return tasks.firstWhere(
      (t) => t.plandailyId == plandailyId,
      orElse: () => throw ClientException(
        statusCode: 404,
        message: 'Task $plandailyId tidak ditemukan',
      ),
    );
  }

  @override
  Future<TaskModel> startJobExecution(String plandailyId) async {
    final formData = FormData.fromMap({
      'plandailyId': plandailyId,
      'userId': sessionManager.userId ?? sessionManager.employeeId ?? '',
      'start_time': DateTime.now().toUtc().toIso8601String(),
    });

    final response = await apiClient.postMultipart(
      ApiEndpoints.taskStart,
      formData: formData,
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final startTime = data['startTime'] as String? ??
        DateTime.now().toUtc().toIso8601String();

    // Return a minimal TaskModel with updated start info
    // The BLoC will refresh the full list after start
    return TaskModel(
      plandailyId: plandailyId,
      coreId: '',
      carId: '',
      unitName: '',
      panelName: '',
      jobName: '',
      divisionName: sessionManager.divisionName ?? '',
      status: 'PROSES',
      isPanelLocked: true,
      dailyTargetHours: 0,
      targetHoursRevised: 0,
      remainingHours: 0,
      taskDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      startedAt: startTime,
      taskCategory: '',
      customDescription: '',
      ownerName: sessionManager.fullName ?? '',
      totalActualHours: 0,
      hasMonitoringRecord: false,
    );
  }

  @override
  Future<TaskModel> finishJobExecution(
    String plandailyId, {
    int breakDurationMinutes = 60,
  }) async {
    // The API contract uses POST /tasks/submit for both finish & submit.
    // For a simple "finish" action, submit with status = current status.
    final formData = FormData.fromMap({
      'plandailyId': plandailyId,
      'finishTime': DateTime.now().toUtc().toIso8601String(),
      'breakDurationMinutes': breakDurationMinutes,
    });

    final response = await apiClient.postMultipart(
      ApiEndpoints.taskSubmit,
      formData: formData,
    );

    final data = response.data as Map<String, dynamic>? ?? {};

    return TaskModel(
      plandailyId: plandailyId,
      coreId: '',
      carId: '',
      unitName: '',
      panelName: '',
      jobName: '',
      divisionName: sessionManager.divisionName ?? '',
      status: data['status'] as String? ?? 'DONE',
      isPanelLocked: false,
      dailyTargetHours: 0,
      targetHoursRevised: 0,
      remainingHours: 0,
      taskDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      completedAt: DateTime.now().toUtc().toIso8601String(),
      taskCategory: '',
      customDescription: '',
      ownerName: sessionManager.fullName ?? '',
      totalActualHours: (data['durationHours'] as num?)?.toDouble() ?? 0,
      hasMonitoringRecord: true,
    );
  }

  @override
  Future<TaskModel> submitTaskExecution(TaskExecutionLog log) async {
    final fields = <String, dynamic>{
      'plandailyId': log.plandailyId,
      'finishTime': log.finishTime,
      'breakDurationMinutes': log.breakDurationMinutes,
      'progressPercent': log.progressPercent,
      'status': log.status,
      if (log.dailyNotes != null) 'dailyNotes': log.dailyNotes,
    };

    // Attach photo files if provided
    if (log.photoProcess != null && log.photoProcess!.isNotEmpty) {
      fields['photoProcess'] =
          await MultipartFile.fromFile(log.photoProcess!, filename: 'photo_process.jpg');
    }
    if (log.photoAfter != null && log.photoAfter!.isNotEmpty) {
      fields['photoAfter'] =
          await MultipartFile.fromFile(log.photoAfter!, filename: 'photo_after.jpg');
    }
    if (log.photoBefore != null && log.photoBefore!.isNotEmpty) {
      fields['photoBefore'] =
          await MultipartFile.fromFile(log.photoBefore!, filename: 'photo_before.jpg');
    }

    final formData = FormData.fromMap(fields);

    final response = await apiClient.postMultipart(
      ApiEndpoints.taskSubmit,
      formData: formData,
    );

    final data = response.data as Map<String, dynamic>? ?? {};

    return TaskModel(
      plandailyId: log.plandailyId,
      coreId: '',
      carId: '',
      unitName: '',
      panelName: '',
      jobName: '',
      divisionName: sessionManager.divisionName ?? '',
      status: data['status'] as String? ?? log.status,
      isPanelLocked: false,
      dailyTargetHours: 0,
      targetHoursRevised: 0,
      remainingHours: 0,
      taskDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      startedAt: log.startTime,
      completedAt: log.finishTime,
      taskCategory: '',
      customDescription: '',
      ownerName: sessionManager.fullName ?? '',
      totalActualHours: (data['durationHours'] as num?)?.toDouble() ?? 0,
      hasMonitoringRecord: true,
    );
  }

  /// Maps a ViewTask-style JSON from GET /tasks response to TaskModel.
  TaskModel _viewTaskJsonToTaskModel(Map<String, dynamic> json) {
    final division = json['division'] as Map<String, dynamic>? ?? {};
    final unit = json['unit'] as Map<String, dynamic>? ?? {};
    final task = json['task'] as Map<String, dynamic>? ?? {};

    return TaskModel(
      plandailyId: json['planDailyId'] as String? ?? '',
      coreId: '',
      carId: unit['unitId'] as String? ?? '',
      unitName: unit['unitName'] as String? ?? '',
      panelName: task['namaPanel'] as String? ?? '',
      jobName: task['jobName'] as String? ?? '',
      divisionName: division['divisionName'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      isPanelLocked: false,
      dailyTargetHours: 8.0,
      targetHoursRevised: 0,
      remainingHours: 0,
      taskDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      taskCategory: '',
      customDescription: task['jobDescription'] as String? ?? '',
      ownerName: (json['employee'] as Map<String, dynamic>?)?['employeeName'] as String? ?? '',
      totalActualHours: 0,
      hasMonitoringRecord: json['hasMonitoringRecord'] as bool? ?? false,
    );
  }
}
