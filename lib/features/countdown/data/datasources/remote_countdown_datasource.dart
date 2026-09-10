/*
Tujuan: Datasource HTTP countdown untuk unit, jobdesc, dan detail countdown dari backend.
Caller: CountdownRepositoryImpl.
Dependensi: ApiClient, ApiEndpoints, SessionManager, countdown_datasource.
Main Functions: getUnits, getJobdescs, getDetails.
Side Effects: HTTP GET ke service countdown.
*/
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import 'countdown_datasource.dart';

class RemoteCountdownDataSource implements CountdownDataSource {
  RemoteCountdownDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  @override
  Future<List<Map<String, dynamic>>> getUnits() async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId},
    );

    final rows = response.data as List<dynamic>? ?? [];
    return rows.whereType<Map<String, dynamic>>().map((item) {
      return {
        'carId': '${item['car_id'] ?? ''}',
        'unitName': '${item['unit_name'] ?? '-'}',
        'owner': '${item['customer_name'] ?? '-'}',
        'status': '${item['status'] ?? 'PROSES'}',
        'progress': ((item['overall_progress'] as num?) ?? 0).toInt(),
        'deliveryDate': _toDate(item['contract_delivery_date']),
        'division': sessionManager.divisionName ?? '-',
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getDivisions(String carId) async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId, 'car_id': carId},
    );
    final rows = response.data as List<dynamic>? ?? [];
    return rows.whereType<Map<String, dynamic>>().map((item) {
      return {
        'divisionId': item['division_id'],
        'divisionName': '${item['division_name'] ?? '-'}',
        'code': '${item['code'] ?? ''}',
        'divisionProgress': ((item['division_progress'] as num?) ?? 0)
            .toDouble(),
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> getMasterPanelTracking(String unitId) async {
    final response = await apiClient.get(
      ApiEndpoints.masterPanelTracking(unitId),
      queryParameters: {'user_id': _userId},
    );
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      return raw['data'] as Map<String, dynamic>;
    }
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getMasterPanelDetail({
    required String unitId,
    required int panelId,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.masterPanelDetail(unitId, panelId),
      queryParameters: {'user_id': _userId},
    );
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      return raw['data'] as Map<String, dynamic>;
    }
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> getCountdownCreateOptions(String unitId) async {
    final response = await apiClient.get(
      ApiEndpoints.masterPanelCountdownOptions(unitId),
      queryParameters: {'user_id': _userId},
    );
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      return raw['data'] as Map<String, dynamic>;
    }
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<List<Map<String, dynamic>>> createMasterPanelCountdown({
    required String unitId,
    required int masterPanelId,
    required int divisionId,
    required String jobTypeId,
    required String description,
    required double targetHours,
    required String picPlan,
    String? startDate,
    String? deadlineDate,
    String taskCategory = 'MAIN',
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.masterPanelJobdescs(unitId, masterPanelId),
      data: {
        'user_id': _userId,
        'jobs': [
          {
            'division_id': divisionId,
            'job_type_id': jobTypeId,
            'description': description,
            'target_hours_initial': targetHours,
            'pic_plan': picPlan,
            if ((startDate ?? '').isNotEmpty) 'start_date': startDate,
            if ((deadlineDate ?? '').isNotEmpty) 'deadline_date': deadlineDate,
            'task_category': taskCategory,
          },
        ],
      },
    );
    final raw = response.data;
    if (raw is Map<String, dynamic> && raw['data'] is List<dynamic>) {
      return raw['data']!.whereType<Map<String, dynamic>>().toList();
    }
    return raw is List<dynamic>
        ? raw.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  }) async {
    final params = <String, dynamic>{
      'user_id': _userId,
      'car_id': carId,
      'division_id': divisionId,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty && status != 'all') {
      final st = status.toLowerCase() == 'qcready' ? 'READY_QC' : status;
      params['status'] = st;
    }
    if (plannable) params['plannable'] = 'true';

    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: params,
    );
    final rows = response.data as List<dynamic>? ?? [];
    return rows.whereType<Map<String, dynamic>>().map((item) {
      return {
        'panelId': item['panel_id'],
        'sectionName': '${item['section_name'] ?? '-'}',
        'section': '${item['section'] ?? '-'}',
        'totalJobdesc': (item['total_jobdesc'] as num?)?.toInt() ?? 0,
        'totalRemainingHours': ((item['total_remaining_hours'] as num?) ?? 0)
            .toDouble(),
        'totalTargetHours': ((item['total_target_hours'] as num?) ?? 0)
            .toDouble(),
        'sectionProgress': ((item['section_progress'] as num?) ?? 0).toDouble(),
        'sectionStatus': '${item['section_status'] ?? 'PLAN'}',
        'totalTargetHoursAlias': item['total_target_hours_alias'],
        'totalRemainingHoursAlias': item['total_remaining_hours_alias'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  }) async {
    final params = <String, dynamic>{
      'user_id': _userId,
      'car_id': carId,
      'division_id': divisionId,
      'panel_id': panelId,
    };
    if (plannable) params['plannable'] = 'true';

    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: params,
    );
    final rows = response.data as List<dynamic>? ?? [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((job) => _mapJobRow(job, carId))
        .toList();
  }

  Map<String, dynamic> _mapJobRow(Map<String, dynamic> job, String carId) {
    return {
      'id': '${job['countdown_id'] ?? ''}',
      'carId': carId,
      'panelName': '${job['panel_name'] ?? '-'}',
      'sectionName': '${job['section_name'] ?? '-'}',
      'jobdesc': '${job['job_name'] ?? '-'}',
      'taskCategory': '${job['task_category'] ?? 'MAIN'}',
      'actualProgressPercent': (job['progress'] as num?)?.toInt() ?? 0,
      'status': '${job['status'] ?? 'PLAN'}',
      'targetHoursInitial': ((job['target_hours_revised'] as num?) ?? 0)
          .toDouble(),
      'timeExtensionHours': 0.0,
      'targetHoursRevised': ((job['target_hours_revised'] as num?) ?? 0)
          .toDouble(),
      'totalActualHours': 0.0,
      'remainingHours': ((job['remaining_hours'] as num?) ?? 0).toDouble(),
      'startDate': DateTime.now().toIso8601String().split('T').first,
      'deadlineDate': _toDate(job['deadline_date']),
      'qcLastStatus': null,
      'extensionRequestStatus': job['extension_request_status'],
      'extensionRequestedHours': null,
      'extensionRequestedDeadline': null,
      'extensionRequestReason': null,
      'extensionApprovedHours': null,
      'extensionApprovedDeadline': null,
      'extensionApprovedByName': null,
      'extensionApprovedAt': null,
      'extensionRejectedByName': null,
      'extensionRejectedAt': null,
      'extensionRequestedAt': null,
      'extensionRequestedByName': null,
      'divisionId': job['division_id'],
      'isLockedByOtherDivision':
          job['is_locked']?.toString() == '1' &&
          job['current_division_id']?.toString() !=
              job['division_id']?.toString(),
      'targetHoursRevisedAlias': job['target_hours_revised_alias'],
      'remainingHoursAlias': job['remaining_hours_alias'],
      'availablePlanHours':
          ((job['available_plan_hours'] as num?) ??
                  (job['remaining_hours'] as num?) ??
                  0)
              .toDouble(),
      'reservedPlanHours': ((job['reserved_plan_hours'] as num?) ?? 0)
          .toDouble(),
      'availablePlanHoursAlias': job['available_plan_hours_alias'],
      'reservedPlanHoursAlias': job['reserved_plan_hours_alias'],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getDetails(String countdownId) async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId, 'countdown_id': countdownId},
    );

    final rows = response.data as List<dynamic>? ?? [];
    return rows.whereType<Map<String, dynamic>>().map((item) {
      final start = _secondsOrStringToTime(item['start_time']);
      final finish = _secondsOrStringToTime(item['finish_time']);
      final duration = ((item['billed_hours'] as num?) ?? 0).toDouble();
      return {
        'id': '${item['detail_id'] ?? ''}',
        'countdownId': countdownId,
        'employeeName': '${item['employee_name'] ?? '-'}',
        'job': 'Actual Work',
        'detailJob': '${item['task_status'] ?? '-'}',
        'workDate': _toDate(item['work_date']),
        'startTime': start,
        'finishTime': finish,
        'targetHours': duration,
        'durationHours': duration,
        'remainingHours': 0.0,
        'overtimeHours': 0.0,
        'percentage': ((item['progress_percent'] as num?) ?? 0).toDouble(),
        'status': '${item['task_status'] ?? '-'}',
      };
    }).toList();
  }

  String _secondsOrStringToTime(Object? value) {
    if (value == null) return '08:00';
    if (value is num) {
      final totalSeconds = value.toInt();
      final h = totalSeconds ~/ 3600;
      final m = (totalSeconds % 3600) ~/ 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    final raw = '$value';
    if (raw.length >= 5) return raw.substring(0, 5);
    return raw;
  }

  @override
  Future<List<Map<String, dynamic>>> getRevisionRequests({
    String? carId,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId, 'approvals': true},
    );

    final rows = response.data as List<dynamic>? ?? [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return {
            'requestId': '${item['countdown_id'] ?? ''}',
            'countdownId': '${item['countdown_id'] ?? ''}',
            'carId': '${item['car_id'] ?? ''}',
            'unitName': '${item['unit_name'] ?? '-'}',
            'panelName': '${item['panel_name'] ?? '-'}',
            'jobdesc': '${item['job_name'] ?? '-'}',
            'status': 'REQUESTED',
            'requestedHours': (item['requested_extension_hours'] as num?)
                ?.toDouble(),
            'requestedDeadline': _toDate(item['requested_deadline']),
            'reason': item['revision_reason'] as String?,
            'requestedByName': item['requested_by_name'] as String?,
            'requestedAt': '${item['created_at'] ?? ''}',
            'currentHours': (item['current_hours'] as num?)?.toDouble(),
            'currentDeadline': _toDate(item['current_deadline']),
            'approvedHours': null,
            'approvedDeadline': null,
            'approvedByName': null,
            'approvedAt': null,
            'rejectedByName': null,
            'rejectedAt': null,
          };
        })
        .where((item) {
          if (carId == null || carId.isEmpty) {
            return true;
          }
          return item['carId'] == carId;
        })
        .toList();
  }

  @override
  Future<void> requestRevision({
    required String countdownId,
    required double requestedHours,
    required String requestedDeadline,
    required String reason,
  }) async {
    await apiClient.post(
      ApiEndpoints.countdownRevision,
      data: {
        'user_id': _userId,
        'countdown_id': countdownId,
        'requested_hours': requestedHours,
        'requested_deadline': requestedDeadline,
        'reason': reason,
      },
    );
  }

  @override
  Future<void> processRevisionRequest({
    required String requestId,
    required bool approved,
    required double approvedHours,
    required String approvedDeadline,
  }) async {
    await apiClient.put(
      ApiEndpoints.countdownAction,
      data: {
        'action': 'submit_approval',
        'user_id': _userId,
        'countdown_id': requestId,
        'is_approved': approved,
        'approved_hours': approvedHours,
        'approved_deadline': approvedDeadline,
      },
    );
  }

  @override
  Future<void> markAsQcReady(String countdownId) async {
    await apiClient.put(
      ApiEndpoints.countdownAction,
      data: {
        'action': 'mark_qc_ready',
        'user_id': _userId,
        'countdown_id': countdownId,
      },
    );
  }

  @override
  Future<void> moApproveRevision({
    required String requestId,
    required bool approved,
    String? note,
  }) async {
    await apiClient.put(
      ApiEndpoints.countdownAction,
      data: {
        'action': 'approve_revision',
        'user_id': _userId,
        'countdown_id': requestId,
        'is_approved': approved,
        if (note != null && note.isNotEmpty) 'notes': note,
      },
    );
  }

  @override
  Future<void> submitRevisionToApproval(String requestId) async {
    await apiClient.put(
      ApiEndpoints.countdownAction,
      data: {
        'action': 'submit_approval',
        'user_id': _userId,
        'countdown_id': requestId,
      },
    );
  }

  String? _toDate(Object? value) {
    if (value == null) return null;
    final raw = '$value';
    if (raw.contains('T')) return raw.split('T').first;
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }
}
