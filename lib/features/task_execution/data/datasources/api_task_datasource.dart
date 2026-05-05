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
/// - POST /tasks action=start (JSON body)
/// - PUT /tasks action=submit (JSON body)
class ApiTaskDataSource implements RemoteTaskDataSource {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  const ApiTaskDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  void _assertRemotePhotoUrl(String? value, String fieldName) {
    if (value == null || value.isEmpty) return;
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return;
    throw DataFormatException(
      message:
          '$fieldName harus berupa URL publik hasil upload, bukan path lokal.',
    );
  }

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
        'userId': sessionManager.userId ?? sessionManager.employeeId ?? '',
        'date': dateStr,
      },
    );

    final rawData = response.data;
    // BE wraps response as: {statusCode, data: {filters, data: [...]}}
    // So we need to drill: rawData['data']['data']
    List<dynamic> items;
    if (rawData is List) {
      items = rawData;
    } else if (rawData is Map) {
      final inner = rawData['data'];
      if (inner is List) {
        items = inner;
      } else if (inner is Map) {
        // Nested: data.data is the actual array
        items = (inner['data'] as List?) ?? [];
      } else {
        items = [];
      }
    } else {
      items = [];
    }

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
  Future<TaskModel> startJobExecution(
    String plandailyId, {
    String? photoBefore1Path,
    String? photoBefore2Path,
  }) async {
    _assertRemotePhotoUrl(photoBefore1Path, 'photoBefore1');
    _assertRemotePhotoUrl(photoBefore2Path, 'photoBefore2');

    // BE action=start: generates startTime itself — do NOT send startTime.
    // photoBefore1 wajib diisi (BE validates), photoBefore2/3 optional.
    final payload = <String, dynamic>{
      'action': 'start',
      'plandailyId': plandailyId,
      'userId': sessionManager.userId ?? sessionManager.employeeId ?? '',
      if (photoBefore1Path != null && photoBefore1Path.isNotEmpty)
        'photoBefore1': photoBefore1Path,
      if (photoBefore2Path != null && photoBefore2Path.isNotEmpty)
        'photoBefore2': photoBefore2Path,
    };

    final response = await apiClient.post(
      ApiEndpoints.taskStart,
      data: payload,
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final respData = data['data'] as Map<String, dynamic>? ?? {};
    final startTime = respData['startTime'] as String? ??
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
    final payload = <String, dynamic>{
      'action': 'submit',
      'plandailyId': plandailyId,
      'userId': sessionManager.userId ?? sessionManager.employeeId ?? '',
      'startTime': DateTime.now().toUtc().toIso8601String(),
      'finishTime': DateTime.now().toUtc().toIso8601String(),
      'breakDurationMinutes': breakDurationMinutes,
      'progressPercent': 100,
      'status': 'done',
    };

    final response = await apiClient.put(
      ApiEndpoints.taskSubmit,
      data: payload,
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
      status: _normalizeTaskStatus(data['status'] as String? ?? 'DONE'),
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
      totalActualHours: (data['duration'] as num?)?.toDouble() ?? 0,
      hasMonitoringRecord: true,
    );
  }

  @override
  Future<TaskModel> submitTaskExecution(TaskExecutionLog log) async {
    final userId = sessionManager.userId ?? sessionManager.employeeId ?? '';
    final normalizedStatus = log.status.trim().toLowerCase();
    _assertRemotePhotoUrl(log.photoProcess, 'photoProcess1');
    _assertRemotePhotoUrl(log.photoAfter, 'photoAfter1');

    if (normalizedStatus == 'pending') {
      final checkpointPayload = <String, dynamic>{
        'action': 'checkpoint',
        'plandailyId': log.plandailyId,
        'userId': userId,
        'status': 'pending',
        'progressSeen': log.progressPercent.round(),
        if (log.dailyNotes != null && log.dailyNotes!.trim().isNotEmpty)
          'note': log.dailyNotes!.trim(),
      };

      await apiClient.post(
        ApiEndpoints.taskCheckpoint,
        data: checkpointPayload,
      );

      return TaskModel(
        plandailyId: log.plandailyId,
        coreId: '',
        carId: '',
        unitName: '',
        panelName: '',
        jobName: '',
        divisionName: sessionManager.divisionName ?? '',
        status: 'PLAN',
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
        totalActualHours: 0,
        hasMonitoringRecord: true,
      );
    }

    final payload = <String, dynamic>{
      'action': 'submit',
      'plandailyId': log.plandailyId,
      'userId': userId,
      'startTime': log.startTime,
      'finishTime': log.finishTime,
      'breakDurationMinutes': log.breakDurationMinutes,
      'progressPercent': log.progressPercent,
      'status': normalizedStatus,
      if (log.dailyNotes != null) 'dailyNotes': log.dailyNotes,
      if (log.photoProcess != null && log.photoProcess!.isNotEmpty)
        'photoProcess1': log.photoProcess,
      if (log.photoAfter != null && log.photoAfter!.isNotEmpty)
        'photoAfter1': log.photoAfter,
    };

    final response = await apiClient.put(
      ApiEndpoints.taskSubmit,
      data: payload,
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
      status: _normalizeTaskStatus(data['status'] as String? ?? log.status),
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
      totalActualHours: (data['duration'] as num?)?.toDouble() ?? 0,
      hasMonitoringRecord: true,
    );
  }

  @override
  Future<TaskModel> recordBreak(
    String plandailyId, {
    required int breakDurationMinutes,
  }) async {
    return getTaskById(plandailyId);
  }

  @override
  Future<TaskModel> uploadProgressPhoto(
    String plandailyId, {
    required String photoUrl,
    String photoType = 'PROCESS',
  }) async {
    return getTaskById(plandailyId);
  }

  @override
  Future<String> getUploadTicket({required String filename}) async {
    final response = await apiClient.get(
      ApiEndpoints.tasksUploadTicket,
      queryParameters: {
        'filename': filename,
      },
    );
    final rawData = response.data as Map<String, dynamic>? ?? {};
    final data = rawData['data'] as Map<String, dynamic>? ?? {};
    final uploadUrl = data['upload_url'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw DataFormatException(message: 'upload_url tidak ditemukan');
    }
    return uploadUrl;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  String _normalizeTaskStatus(String raw) {
    final value = raw.trim().toUpperCase();
    switch (value) {
      case 'DONE':
      case 'QC_READY':
      case 'READY_QC':
        return 'DONE';
      case 'CANCEL':
      case 'CANCELLED':
        return 'CANCEL';
      case 'PENDING':
      case 'PLAN':
      case 'ASSIGNED':
        return 'PLAN';
      case 'PROSES':
      case 'IN_PROGRESS':
      case 'ON_PROGRESS':
      case 'ONPROGRESS':
      case 'CHECK_PROGRESS':
      case 'SUBMITTED':
        return 'PROSES';
      default:
        return 'PLAN';
    }
  }

  /// Maps a ViewTask-style JSON from GET /tasks response to TaskModel.
  TaskModel _viewTaskJsonToTaskModel(Map<String, dynamic> json) {
    final division = json['division'] as Map<String, dynamic>? ?? {};
    final unit = json['unit'] as Map<String, dynamic>? ?? {};
    final task = json['task'] as Map<String, dynamic>? ?? {};

    return TaskModel(
      plandailyId: _asString(json['planDailyId']),
      coreId: '',
      carId: _asString(unit['unitId']),
      unitName: _asString(unit['unitName'], fallback: '-'),
      panelName: _asString(task['namaPanel'], fallback: '-'),
      jobName: _asString(task['jobName'], fallback: '-'),
      divisionName: _asString(division['divisionName'], fallback: '-'),
      status:
          _normalizeTaskStatus(_asString(json['status'], fallback: 'PENDING')),
      isPanelLocked: false,
      dailyTargetHours: 8.0,
      targetHoursRevised: 0,
      remainingHours: 0,
      taskDate: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now().toUtc().toIso8601String(),
      taskCategory: '',
      customDescription: _asString(task['jobDescription']),
      ownerName: _asString(
        (json['employee'] as Map<String, dynamic>?)?['employeeName'],
      ),
      totalActualHours: 0,
      hasMonitoringRecord: json['hasMonitoringRecord'] as bool? ?? false,
      isRework: task['is_rework'] == 1 || task['is_rework'] == true,
      isOvertime: task['is_overtime'] == 1 || task['is_overtime'] == true,
      isPriority: task['is_priority'] == 1 || task['is_priority'] == true,
    );
  }
}
