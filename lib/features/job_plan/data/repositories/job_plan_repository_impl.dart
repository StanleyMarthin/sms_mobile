/*
Tujuan: Adapter repository job plan dari datasource ke entity domain.
Caller: UI job plan melalui dependency injection.
Dependensi: JobPlanDataSource dan entity JobPlan.
Main Functions: mapping browse/draft/approval response ke JobPlan.
Side Effects: HTTP/mock I/O melalui datasource.
*/
library;

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../datasources/job_plan_datasource.dart';

class JobPlanRepositoryImpl implements JobPlanRepository {
  const JobPlanRepositoryImpl({required this.dataSource});

  final JobPlanDataSource dataSource;

  @override
  Future<List<JobPlan>> getPlans() async {
    final plans = await dataSource.getPlans();
    return plans.map(_mapPlan).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getApprovalQueue({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) {
    return dataSource.getApprovalQueue(
      divisionId: divisionId,
      unitId: unitId,
      taskDate: taskDate,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> getDropdowns({
    String? divisionId,
    String? carId,
    String? searchUser,
    int userLimit = 200,
  }) {
    return dataSource.getDropdowns(
      divisionId: divisionId,
      carId: carId,
      searchUser: searchUser,
      userLimit: userLimit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getDropdownUsers({
    required String divisionId,
    String? search,
    int limit = 200,
  }) {
    return dataSource.getDropdownUsers(
      divisionId: divisionId,
      search: search,
      limit: limit,
    );
  }

  @override
  Future<List<JobPlan>> browsePlans({
    String? divisionId,
    String? unitId,
    String? role,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final maps = await dataSource.browsePlans(
      divisionId: divisionId,
      unitId: unitId,
      role: role,
      taskDate: taskDate,
      limit: limit,
      offset: offset,
    );
    return maps.map(_mapPlan).toList();
  }

  @override
  Future<Map<String, dynamic>> getAdditionalDropdowns({String? divisionId}) {
    return dataSource.getAdditionalDropdowns(divisionId: divisionId);
  }

  @override
  Future<void> saveDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    bool replaceItems = true,
    String? note,
  }) {
    return dataSource.saveDraft(
      userId: userId,
      items: items,
      sourceType: sourceType,
      replaceItems: replaceItems,
      note: note,
    );
  }

  @override
  Future<Map<String, dynamic>?> getDraft({required String userId}) {
    return dataSource.getDraft(userId: userId);
  }

  @override
  Future<void> deleteDraft({required String userId}) {
    return dataSource.deleteDraft(userId: userId);
  }

  @override
  Future<List<String>> submitDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    String? note,
  }) {
    return dataSource.submitDraft(
      userId: userId,
      items: items,
      sourceType: sourceType,
      note: note,
    );
  }

  @override
  Future<JobPlan> approvePlan({
    required String planId,
    required String userId,
  }) async {
    final result = await dataSource.approvePlan(planId: planId, userId: userId);
    return _mapPlan(result);
  }

  @override
  Future<JobPlan> rejectPlan({
    required String planId,
    required String userId,
    required String rejectNote,
  }) async {
    final result = await dataSource.rejectPlan(
      planId: planId,
      userId: userId,
      rejectNote: rejectNote,
    );
    return _mapPlan(result);
  }

  @override
  Future<JobPlan> resubmitPlan({
    required String planId,
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    final result = await dataSource.resubmitPlan(
      planId: planId,
      userId: userId,
      items: items,
    );
    return _mapPlan(result);
  }

  @override
  Future<void> deleteRejectedPlan({
    required String planId,
    required String userId,
  }) async {
    return dataSource.deleteRejectedPlan(planId: planId, userId: userId);
  }

  @override
  Future<JobPlan> createPlan({
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
    return _mapPlan(
      await dataSource.createPlan(
        coreId: coreId,
        carId: carId,
        sourceType: sourceType,
        sourceRefId: sourceRefId,
        initialStatus: initialStatus,
        syncToTasks: syncToTasks,
        isUrgent: isUrgent,
        unitName: unitName,
        panelName: panelName,
        assignedDivision: assignedDivision,
        assignedUserId: assignedUserId,
        assignedTo: assignedTo,
        description: description,
        targetHours: targetHours,
        workDate: workDate,
        startTime: startTime,
        finishTime: finishTime,
        isOvertime: isOvertime,
        note: note,
      ),
    );
  }

  @override
  Future<JobPlan> reviewPlan({
    required String planId,
    required bool approved,
  }) async {
    return _mapPlan(
      await dataSource.reviewPlan(planId: planId, approved: approved),
    );
  }

  @override
  Future<JobPlan> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  }) async {
    return _mapPlan(
      await dataSource.updatePlan(
        planId: planId,
        targetHours: targetHours,
        deadline: deadline,
      ),
    );
  }

  JobPlan _mapPlan(Map<String, dynamic> item) {
    final targetHours = _parseHours(
      item['targetHours'] ?? item['target_hours'] ?? item['dailyTargetHours'],
    );
    final startTime =
        _normalizeTime(
          item['startTime'] ?? item['start_time'] ?? item['targetStartHours'],
        ) ??
        '08:00';
    final finishTime =
        _normalizeTime(
          item['finishTime'] ??
              item['finish_time'] ??
              item['targetFinishHours'],
        ) ??
        _addHours(startTime, targetHours);

    return JobPlan(
      planId: (item['planId'] ?? item['id'] ?? '').toString(),
      coreId: (item['coreId'] ?? item['core_id'] ?? '').toString(),
      carId: (item['carId'] ?? item['car_id'] ?? '').toString(),
      sourceType: (item['sourceType'] ?? item['source_type'] ?? 'ADDITIONAL')
          .toString(),
      sourceRefId: (item['sourceRefId'] ?? item['source_ref_id'] ?? '')
          .toString(),
      unitName: (item['unitName'] ?? item['unit_name'] ?? '').toString(),
      panelName: (item['panelName'] ?? item['panel_name'] ?? '').toString(),
      assignedDivision:
          (item['assignedDivision'] ?? item['assigned_division'] ?? '')
              .toString(),
      assignedUserId: (item['assignedUserId'] ?? item['assigned_user_id'] ?? '')
          .toString(),
      assignedTo:
          (item['assignedUserName'] ??
                  item['assignedTo'] ??
                  item['assigned_to'] ??
                  '')
              .toString(),
      description: (item['jobdescription'] ?? item['description'] ?? '')
          .toString(),
      targetHours: targetHours,
      workDate:
          (item['workDate'] ??
                  item['work_date'] ??
                  item['deadline'] ??
                  item['taskDate'] ??
                  item['task_date'] ??
                  '')
              .toString(),
      startTime: startTime,
      finishTime: finishTime,
      isOvertime:
          (item['isOvertime'] ?? item['is_overtime'] ?? false) == true ||
          (item['isOvertime'] ?? item['is_overtime'] ?? 0) == 1,
      deadline:
          (item['deadline'] ??
                  item['deadlineDate'] ??
                  item['deadline_date'] ??
                  '')
              .toString(),
      status: _normalizeApprovalStatus((item['status'] ?? '').toString()),
      note: (item['note'] ?? '').toString(),
      panelCustomNote:
          item['panelCustomNote']?.toString() ??
          item['panel_custom_note']?.toString(),
      rejectNote:
          item['rejectNote']?.toString() ?? item['reject_note']?.toString(),
      targetHoursAlias:
          item['targetHours_alias']?.toString() ??
          item['target_hours_alias']?.toString() ??
          item['dailyTargetHours_alias']?.toString(),
      remainingHoursAlias:
          item['remainingHours_alias']?.toString() ??
          item['remaining_hours_alias']?.toString(),
    );
  }

  String _normalizeApprovalStatus(String rawStatus) {
    return switch (rawStatus.trim().toUpperCase()) {
      'PENDING_PM' ||
      'PENDING_MANAGER' ||
      'PENDING_MP_APPROVAL' ||
      'MENUNGGU MP' => 'PENDING_MP',
      'PENDING_PROJECT_HEAD' ||
      'PENDING_KEPALA_PROJECT' ||
      'PENDING_KP_APPROVAL' ||
      'MENUNGGU KP' => 'PENDING_KP',
      'PENDING_ADVISOR' ||
      'PENDING_ADVISOR_APPROVAL' ||
      'MENUNGGU ADV' => 'PENDING_ADV',
      final s => s,
    };
  }

  String? _normalizeTime(Object? value) {
    if (value == null) return null;
    if (value is num) return _secondsToTime(value.toDouble());
    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
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

  double _parseHours(Object? value) {
    if (value == null) return 0.0;
    if (value is num) return _normalizeHourNumber(value.toDouble());
    final raw = value.toString().trim();
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

  double _normalizeHourNumber(double value) {
    if (value <= 24) return value;
    if (value <= 24 * 60) return value / 60;
    return value / 3600;
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
}
