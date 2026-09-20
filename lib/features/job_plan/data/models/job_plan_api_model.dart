/*
Tujuan: Model parser kontrak read-only Job Plan dari backend.
Caller: JobPlanRepositoryImpl dan test model V2.
Dependensi: JobPlan entity.
Main Functions: JobPlanApiModel.fromJson, toEntity.
Side Effects: Tidak ada.
*/
library;

import '../../domain/entities/job_plan.dart';

class JobPlanApiModel {
  const JobPlanApiModel({required this.json});

  factory JobPlanApiModel.fromJson(Map<String, dynamic> json) {
    return JobPlanApiModel(json: json);
  }

  final Map<String, dynamic> json;

  JobPlan toEntity() {
    final planId = _string(['planId', 'plan_id', 'id']);
    final coreId = _string(['coreId', 'core_id']);
    final employeeId = _string([
      'employeeId',
      'employee_id',
      'assignedUserId',
      'assigned_user_id',
    ]);
    final employeeName = _string([
      'employeeName',
      'employee_name',
      'assignedUserName',
      'assignedTo',
    ]);
    final taskDate = _string(['taskDate', 'task_date', 'workDate']);
    final startMinute =
        _int('startMinute', 'plannedStartMinute', 'planned_start_minute') ?? 0;
    final durationMinutes =
        _int('durationMinutes', 'plannedWorkMinutes', 'planned_work_minutes') ??
        _durationFromFinish(startMinute) ??
        (_hours('dailyTargetHours', 'targetHours') * 60).round();
    final startTime = _minuteLabel(startMinute);
    final finishTime = _minuteLabel(startMinute + durationMinutes);
    final description = _string([
      'countdownName',
      'countdown_name',
      'jobdescription',
      'description',
    ]);

    return JobPlan(
      planId: planId,
      coreId: coreId,
      carId: _string(['unitId', 'unit_id', 'carId', 'car_id']),
      sourceType: _string(['sourceType', 'source_type'], fallback: 'COUNTDOWN'),
      sourceId: _string(['sourceId', 'source_id'], fallback: coreId),
      sourceRefId: _string(['sourceRefId', 'source_ref_id'], fallback: coreId),
      unitName: _string(['unitName', 'unit_name']),
      panelName: _string(['panelName', 'panel_name']),
      panelId: _string(['panelId', 'panel_id']),
      unitId: _string(['unitId', 'unit_id', 'carId', 'car_id']),
      countdownName: description,
      assignedDivision: _string(['divisionName', 'division_name']),
      assignedUserId: employeeId,
      assignedTo: employeeName,
      employeeId: employeeId,
      employeeName: employeeName,
      description: description,
      targetHours: durationMinutes / 60,
      workDate: taskDate,
      taskDate: taskDate,
      startTime: startTime,
      finishTime: finishTime,
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      isOvertime: _bool('isOvertime', 'is_overtime'),
      deadline: _string(['deadline'], fallback: taskDate),
      status: _string(['legacy_status', 'approvalState', 'approval_state']),
      approvalState: _string(['approvalState', 'approval_state']),
      executionState: _string(['executionState', 'execution_state']),
      ledgerState: _string(['ledgerState', 'ledger_state']),
      version: _int('version') ?? 0,
      readSource: _string(['source']),
      readOnly: _bool('readOnly', 'read_only'),
      createdAt: DateTime.tryParse(_string(['createdAt', 'created_at'])),
      updatedAt: DateTime.tryParse(_string(['updatedAt', 'updated_at'])),
      waitingFor: _string(['waitingFor', 'waiting_for']),
      currentApproverType: _string([
        'currentApproverType',
        'current_approver_type',
      ]),
      accumulatedMinutes:
          _int('accumulatedMinutes', 'accumulated_work_minutes') ?? 0,
      verifiedMinutes:
          _int(
            'verifiedMinutes',
            'persisted_work_minutes',
            'verified_minutes',
          ) ??
          0,
      unverifiedMinutes:
          _int(
            'unverifiedMinutes',
            'unverified_work_minutes',
            'unverifiedWorkMinutes',
          ) ??
          0,
      countdownTargetMinutes:
          _int(
            'countdownTargetMinutes',
            'countdown_target_minutes',
            'targetMinutes',
          ) ??
          0,
      note: _string(['note']),
    );
  }

  String _string(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = json[key];
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  int? _int(String first, [String? second, String? third]) {
    for (final key in [
      first,
      if (second != null) second,
      if (third != null) third,
    ]) {
      final value = json[key];
      if (value is num) return value.round();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  double _hours(String first, String second) {
    for (final key in [first, second]) {
      final value = json[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  bool _bool(String first, String second) {
    final value = json[first] ?? json[second];
    if (value is bool) return value;
    if (value is num) return value == 1;
    return value?.toString().toLowerCase() == 'true';
  }

  int? _durationFromFinish(int startMinute) {
    final finish = _int(
      'finishMinute',
      'plannedFinishMinute',
      'planned_finish_minute',
    );
    if (finish == null || finish <= startMinute) return null;
    return finish - startMinute;
  }

  String _minuteLabel(int minute) {
    final normalized = minute.clamp(0, 24 * 60);
    final h = '${normalized ~/ 60}'.padLeft(2, '0');
    final m = '${normalized % 60}'.padLeft(2, '0');
    return '$h:$m';
  }
}
