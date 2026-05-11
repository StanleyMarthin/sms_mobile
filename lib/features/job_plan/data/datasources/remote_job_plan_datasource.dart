/*
Tujuan: Datasource remote job plan untuk draft, browse, submit, dan approval via API.
Caller: JobPlanRepositoryImpl.
Dependensi: ApiClient, ApiEndpoints, SessionManager.
Main Functions: saveDraft, getDraft, submitDraft, browsePlans, createPlan.
Side Effects: HTTP GET/POST/PUT ke service sm_job_plan.
*/
library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import 'job_plan_datasource.dart';

class RemoteJobPlanDataSource implements JobPlanDataSource {
  static final Map<String, String> _statusOverrides = {};
  static final RegExp _legacyPokPattern = RegExp(
    r'(?:^|\|)\s*POK:\s*(.+)$',
    caseSensitive: false,
  );

  RemoteJobPlanDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _roleCode {
    final role = (sessionManager.role ?? '').trim().toLowerCase();
    final jabatan = (sessionManager.jabatan ?? '').trim().toLowerCase();
    if (role == 'pm' && jabatan.contains('kepala project')) return 'KP';
    return switch (role) {
      'adv' => 'ADV',
      'advisor' => 'ADV',
      'kp' => 'KP',
      'kepala_project' => 'KP',
      'kepala project' => 'KP',
      'project_head' => 'KP',
      'pm' => 'MP',
      'mp' => 'MP',
      'manager_project' => 'MP',
      'manager project' => 'MP',
      'kd' => 'KD',
      'ketua_divisi' => 'KD',
      'kepala_divisi' => 'KD',
      _ => role.toUpperCase(),
    };
  }

  String _resolveNote({
    String? note,
    String? jobDescription,
    String? panelName,
  }) {
    final raw = (note ?? '').trim();
    if (raw.isNotEmpty) {
      final pokMatch = _legacyPokPattern.firstMatch(raw);
      final pokValue = pokMatch?.group(1)?.trim() ?? '';
      if (pokValue.isNotEmpty) return pokValue;

      final upper = raw.toUpperCase();
      final looksLegacyMeta =
          upper.contains('SUMBER:') ||
          upper.contains('LEMBUR:') ||
          upper.contains('URGENT:');
      if (!looksLegacyMeta) return raw;
    }

    final parts = <String>[
      if ((jobDescription ?? '').trim().isNotEmpty) jobDescription!.trim(),
      if ((panelName ?? '').trim().isNotEmpty) panelName!.trim(),
    ];
    return parts.join(' - ');
  }

  String _itemPanelName(Map<String, dynamic> item) =>
      (item['panelName'] ??
              item['panel_name'] ??
              item['sectionName'] ??
              item['panelCustomNote'] ??
              item['panel_custom_note'] ??
              '')
          .toString();

  String _itemJobDescription(Map<String, dynamic> item) =>
      (item['jobDescription'] ?? item['jobdescription'] ?? '').toString();

  Map<String, dynamic> _normalizeDraftItem(
    Map<String, dynamic> item, {
    String? draftNote,
  }) {
    final normalized = Map<String, dynamic>.from(item);
    normalized['note'] = _resolveNote(
      note: normalized['note']?.toString() ?? draftNote,
      jobDescription: _itemJobDescription(normalized),
      panelName: _itemPanelName(normalized),
    );
    return normalized;
  }

