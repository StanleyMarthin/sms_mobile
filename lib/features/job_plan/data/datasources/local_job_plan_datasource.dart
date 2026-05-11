/*
Tujuan: Datasource lokal/mock job plan untuk development tanpa backend.
Caller: JobPlanRepositoryImpl saat mode mock/local aktif.
Dependensi: Dummy data dan LocalMockApiStore.
Main Functions: saveDraft, getDraft, submitDraft, browsePlans, approval mock.
Side Effects: Mutasi state draft in-memory dan local mock store.
*/
library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';
import 'job_plan_datasource.dart';

class LocalJobPlanDataSource implements JobPlanDataSource {
  LocalJobPlanDataSource({required this.store});
  static final RegExp _legacyPokPattern = RegExp(
    r'(?:^|\|)\s*POK:\s*(.+)$',
    caseSensitive: false,
  );

  final LocalMockApiStore store;
  Map<String, dynamic>? _draft;

  String _draftItemIdentity(Map<String, dynamic> item) {
    final explicitId = (item['draftItemId'] ?? item['draft_item_id'] ?? '')
        .toString()
        .trim();
    if (explicitId.isNotEmpty) return 'id:$explicitId';

    final rejectedId =
        (item['rejectedPlanId'] ?? item['rejected_plan_id'] ?? '')
            .toString()
            .trim();
    if (rejectedId.isNotEmpty) return 'rej:$rejectedId';

    final parts = [
      (item['coreId'] ?? item['core_id'] ?? '').toString().trim(),
      (item['carId'] ?? item['car_id'] ?? '').toString().trim(),
      (item['assignedUserId'] ?? item['assigned_user_id'] ?? '')
          .toString()
          .trim(),
      (item['taskDate'] ?? item['task_date'] ?? '').toString().trim(),
      (item['startTime'] ?? item['start_time'] ?? '').toString().trim(),
      (item['finishTime'] ?? item['finish_time'] ?? '').toString().trim(),
      (item['jobDescription'] ?? item['jobdescription'] ?? '')
          .toString()
          .trim(),
      (item['panelName'] ??
              item['panel_name'] ??
              item['panelCustomNote'] ??
              item['sectionName'] ??
              '')
          .toString()
          .trim(),
    ];
    return parts.join('|');
  }

