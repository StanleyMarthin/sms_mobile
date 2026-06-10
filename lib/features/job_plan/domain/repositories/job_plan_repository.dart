library;

import 'package:fpdart/fpdart.dart' as fp;
import 'package:sm_system/core/errors/failures.dart';
import '../entities/job_plan.dart';

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
    required String note,
  });
}