  String? _resolveSharedSourceRefId(List<Map<String, dynamic>> items) {
    final sourceRefs = items
        .map((item) => item['sourceRefId']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    if (sourceRefs.length == 1) return sourceRefs.first;
    return null;
  }

  Map<String, dynamic> _normalizeDraftPayloadMap(Map<String, dynamic> payload) {
    final items = (payload['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    final firstItem = items.isNotEmpty ? items.first : <String, dynamic>{};
    final normalizedNote = _resolveNote(
      note: payload['note']?.toString(),
      jobDescription: _itemJobDescription(firstItem),
      panelName: _itemPanelName(firstItem),
    );
    return {
      ...payload,
      'note': normalizedNote,
      'items': items
          .map((item) => _normalizeDraftItem(item, draftNote: normalizedNote))
          .toList(),
    };
  }

  // ─── GET /sm/job-plans  (action=queue, default) ──────────────────
  // Returns { items: [...], count: N }
  @override
  Future<List<Map<String, dynamic>>> getPlans() async {
    final response = await apiClient.get(
      ApiEndpoints.jobPlans,
      queryParameters: {
        'userId': sessionManager.employeeId ?? '',
        if (sessionManager.divisionId != null)
          'divisionId': '${sessionManager.divisionId}',
        'limit': 200,
        'offset': 0,
      },
    );
    // ApiClient._parseResponse already unwraps data['data']
    final payload = response.data;
    List<dynamic> items = const [];
    if (payload is Map<String, dynamic>) {
      items = payload['items'] as List<dynamic>? ?? [];
    } else if (payload is List<dynamic>) {
      items = payload;
    }

    final merged = <String, Map<String, dynamic>>{};
    for (final item in items.whereType<Map<String, dynamic>>()) {
      final id = '${item['planId'] ?? ''}';
      if (id.isEmpty) continue;
      if (_statusOverrides.containsKey(id)) {
        item['status'] = _statusOverrides[id];
      }
      merged[id] = item;
    }

    final normalized = merged.values.map(_normalizePlan).toList();
    normalized.sort((a, b) {
      final byDate = b['workDate'].toString().compareTo(
        a['workDate'].toString(),
      );
      if (byDate != 0) return byDate;
      return b['planId'].toString().compareTo(a['planId'].toString());
    });
    return normalized;
  }

  @override
  Future<List<Map<String, dynamic>>> getApprovalQueue({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.jobPlans,
      queryParameters: {
        'action': 'approval_queue',
        'userId': sessionManager.employeeId ?? '',
        if (divisionId != null) 'divisionId': divisionId,
        if (unitId != null) 'unitId': unitId,
        if (taskDate != null) 'taskDate': taskDate,
        'limit': limit,
        'offset': offset,
      },
    );
    final payload = response.data;
    final rawItems = payload is Map<String, dynamic>
        ? (payload['items'] as List<dynamic>? ?? [])
        : payload is List<dynamic>
        ? payload
        : const <dynamic>[];

    final items = rawItems.whereType<Map<String, dynamic>>().map((item) {
      if (item.containsKey('planId')) return _normalizePlan(item);
      return Map<String, dynamic>.from(item);
    }).toList();
    return items;
  }

  // ─── GET /sm/job-plans?action=browse ────────────────────────────
  // Returns List (for KD) or List (division/unit steps)
  @override
  Future<List<Map<String, dynamic>>> browsePlans({
    String? divisionId,
    String? unitId,
    String? role,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.jobPlans,
      queryParameters: {
        'action': 'browse',
        'userId': sessionManager.employeeId ?? '',
        if (divisionId != null) 'divisionId': divisionId,
        if (unitId != null) 'unitId': unitId,
        if (taskDate != null) 'taskDate': taskDate,
        'limit': limit,
        'offset': offset,
      },
    );
    final payload = response.data;
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      return (payload['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  // ─── GET /sm/job-plans/dropdowns ───────────────────────────────
  // Returns { divisions, panels, units, users, jobTypes }
  @override
  Future<Map<String, List<Map<String, dynamic>>>> getDropdowns({
    String? divisionId,
    String? carId,
    String? searchUser,
    int userLimit = 200,
  }) async {
    String? resolvedDivId;
    if ((divisionId ?? '').isNotEmpty) {
      resolvedDivId = int.tryParse(divisionId!) != null
          ? divisionId
          : await _resolveNumericDivisionId(divisionId);
    }

    final response = await apiClient.get(
      ApiEndpoints.jobPlanDropdowns,
      queryParameters: {
        if ((resolvedDivId ?? '').isNotEmpty) 'divisionId': resolvedDivId,
        if ((carId ?? '').trim().isNotEmpty) 'carId': carId,
      },
    );
    // response.data is already inner payload: { divisions, panels, units, users, jobTypes }
    final payload = response.data as Map<String, dynamic>? ?? {};
    return {
      'cars': _asMapList(payload['cars']), // BE key: "cars"
      'panels': _asMapList(payload['panels']),
      'jobTypes': _asMapList(payload['jobTypes']),
      'divisions': _asMapList(payload['divisions']),
      'users': _asMapList(
        payload['users'],
      ).map(_normalizeDropdownUser).toList(),
    };
  }

  // ─── GET /sm/job-plans/dropdowns (for additional form) ─────────
  @override
  Future<Map<String, dynamic>> getAdditionalDropdowns({
    String? divisionId,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.jobPlanDropdowns,
      queryParameters: {if (divisionId != null) 'divisionId': divisionId},
    );
    final payload = response.data as Map<String, dynamic>? ?? {};
    return {
      ...payload,
      'users': _asMapList(
        payload['users'],
      ).map(_normalizeDropdownUser).toList(),
    };
  }

  // ─── Dropdown users — reuse /dropdowns endpoint ─────────────────
  // BE does not have a separate /dropdowns/users endpoint
  @override
  Future<List<Map<String, dynamic>>> getDropdownUsers({
    required String divisionId,
    String? search,
    int limit = 200,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.jobPlanDropdowns,
      queryParameters: {'divisionId': divisionId},
    );
    final payload = response.data as Map<String, dynamic>? ?? {};
    return _asMapList(payload['users']).map(_normalizeDropdownUser).toList();
  }

  // ─── GET /sm/job-plans?action=draft ────────────────────────────
  @override
  Future<Map<String, dynamic>?> getDraft({required String userId}) async {
    try {
      final response = await apiClient.get(
        ApiEndpoints.jobPlans,
        queryParameters: {'action': 'draft', 'userId': userId},
      );
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return _normalizeDraftPayloadMap(payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── POST /sm/job-plans  action=save_draft ─────────────────────
  @override
  Future<void> saveDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    bool replaceItems = true,
    String? note,
  }) async {
    final normalizedItems = items
        .map((item) => _normalizeDraftItem(item, draftNote: note))
        .toList();
    final firstItem = normalizedItems.isNotEmpty
        ? normalizedItems.first
        : <String, dynamic>{};
    final sourceRefId = _resolveSharedSourceRefId(normalizedItems);
    final normalizedNote = _resolveNote(
      note: note,
      jobDescription: _itemJobDescription(firstItem),
      panelName: _itemPanelName(firstItem),
    );
    await apiClient.post(
      ApiEndpoints.jobPlans,
      data: {
        'action': 'save_draft',
        'userId': userId,
        'sourceType': sourceType,
        if (sourceRefId != null) 'sourceRefId': sourceRefId,
        'replaceItems': replaceItems,
        'note': normalizedNote,
        'items': normalizedItems,
      },
    );
  }

  // ─── POST /sm/job-plans  action=delete_draft ───────────────────
  @override
  Future<void> deleteDraft({required String userId}) async {
    await apiClient.post(
      ApiEndpoints.jobPlans,
      data: {'action': 'delete_draft', 'userId': userId},
    );
  }

  // ─── POST /sm/job-plans  action=submit ─────────────────────────
  // BE DraftPlanItem fields: coreId, carId, divisionId, panelId, panelCustomNote,
  //   jobTypeId, assignedUserId, taskDate, startTime, finishTime, targetHours,
  //   isOvertime, jobDescription
  // BE returns: { "createdIds": [...] }
  @override
  Future<List<String>> submitDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    String? note,
  }) async {
    final normalizedItems = items
        .map((item) => _normalizeDraftItem(item, draftNote: note))
        .toList();
    final firstItem = normalizedItems.isNotEmpty
        ? normalizedItems.first
        : <String, dynamic>{};
    final sourceRefId = _resolveSharedSourceRefId(normalizedItems);
    final normalizedNote = _resolveNote(
      note: note,
      jobDescription: _itemJobDescription(firstItem),
      panelName: _itemPanelName(firstItem),
    );
    final response = await apiClient.post(
      ApiEndpoints.jobPlans,
      data: {
        'action': 'submit',
        'userId': userId,
        'sourceType': sourceType,
        if (sourceRefId != null) 'sourceRefId': sourceRefId,
        'note': normalizedNote,
        'items': normalizedItems,
      },
    );
    final payload = response.data;
    List<dynamic> ids = const [];
    if (payload is Map<String, dynamic>) {
      ids = payload['createdIds'] as List<dynamic>? ?? [];
    }
    return ids.map((e) => e.toString()).toList();
  }

  // ─── POST /sm/job-plans  action=submit (shortcut for createPlan) ─
  @override
  Future<Map<String, dynamic>> createPlan({
    String coreId = '',
    String carId = '',
    String sourceType = 'ADDITIONAL',
    String sourceRefId = '',
    String? initialStatus,
    bool syncToTasks = false,
    bool isUrgent = false,
    required String unitName,
    required String panelName,
    required String assignedDivision,
    required String assignedUserId,
    required String assignedTo,
    required String description,
    required double targetHours,
    required String workDate,
    required String startTime,
    required String finishTime,
    required bool isOvertime,
    required String note,
  }) async {
    final divisionId = await _resolveDivisionId(assignedDivision);
    final panelId = await _resolvePanelId(panelName);
    final jobTypeId = await _resolveJobTypeId(description, assignedDivision);
    final normalizedNote = _resolveNote(
      note: note,
      jobDescription: description,
      panelName: panelName,
    );

    final item = <String, dynamic>{
      if (coreId.trim().isNotEmpty) 'coreId': coreId,
      if (carId.trim().isNotEmpty) 'carId': carId,
      if (sourceRefId.trim().isNotEmpty) 'sourceRefId': sourceRefId,
      'divisionId': divisionId,
      'panelId': panelId,
      'panelCustomNote': panelName,
      'jobTypeId': jobTypeId,
      'assignedUserId': assignedUserId,
      'taskDate': workDate,
      'startTime': startTime,
      'finishTime': finishTime,
      'targetHours': targetHours,
      'isOvertime': isOvertime,
      'jobDescription': description,
    };

    final response = await apiClient.post(
      ApiEndpoints.jobPlans,
      data: {
        'action': 'submit',
        'userId': sessionManager.employeeId ?? '',
        'sourceType': sourceType.toUpperCase(),
        if (sourceRefId.trim().isNotEmpty) 'sourceRefId': sourceRefId,
        'note': normalizedNote,
        'items': [item],
      },
    );

    final payload = response.data;
    List<dynamic> createdIds = const [];
    if (payload is Map<String, dynamic>) {
      createdIds = payload['createdIds'] as List<dynamic>? ?? [];
    }

    if (createdIds.isNotEmpty) {
      final plans = await getPlans();
      final matched = plans
          .where((p) => createdIds.contains(p['planId']))
          .toList();
      if (matched.isNotEmpty) return matched.first;
    }

    return {
      'planId': createdIds.isNotEmpty ? createdIds.first : 'pending',
      'coreId': coreId,
      'carId': carId,
      'sourceType': sourceType,
      'sourceRefId': sourceRefId,
      'unitName': unitName,
      'panelName': panelName,
      'assignedDivision': assignedDivision,
      'assignedUserId': assignedUserId,
      'assignedTo': assignedTo,
      'description': description,
      'targetHours': targetHours,
      'workDate': workDate,
      'startTime': startTime,
      'finishTime': finishTime,
      'isOvertime': isOvertime,
      'deadline': workDate,
      'status': initialStatus ?? 'PLAN',
      'note': note,
    };
  }

  // ─── PUT /sm/job-plans  action=approve ─────────────────────────
  // BE req: { action, userId, planId }
  // BE res: { "planId": "..." }
  @override
  Future<Map<String, dynamic>> approvePlan({
    required String planId,
    required String userId,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.jobPlans,
      data: {'action': 'approve', 'userId': userId, 'planId': planId},
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) return payload;
    return {'planId': planId};
  }

  // ─── PUT /sm/job-plans  action=reject ──────────────────────────
  // BE req: { action, userId, planId, rejectNote }
  @override
  Future<Map<String, dynamic>> rejectPlan({
    required String planId,
    required String userId,
    required String rejectNote,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.jobPlans,
      data: {
        'action': 'reject',
        'userId': userId,
        'planId': planId,
        'rejectNote': rejectNote, // BE field: rejectNote (bukan rejectNotes)
      },
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) return payload;
    return {'planId': planId};
  }

  // ─── PUT /sm/job-plans  action=resubmit ────────────────────────
  // BE req: { action, userId, planId, items: [{startTime, finishTime, targetHours}] }
  @override
  Future<Map<String, dynamic>> resubmitPlan({
    required String planId,
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.jobPlans,
      data: {
        'action': 'resubmit',
        'userId': userId,
        'planId': planId,
        'items': items,
      },
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) return payload;
    return {'planId': planId};
  }

  // ─── PUT /sm/job-plans  action=delete ──────────────────────────
  @override
  Future<void> deleteRejectedPlan({
    required String planId,
    required String userId,
  }) async {
    await apiClient.put(
      ApiEndpoints.jobPlans,
      data: {'action': 'delete', 'userId': userId, 'planId': planId},
    );
  }

  // ─── reviewPlan → maps to approve/reject ───────────────────────
  @override
  Future<Map<String, dynamic>> reviewPlan({
    required String planId,
    required bool approved,
  }) async {
    if (approved) {
      await approvePlan(
        planId: planId,
        userId: sessionManager.employeeId ?? '',
      );
      if (_roleCode == 'ADV') {
        _statusOverrides[planId] = 'PENDING_KP';
      } else if (_roleCode == 'KP') {
        _statusOverrides[planId] = 'PENDING_MP';
      } else {
        _statusOverrides[planId] = 'PLAN';
      }
    } else {
      await rejectPlan(
        planId: planId,
        userId: sessionManager.employeeId ?? '',
        rejectNote: 'Ditolak via mobile',
      );
      _statusOverrides[planId] = 'REJECTED';
    }

    final plans = await getPlans();
    return plans.firstWhere(
      (item) => item['planId'] == planId,
      orElse: () => ({
        'planId': planId,
        'coreId': '',
        'carId': '',
        'sourceType': 'ADDITIONAL',
        'sourceRefId': '',
        'unitName': '-',
        'panelName': '-',
        'assignedDivision': '',
        'assignedUserId': '',
        'assignedTo': '-',
        'description': '-',
        'targetHours': 0.0,
        'workDate': '',
        'startTime': '08:00',
        'finishTime': '12:00',
        'isOvertime': false,
        'deadline': '',
        'status': approved ? 'PLAN' : 'REJECTED',
        'note': approved ? '' : 'Ditolak via mobile',
      }),
    );
  }

  // ─── updatePlan → maps to resubmit ─────────────────────────────
  // BE tidak punya action=update; gunakan resubmit dengan 1 item
  @override
  Future<Map<String, dynamic>> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  }) async {
    await resubmitPlan(
      planId: planId,
      userId: sessionManager.employeeId ?? '',
      items: [
        {
          'targetHours': targetHours,
          'taskDate': deadline,
          'startTime': '08:00',
          'finishTime': '16:00',
        },
      ],
    );

    final plans = await getPlans();
    return plans.firstWhere(
      (item) => item['planId'] == planId,
      orElse: () => ({
        'planId': planId,
        'coreId': '',
        'carId': '',
        'sourceType': 'ADDITIONAL',
        'sourceRefId': '',
        'unitName': '-',
        'panelName': '-',
        'assignedDivision': '',
        'assignedUserId': '',
        'assignedTo': '-',
        'description': '-',
        'targetHours': targetHours,
        'workDate': deadline,
        'startTime': '08:00',
        'finishTime': '16:00',
        'isOvertime': false,
        'deadline': deadline,
        'status': 'PLAN',
        'note': '',
      }),
    );
  }

  // ─── Response normalization ─────────────────────────────────────
  Map<String, dynamic> _normalizePlan(Map<String, dynamic> item) {
    final assignedUserId = '${item['assignedUserId'] ?? ''}';
    final assignedTo =
        '${item['assignedUserName'] ?? item['employeeName'] ?? item['full_name'] ?? (assignedUserId.isNotEmpty ? assignedUserId : '-')}';
    final assignedDivision =
        '${item['divisionName'] ?? item['division_name'] ?? item['division'] ?? ''}';
    final dailyTarget = _parseHours(
      item['targetHours'] ?? item['dailyTargetHours'],
    );
    final startTime =
        _normalizeTime(item['startTime'] ?? item['targetStartHours']) ??
        '08:00';
    final finishTime =
        _normalizeTime(item['finishTime'] ?? item['targetFinishHours']) ??
        _addHours(startTime, dailyTarget);
    final taskDate = _toDate(item['taskDate']);
    final normalizedStatus = _normalizeApprovalStatus(_pickStatusValue(item));

    return {
      'planId': '${item['planId'] ?? ''}',
      'coreId': '${item['coreId'] ?? ''}',
      'carId': '${item['carId'] ?? ''}',
      'sourceType': '${item['sourceType'] ?? 'ADDITIONAL'}',
      'sourceRefId': '${item['sourceRefId'] ?? ''}',
      'unitName': '${item['unitName'] ?? item['unit_name'] ?? '-'}',
      'panelName': '${item['panelName'] ?? item['panel_name'] ?? '-'}',
      'assignedDivision': assignedDivision,
      'assignedUserId': assignedUserId,
      'assignedTo': assignedTo,
      'description': '${item['jobdescription'] ?? ''}',
      'targetHours': dailyTarget,
      'workDate': taskDate,
      'startTime': startTime,
      'finishTime': finishTime,
      'isOvertime': _toBool(item['isOvertime']),
      'deadline': _toDate(item['deadlineDate']) == ''
          ? taskDate
          : _toDate(item['deadlineDate']),
      'status': normalizedStatus,
      'note': _resolveNote(
        note: item['note']?.toString(),
        jobDescription:
            '${item['jobdescription'] ?? item['description'] ?? ''}',
        panelName: '${item['panelName'] ?? item['panel_name'] ?? '-'}',
      ),
    };
  }

  String _pickStatusValue(Map<String, dynamic> item) {
    for (final key in [
      'status',
      'approvalStatus',
      'planStatus',
      'currentStatus',
    ]) {
      final value = item[key];
      if (value == null) continue;
      final raw = '$value'.trim();
      if (raw.isNotEmpty && raw.toLowerCase() != 'null') return raw;
    }
    return 'PLAN';
  }

  String _normalizeApprovalStatus(String rawStatus) {
    return switch (rawStatus.trim().toUpperCase()) {
      'PENDING_PM' ||
      'PENDING_MANAGER' ||
      'PENDING_MP_APPROVAL' => 'PENDING_MP',
      'PENDING_PROJECT_HEAD' ||
      'PENDING_KEPALA_PROJECT' ||
      'PENDING_KP_APPROVAL' => 'PENDING_KP',
      'PENDING_ADVISOR' || 'PENDING_ADVISOR_APPROVAL' => 'PENDING_ADV',
      final s => s,
    };
  }

  // ─── Dropdown resolvers ─────────────────────────────────────────
  Map<String, List<Map<String, dynamic>>>? _dropdownCache;

  Future<Map<String, List<Map<String, dynamic>>>> _getOrFetchDropdowns() async {
    if (_dropdownCache != null) return _dropdownCache!;
    try {
      _dropdownCache = await getDropdowns();
    } catch (_) {
      _dropdownCache = const {};
    }
    return _dropdownCache!;
  }

  Future<String?> _resolveNumericDivisionId(String divisionName) async {
    try {
      final response = await apiClient.get(ApiEndpoints.jobPlanDropdowns);
      final payload = response.data as Map<String, dynamic>? ?? {};
      final divisions = _asMapList(payload['divisions']);
      final dName = divisionName.trim().toUpperCase();
      for (final d in divisions) {
        if (d['name']?.toString().toUpperCase() == dName) {
          return d['id']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String> _resolveDivisionId(String divisionName) async {
    final dropdowns = await _getOrFetchDropdowns();
    final dName = divisionName.trim().toUpperCase();
    for (final d in (dropdowns['divisions'] ?? [])) {
      if (d['name']?.toString().toUpperCase() == dName) {
        return d['id'].toString();
      }
    }
    return await _resolveNumericDivisionId(divisionName) ?? '1';
  }

  Future<int> _resolvePanelId(String panelName) async {
    final dropdowns = await _getOrFetchDropdowns();
    final pName = panelName.toUpperCase();
    for (final p in dropdowns['panels'] ?? []) {
      if (p['name']?.toString().toUpperCase() == pName) {
        return int.tryParse(p['id'].toString()) ?? 0;
      }
    }
    return 1;
  }

  Future<String> _resolveJobTypeId(
    String description,
    String divisionName,
  ) async {
    final dropdowns = await _getOrFetchDropdowns();
    final dName = divisionName.toUpperCase();
    String divId = '';
    for (final d in dropdowns['divisions'] ?? []) {
      if (d['name']?.toString().toUpperCase() == dName) {
        divId = d['id'].toString();
        break;
      }
    }
    final jTypes = (dropdowns['jobTypes'] ?? [])
        .where((jt) => jt['division_id']?.toString() == divId)
        .toList();
    final descUpper = description.toUpperCase();
    for (final jt in jTypes) {
      if (descUpper.contains(jt['job_name']?.toString().toUpperCase() ?? '')) {
        return jt['id'].toString();
      }
    }
    if (jTypes.isNotEmpty) return jTypes.first['id'].toString();
    return '1';
  }

  // ─── Type helpers ───────────────────────────────────────────────
  String _toDate(Object? value) {
    if (value == null) return '';
    final raw = '$value';
    if (raw.contains('T')) return raw.split('T').first;
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  String? _normalizeTime(Object? value) {
    if (value is num) return _secondsToTime(value.toDouble());
    final raw = '$value';
    if (raw == 'null' || raw.isEmpty) return null;
    final numeric = double.tryParse(raw);
    if (numeric != null) return _secondsToTime(numeric);
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  String _secondsToTime(double seconds) {
    final totalMinutes = (seconds / 60).round();
    final h = '${(totalMinutes ~/ 60) % 24}'.padLeft(2, '0');
    final m = '${totalMinutes % 60}'.padLeft(2, '0');
    return '$h:$m';
  }

  bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return '$value'.toLowerCase() == 'true' || '$value' == '1';
  }

  double _parseHours(Object? value) {
    if (value == null) return 0.0;
    if (value is num) return _normalizeHourNumber(value.toDouble());
    final raw = '$value';
    final segments = raw.split(':');
    if (segments.length == 3) {
      return (double.tryParse(segments[0]) ?? 0) +
          ((double.tryParse(segments[1]) ?? 0) / 60) +
          ((double.tryParse(segments[2]) ?? 0) / 3600);
    }
    if (segments.length == 2) {
      return (double.tryParse(segments[0]) ?? 0) +
          ((double.tryParse(segments[1]) ?? 0) / 60);
    }
    return _normalizeHourNumber(double.tryParse(raw) ?? 0.0);
  }

  double _normalizeHourNumber(double v) {
    if (v <= 24) return v;
    if (v <= 24 * 60) return v / 60;
    return v / 3600;
  }

  String _addHours(String startTime, double hours) {
    final parts = startTime.split(':');
    if (parts.length < 2 || hours <= 0) return startTime;
    final totalMinutes =
        (int.tryParse(parts[0]) ?? 8) * 60 +
        (int.tryParse(parts[1]) ?? 0) +
        (hours * 60).round();
    final h = '${(totalMinutes ~/ 60) % 24}'.padLeft(2, '0');
    final m = '${totalMinutes % 60}'.padLeft(2, '0');
    return '$h:$m';
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Map<String, dynamic> _normalizeDropdownUser(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);
    final fullName = (normalized['full_name'] ?? normalized['name'] ?? '')
        .toString();
    normalized['full_name'] = fullName;
    normalized['name'] = fullName;
    return normalized;
  }
}
