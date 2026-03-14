library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';
import 'job_plan_datasource.dart';

class LocalJobPlanDataSource implements JobPlanDataSource {
  LocalJobPlanDataSource({required this.store});

  final LocalMockApiStore store;

  @override
  Future<List<Map<String, dynamic>>> getPlans() async => _loadPlans();

  @override
  Future<Map<String, dynamic>> createPlan({
    String coreId = '',
    String carId = '',
    String sourceType = 'ADDITIONAL',
    String sourceRefId = '',
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
    final plan = {
      'planId': 'plan-$sequence',
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
      'status': 'PENDING_ADV',
      'note': note,
    };
    plans.insert(0, plan);
    await _savePlans(plans);
    return Map<String, dynamic>.from(plan);
  }

  @override
  Future<Map<String, dynamic>> reviewPlan({required String planId, required bool approved}) async {
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

  Future<List<Map<String, dynamic>>> _loadPlans() {
    return store.readList(
      key: LocalMockApiStore.jobPlansKey,
      seedBuilder: DummyJobPlans.seedPlans,
    );
  }

  Future<void> _savePlans(List<Map<String, dynamic>> plans) {
    return store.writeList(
      key: LocalMockApiStore.jobPlansKey,
      value: plans,
    );
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
      orElse: () => {
        'customer_name': '-',
      },
    );
    final sourceType = (plan['sourceType'] as String? ?? 'ADDITIONAL').toUpperCase();
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
      'assignedTo': employee['full_name'] as String? ?? plan['assignedTo'] as String? ?? '-',
      'divisionName': employee['division'] as String? ?? plan['assignedDivision'] as String? ?? '-',
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
      'customDescription': plan['description'] as String? ?? '-',
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
        'divisionName': employee['division'] as String? ?? plan['assignedDivision'] as String? ?? '-',
      },
      'unit': {
        'unitId': plan['carId'] as String? ?? '',
        'unitName': plan['unitName'] as String? ?? '-',
      },
      'employee': {
        'employeeId': assignedUserId,
        'employeeName': employee['full_name'] as String? ?? plan['assignedTo'] as String? ?? '-',
      },
      'task': {
        'namaPanel': plan['panelName'] as String? ?? '-',
        'jobName': _jobNameFromDescription(plan['description'] as String? ?? '-'),
        'jobDescription': plan['description'] as String? ?? '-',
        'startTime': plan['startTime'] as String? ?? '08:00',
        'targetFinishTime': plan['finishTime'] as String? ?? '12:00',
        'is_rework': _isRework(plan['description'] as String? ?? '', plan['note'] as String? ?? '') ? 1 : 0,
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