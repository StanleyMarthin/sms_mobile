/*
Tujuan: Kontrak repository Job Plan untuk legacy flow dan read-only Job Plan V2.
Caller: UI job_plan, countdown integration, dan datasource adapter.
Dependensi: Failure, Either, JobPlan entity.
Main Functions: getPlans, browsePlans, getV2Plan, listV2Plans.
Side Effects: Delegasi data access via implementasi repository.
*/
library;

import 'package:fpdart/fpdart.dart' as fp;
import 'package:sm_system/core/errors/failures.dart';
import '../entities/job_plan.dart';
import '../entities/job_plan_v2_options.dart';

abstract class JobPlanRepository {
  Future<List<JobPlan>> getPlans();

  Future<fp.Either<Failure, List<JobPlan>>> getApprovalQueue({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  });

  /// Returns raw items from the hierarchy endpoint.
  /// No params → divisions, divisionId only → units, both → plans.
  Future<fp.Either<Failure, Map<String, dynamic>>> getApprovalRaw({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  });

  Future<fp.Either<Failure, List<JobPlan>>> browsePlans({
    String? divisionId,
    String? unitId,
    String? role,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  });

  Future<JobPlan> getV2Plan(String planId);

  Future<List<JobPlan>> listV2Plans({
    int page = 1,
    int limit = 20,
    String? unitId,
    String? employeeId,
    String? date,
    String? divisionId,
    String? calendarView,
    String? approvalState,
    String? executionState,
  });

  Future<JobPlan> createV2Plan({
    required String coreId,
    required String employeeId,
    required String taskDate,
    required int plannedStartMinute,
    required int plannedWorkMinutes,
    required String jobDescription,
    required String commandId,
    bool isPriority = false,
    bool isRework = false,
  });

  Future<JobPlan> mutateV2Approval({
    required String planId,
    required String action,
    required CommandMetadata metadata,
    String? employeeId,
    String? taskDate,
    int? plannedStartMinute,
    int? plannedWorkMinutes,
    String? note,
    String? rejectReason,
  });

  Future<JobPlan> monitorV2Plan({
    required String planId,
    required CommandMetadata metadata,
    int? verifiedTotalMinutes,
    int? progressSeen,
    String? note,
  });

  Future<JobPlan> validateV2Plan({
    required String planId,
    required CommandMetadata metadata,
    int? verifiedTotalMinutes,
    int? progressSeen,
    String? note,
  });

  Future<JobPlanV2Options> getV2Options({String? divisionId, String? unitId});

  Future<Map<String, dynamic>> getAdditionalDropdowns({String? divisionId});

  Future<List<Map<String, dynamic>>> getDropdownUsers({
    required String divisionId,
    String? search,
    int limit = 200,
  });

  Future<Map<String, List<Map<String, dynamic>>>> getDropdowns({
    String? divisionId,
    String? carId,
    String? searchUser,
    int userLimit = 200,
  });

  // Drafts
  Future<void> saveDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    bool replaceItems = true,
    String? note,
  });
  Future<Map<String, dynamic>?> getDraft({required String userId});
  Future<void> deleteDraft({required String userId});
  Future<List<String>> submitDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    String? note,
  });

  // Approval
  Future<fp.Either<Failure, JobPlan>> approvePlan({
    required String planId,
    required String userId,
  });

  Future<JobPlan> rejectPlan({
    required String planId,
    required String userId,
    required String rejectNote,
  });

  Future<JobPlan> resubmitPlan({
    required String planId,
    required String userId,
    required List<Map<String, dynamic>> items,
  });

  Future<void> deleteRejectedPlan({
    required String planId,
    required String userId,
  });

  Future<JobPlan> reviewPlan({required String planId, required bool approved});

  Future<JobPlan> updatePlan({
    required String planId,
    required double targetHours,
    required String deadline,
  });

  // Legacy / fallback
  Future<JobPlan> createPlan({
    String coreId = '',
    String carId = '',
    String sourceType = 'ADDITIONAL',
    String sourceRefId = '',
    String? initialStatus,
    bool syncToTasks = false,
    bool isUrgent = false,
    int? panelId,
    required String unitName,
    required String panelName,
    required String assignedDivision,
    required String assignedUserId,
    required String assignedTo,
    required String description,
    required double targetHours,
    double? totalProjectHours,
    String? startDate,
    String? deadlineDate,
    required String workDate,
    required String startTime,
    required String finishTime,
    required bool isOvertime,
    bool isNonTechnicalJob = false,
    required String note,
  });
}
