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
  Future<JobPlan> createPlan({
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
    return _mapPlan(
      await dataSource.createPlan(
        coreId: coreId,
        carId: carId,
        sourceType: sourceType,
        sourceRefId: sourceRefId,
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
  Future<JobPlan> reviewPlan({required String planId, required bool approved}) async {
    return _mapPlan(await dataSource.reviewPlan(planId: planId, approved: approved));
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
    return JobPlan(
      planId: item['planId'] as String,
      coreId: item['coreId'] as String? ?? '',
      carId: item['carId'] as String? ?? '',
      sourceType: item['sourceType'] as String? ?? 'ADDITIONAL',
      sourceRefId: item['sourceRefId'] as String? ?? '',
      unitName: item['unitName'] as String,
      panelName: item['panelName'] as String,
      assignedDivision: item['assignedDivision'] as String? ?? '',
      assignedUserId: item['assignedUserId'] as String? ?? '',
      assignedTo: item['assignedTo'] as String,
      description: item['description'] as String,
      targetHours: (item['targetHours'] as num).toDouble(),
      workDate: item['workDate'] as String? ?? item['deadline'] as String,
      startTime: item['startTime'] as String? ?? '08:00',
      finishTime: item['finishTime'] as String? ?? '12:00',
      isOvertime: item['isOvertime'] as bool? ?? false,
      deadline: item['deadline'] as String,
      status: item['status'] as String,
      note: item['note'] as String? ?? '',
    );
  }
}