  Map<String, dynamic> _mergeDraftPayload({
    required Map<String, dynamic>? existingDraft,
    required String userId,
    required String sourceType,
    required List<Map<String, dynamic>> items,
    required bool replaceItems,
    String? note,
  }) {
    final base = Map<String, dynamic>.from(existingDraft ?? const {});
    final existingItems = (base['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();

    final mergedItems = replaceItems
        ? items
        : () {
            final merged = <Map<String, dynamic>>[];
            final indexByKey = <String, int>{};

            void upsert(Map<String, dynamic> item) {
              final key = _draftItemIdentity(item);
              final idx = indexByKey[key];
              if (idx != null) {
                merged[idx] = item;
              } else {
                indexByKey[key] = merged.length;
                merged.add(item);
              }
            }

            for (final item in existingItems) {
              upsert(item);
            }
            for (final item in items) {
              upsert(item);
            }
            return merged;
          }();

    final firstItem = mergedItems.isNotEmpty
        ? mergedItems.first
        : <String, dynamic>{};
    final normalizedNote = _resolveNote(
      note: note ?? base['note']?.toString(),
      jobDescription: _itemJobDescription(firstItem),
      panelName: _itemPanelName(firstItem),
    );

    final sourceTypes = mergedItems
        .map((item) => (item['sourceType'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    return {
      ...base,
      'action': 'save_draft',
      'userId': userId,
      'sourceType': sourceTypes.length == 1
          ? sourceTypes.first
          : sourceTypes.isNotEmpty
          ? 'MIXED'
          : sourceType,
      'note': normalizedNote,
      'items': mergedItems,
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

  Map<String, dynamic> _normalizeDraftPayload(Map<String, dynamic> payload) {
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

  @override
  Future<List<Map<String, dynamic>>> getPlans() async => _loadPlans();

  @override
  Future<List<Map<String, dynamic>>> getApprovalQueue({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final plans = await _loadPlans();
    final pendingPlans = plans.where((plan) {
      final status = (plan['status'] ?? '').toString().toUpperCase();
      if (!status.startsWith('PENDING')) return false;
      if (taskDate != null &&
          (plan['workDate'] ?? plan['taskDate']).toString() != taskDate) {
        return false;
      }
      if (divisionId != null && unitId != null) {
        return (plan['assignedDivision'] ?? '').toString() == divisionId ||
            (plan['divisionId'] ?? '').toString() == divisionId;
      }
      return true;
    }).toList();

    if (divisionId == null) {
      final names = <String>{};
      for (final plan in pendingPlans) {
        names.add(
          (plan['assignedDivision'] ?? plan['divisionName'] ?? '-').toString(),
        );
      }
      return names.map((name) => {'id': name, 'name': name}).toList();
    }

    if (unitId == null) {
      final units = <String, String>{};
      for (final plan in pendingPlans) {
        final id = (plan['carId'] ?? plan['unitName'] ?? '-').toString();
        units[id] = (plan['unitName'] ?? id).toString();
      }
      return units.entries
          .map((entry) => {'id': entry.key, 'unit_name': entry.value})
          .toList();
    }

    return pendingPlans
        .where(
          (plan) => (plan['carId'] ?? plan['unitName']).toString() == unitId,
        )
        .skip(offset)
        .take(limit)
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> browsePlans({
    String? divisionId,
    String? unitId,
    String? role,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final plans = await _loadPlans();
    return plans
        .where(
          (plan) =>
              taskDate == null ||
              (plan['workDate'] ?? plan['taskDate']).toString() == taskDate,
        )
        .skip(offset)
        .take(limit)
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getAdditionalDropdowns({
    String? divisionId,
  }) async {
    final dropdowns = await getDropdowns(divisionId: divisionId);
    return Map<String, dynamic>.from(dropdowns);
  }

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
    _draft = _mergeDraftPayload(
      existingDraft: _draft,
      userId: userId,
      sourceType: sourceType,
      items: normalizedItems,
      replaceItems: replaceItems,
      note: note,
    );
  }

  @override
  Future<Map<String, dynamic>?> getDraft({required String userId}) async =>
      _draft == null
      ? null
      : _normalizeDraftPayload(Map<String, dynamic>.from(_draft!));

  @override
  Future<void> deleteDraft({required String userId}) async {
    _draft = null;
  }

  @override
  Future<List<String>> submitDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    String? note,
  }) async {
    final ids = <String>[];
    final normalizedItems = items
        .map((item) => _normalizeDraftItem(item, draftNote: note))
        .toList();
    for (final item in normalizedItems) {
      final created = await createPlan(
        coreId: (item['coreId'] ?? '').toString(),
        carId: (item['carId'] ?? '').toString(),
        sourceType: sourceType,
        unitName: (item['unitName'] ?? '-').toString(),
        panelName: (item['panelName'] ?? '-').toString(),
        assignedDivision: (item['divisionName'] ?? item['divisionId'] ?? '')
            .toString(),
        assignedUserId: (item['assignedUserId'] ?? '').toString(),
        assignedTo: (item['assignedUserName'] ?? '').toString(),
        description: (item['jobDescription'] ?? item['jobdescription'] ?? '')
            .toString(),
        targetHours:
            double.tryParse((item['targetHours'] ?? 0).toString()) ?? 0,
        workDate: (item['taskDate'] ?? '').toString(),
        startTime: (item['startTime'] ?? '08:00').toString(),
        finishTime: (item['finishTime'] ?? '16:00').toString(),
        isOvertime: item['isOvertime'] == true,
        note: _resolveNote(
          note: item['note']?.toString() ?? note,
          jobDescription: _itemJobDescription(item),
          panelName: _itemPanelName(item),
        ),
      );
      ids.add(created['planId'].toString());
    }
    return ids;
  }

  @override
  Future<Map<String, dynamic>> approvePlan({
    required String planId,
    required String userId,
  }) {
    return reviewPlan(planId: planId, approved: true);
  }

  @override
  Future<Map<String, dynamic>> rejectPlan({
    required String planId,
    required String userId,
    required String rejectNote,
  }) async {
    final plans = await _loadPlans();
    final plan = plans.firstWhere((item) => item['planId'] == planId);
    plan['status'] = 'REJECTED';
    plan['note'] = rejectNote;
    await _savePlans(plans);
    return Map<String, dynamic>.from(plan);
  }

  @override
  Future<Map<String, dynamic>> resubmitPlan({
    required String planId,
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    final plans = await _loadPlans();
    final plan = plans.firstWhere((item) => item['planId'] == planId);
    plan['status'] = 'PENDING_ADV';
    await _savePlans(plans);
    return Map<String, dynamic>.from(plan);
  }

  @override
  Future<void> deleteRejectedPlan({
    required String planId,
    required String userId,
  }) async {
    final plans = await _loadPlans();
    plans.removeWhere(
      (item) => item['planId'] == planId && item['status'] == 'REJECTED',
    );
    await _savePlans(plans);
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> getDropdowns({
    String? divisionId,
    String? carId,
    String? searchUser,
    int userLimit = 200,
  }) async {
    final users = await getDropdownUsers(
      divisionId: divisionId ?? '',
      search: searchUser,
      limit: userLimit,
    );

    final panels = DummyPanels.all
        .where((item) {
          final itemCarId = item['car_id']?.toString();
          if ((carId ?? '').isEmpty) return true;
          return itemCarId == null || itemCarId.isEmpty || itemCarId == carId;
        })
        .map(Map<String, dynamic>.from)
        .toList();

    return {
      'cars': DummyCars.all.map(Map<String, dynamic>.from).toList(),
      'panels': panels,
      'jobTypes': DummyJobTypes.all.map(Map<String, dynamic>.from).toList(),
      'divisions': DummyDivisions.all.map(Map<String, dynamic>.from).toList(),
      'users': users,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getDropdownUsers({
    required String divisionId,
    String? search,
    int limit = 200,
  }) async {
    final normalizedDivision = divisionId.trim();
    final divisionAsInt = int.tryParse(normalizedDivision);
    final normalizedSearch = (search ?? '').trim().toLowerCase();

    final filtered = DummyEmployees.all
        .where((item) {
          final divisionMatches = normalizedDivision.isEmpty
              ? true
              : (divisionAsInt != null
                    ? item['divisionId'] == divisionAsInt
                    : (item['division'] as String?)?.toLowerCase() ==
                          normalizedDivision.toLowerCase());
          if (!divisionMatches) return false;

          if (normalizedSearch.isEmpty) return true;
          final fullName = (item['full_name'] as String? ?? '').toLowerCase();
          final employeeId = (item['employee_id'] as String? ?? '')
              .toLowerCase();
          final id = (item['id'] as String? ?? '').toLowerCase();
          return fullName.contains(normalizedSearch) ||
              employeeId.contains(normalizedSearch) ||
              id.contains(normalizedSearch);
        })
        .take(limit)
        .map(Map<String, dynamic>.from)
        .toList();

    return filtered;
  }

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
    final plans = await _loadPlans();
    final sequence = (plans.length + 1).toString().padLeft(3, '0');
    final normalizedNote = _resolveNote(
      note: note,
      jobDescription: description,
      panelName: panelName,
    );
    final plan = {
      'planId': 'plan-$sequence',
      'coreId': coreId,
      'carId': carId,
      'sourceType': sourceType,
      'sourceRefId': sourceRefId,
      if (isUrgent) 'isUrgent': true,
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
      'status': initialStatus ?? 'PENDING_ADV',
      'note': normalizedNote,
    };
    plans.insert(0, plan);
    await _savePlans(plans);
    if (syncToTasks || (plan['status'] as String?) == 'APPROVED') {
      await _syncApprovedPlan(plan);
    }
    return Map<String, dynamic>.from(plan);
  }

  @override
  Future<Map<String, dynamic>> reviewPlan({
    required String planId,
    required bool approved,
  }) async {
    final plans = await _loadPlans();
    final plan = plans.firstWhere((item) => item['planId'] == planId);
    final status = plan['status'] as String;
    plan['status'] = approved
        ? (status == 'PENDING_ADV' ? 'PENDING_PM' : 'APPROVED')
        : 'REJECTED';
    await _savePlans(plans);
    if (plan['status'] == 'APPROVED') {
      await _syncApprovedPlan(plan);
    }
    return Map<String, dynamic>.from(plan);
  }

  @override
  Future<Map<String, dynamic>> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  }) async {
    final plans = await _loadPlans();
    final plan = plans.firstWhere((item) => item['planId'] == planId);
    final status = (plan['status'] as String?)?.toUpperCase();
    if (status == 'APPROVED') {
      throw StateError('Plan yang sudah di-ACC PM tidak bisa diupdate lagi.');
    }
    plan['targetHours'] = targetHours;
    plan['deadline'] = deadline;
    plan['workDate'] = deadline;
    await _savePlans(plans);
    await _syncApprovedPlan(plan);
    return Map<String, dynamic>.from(plan);
  }

  Future<List<Map<String, dynamic>>> _loadPlans() async {
    final plans = await store.readList(
      key: LocalMockApiStore.jobPlansKey,
      seedBuilder: DummyJobPlans.seedPlans,
    );
    return plans.map((plan) {
      final normalized = Map<String, dynamic>.from(plan);
      normalized['note'] = _resolveNote(
        note: normalized['note']?.toString(),
        jobDescription:
            (normalized['description'] ?? normalized['jobdescription'] ?? '')
                .toString(),
        panelName: (normalized['panelName'] ?? normalized['panel_name'] ?? '')
            .toString(),
      );
      return normalized;
    }).toList();
  }

  Future<void> _savePlans(List<Map<String, dynamic>> plans) {
    return store.writeList(key: LocalMockApiStore.jobPlansKey, value: plans);
  }

  Future<void> _syncApprovedPlan(Map<String, dynamic> plan) async {
    if ((plan['status'] as String?) != 'APPROVED') {
      return;
    }

    final taskRecords = await store.readList(
      key: LocalMockApiStore.taskExecutionKey,
      seedBuilder: DummyTaskExecutionData.seedTasks,
    );
    final taskIndex = taskRecords.indexWhere(
      (item) => item['plandailyId'] == plan['planId'],
    );
    final taskRecord = _taskExecutionFromPlan(plan);
    if (taskIndex >= 0) {
      taskRecords[taskIndex] = taskRecord;
    } else {
      taskRecords.insert(0, taskRecord);
    }
    await store.writeList(
      key: LocalMockApiStore.taskExecutionKey,
      value: taskRecords,
    );

    final viewRecords = await store.readList(
      key: LocalMockApiStore.taskViewKey,
      seedBuilder: DummyTaskViewData.seedTasks,
    );
    final viewIndex = viewRecords.indexWhere(
      (item) => item['planDailyId'] == plan['planId'],
    );
    final viewRecord = _taskViewFromPlan(plan);
    if (viewIndex >= 0) {
      viewRecords[viewIndex] = viewRecord;
    } else {
      viewRecords.insert(0, viewRecord);
    }
    await store.writeList(
      key: LocalMockApiStore.taskViewKey,
      value: viewRecords,
    );
  }

  Map<String, dynamic> _taskExecutionFromPlan(Map<String, dynamic> plan) {
    final assignedUserId = plan['assignedUserId'] as String;
    final employee = DummyEmployees.all.firstWhere(
      (item) => item['id'] == assignedUserId,
      orElse: () => {
        'division': plan['assignedDivision'],
        'full_name': plan['assignedTo'],
      },
    );
    final car = DummyCars.all.firstWhere(
      (item) => item['id'] == plan['carId'],
      orElse: () => {'customer_name': '-'},
    );
    final sourceType = (plan['sourceType'] as String? ?? 'ADDITIONAL')
        .toUpperCase();
    final taskCategory = switch (sourceType) {
      'COUNTDOWN' => 'MAIN',
      'WO' => 'WO',
      'WOV' => 'WOV',
      _ => 'ADDITIONAL',
    };

    return {
      'plandailyId': plan['planId'],
      'isOvertime': plan['isOvertime'] == true,
      'coreId': plan['coreId'] as String? ?? '',
      'carId': plan['carId'] as String? ?? '',
      'unitName': plan['unitName'] as String? ?? '-',
      'ownerName': car['customer_name'] as String? ?? '-',
      'panelName': plan['panelName'] as String? ?? '-',
      'jobName': _jobNameFromDescription(plan['description'] as String? ?? '-'),
      'assignedUserId': assignedUserId,
      'assignedTo':
          employee['full_name'] as String? ??
          plan['assignedTo'] as String? ??
          '-',
      'divisionName':
          employee['division'] as String? ??
          plan['assignedDivision'] as String? ??
          '-',
      'status': 'ASSIGNED',
      'isPanelLocked': false,
      'dailyTargetHours': (plan['targetHours'] as num).toDouble(),
      'targetHoursRevised': (plan['targetHours'] as num).toDouble(),
      'totalActualHours': 0.0,
      'remainingHours': (plan['targetHours'] as num).toDouble(),
      'taskDate': plan['workDate'] as String,
      'createdAt': DateTime.now().toIso8601String(),
      'startedAt': null,
      'completedAt': null,
      'taskCategory': taskCategory,
      'jobDescription': plan['description'] as String? ?? '-',
      'instruction': plan['note'] as String? ?? '',
      'lockedByName': null,
    };
  }

  Map<String, dynamic> _taskViewFromPlan(Map<String, dynamic> plan) {
    final assignedUserId = plan['assignedUserId'] as String;
    final employee = DummyEmployees.all.firstWhere(
      (item) => item['id'] == assignedUserId,
      orElse: () => {
        'division': plan['assignedDivision'],
        'divisionId': 0,
        'full_name': plan['assignedTo'],
      },
    );

    return {
      'planDailyId': plan['planId'],
      'taskDate': plan['workDate'] as String,
      'isOvertime': plan['isOvertime'] == true,
      'division': {
        'divisionId': '${employee['divisionId'] ?? 0}',
        'divisionName':
            employee['division'] as String? ??
            plan['assignedDivision'] as String? ??
            '-',
      },
      'unit': {
        'unitId': plan['carId'] as String? ?? '',
        'unitName': plan['unitName'] as String? ?? '-',
      },
      'employee': {
        'employeeId': assignedUserId,
        'employeeName':
            employee['full_name'] as String? ??
            plan['assignedTo'] as String? ??
            '-',
      },
      'task': {
        'namaPanel': plan['panelName'] as String? ?? '-',
        'jobName': _jobNameFromDescription(
          plan['description'] as String? ?? '-',
        ),
        'jobDescription': plan['description'] as String? ?? '-',
        'note': plan['note'] as String? ?? '',
        'startTime': plan['startTime'] as String? ?? '08:00',
        'targetFinishTime': plan['finishTime'] as String? ?? '12:00',
        'is_rework':
            _isRework(
              plan['description'] as String? ?? '',
              plan['note'] as String? ?? '',
            )
            ? 1
            : 0,
        'breakDuration': 60,
      },
      'status': 'ASSIGNED',
    };
  }

  String _jobNameFromDescription(String description) {
    final normalized = description.trim();
    if (normalized.isEmpty) return 'Task';
    final parts = normalized.split(RegExp(r'\s+'));
    return parts.take(3).join(' ');
  }

  bool _isRework(String description, String note) {
    final haystack = '${description.toUpperCase()} ${note.toUpperCase()}';
    return haystack.contains('REWORK');
  }
}
