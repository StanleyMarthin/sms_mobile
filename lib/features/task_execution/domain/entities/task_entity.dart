/// TaskEntity represents a mechanic's daily work assignment from the ERP.
///
/// This entity is pure Dart with no Flutter dependencies and serves as the
/// contract between layers. It encapsulates the essential data about a mechanic's
/// daily task, combining data from multiple ERP tables:
/// - trx_jobdesc_plandaily: The daily assignment record
/// - trx_jobdesc_core: The actual job details
/// - trx_car_panel_status: Panel lock status (CRITICAL for business rule #1)
/// - cars: Unit/project information
/// - master_panels: Panel master data
///
/// Following Domain-Driven Design principles, this entity contains only
/// business-critical properties and no implementation details from the data layer.
library;

import 'package:equatable/equatable.dart';

/// Represents a mechanic's daily task assignment from SM Restoration ERP.
///
/// This task appears on the mechanic's dashboard for the current day and combines:
/// 1. Daily assignment info (plandaily_id, assigned date, daily hours)
/// 2. Core job details (what to do, which panel, which car)
/// 3. Lock status (can the mechanic start work?)
///
/// Properties are mapped from ERD tables:
/// - **plandailyId** (trx_jobdesc_plandaily.id): Unique daily assignment ID
/// - **coreId** (trx_jobdesc_core.id): The underlying core job
/// - **carId** (cars.id): Which unit/project this is for
/// - **unitName** (cars.unit_name): Human-readable car identification
/// - **panelName** (master_panels.name): Physical location (e.g., "Fender Kiri")
/// - **jobName** (master_job_types.job_name): What to do (e.g., "Spray cat")
/// - **divisionName** (sm_divisi.name): Division (e.g., "BODY PAINT")
/// - **status** (trx_jobdesc_core.status): Job execution status
/// - **isPanelLocked** (trx_car_panel_status.is_locked): CRITICAL - panel lock status
/// - **dailyTargetHours**: Expected hours for today
/// - **targetHoursRevised**: Total hours allocated (from contract + extensions)
/// - **remainingHours**: Hours still needed to complete job
/// - **taskDate**: Date of this assignment
class TaskEntity extends Equatable {
  /// Unique identifier for this daily assignment record.
  /// From: trx_jobdesc_plandaily.id
  /// Example: "550e8400-e29b-41d4-a716-446655440001"
  final String plandailyId;

  /// The underlying core job this daily assignment is based on.
  /// From: trx_jobdesc_core.id
  final String coreId;

  /// Which car/unit this job is for.
  /// From: cars.id
  final String carId;

  /// Human-readable car identification.
  /// From: cars.unit_name
  /// Example: "Nissan Datsun 1975"
  final String unitName;

  /// Physical panel/location being worked on.
  /// From: master_panels.name
  /// Example: "Fender Kiri", "Pintu Supir", "Ruang Mesin"
  final String panelName;

  /// Type of job to be performed.
  /// From: master_job_types.job_name
  /// Example: "Spray cat", "Sanding", "Fitting", "Turunkan Mesin"
  final String jobName;

  /// Division responsible for this work.
  /// From: sm_divisi.name
  /// Example: "BODY PAINT", "MECHANIC", "BODY WORK"
  final String divisionName;

  /// Current status of the core job.
  /// From: trx_jobdesc_core.status
  /// Valid values: "PROSES", "QC_READY", "DONE"
  final String status;

  /// **CRITICAL BUSINESS RULE #1**: Panel lock status
  /// From: trx_car_panel_status.is_locked
  /// - true: Panel is locked by another mechanic/division → "Start" button DISABLED
  /// - false: Panel is available → "Start" button ENABLED (if status == 'PROSES')
  /// This is the key validation preventing concurrent work on same panel.
  final bool isPanelLocked;

  /// Hours allocated for today's work.
  /// From: trx_jobdesc_plandaily.daily_target_hours
  /// Example: 8.0 hours
  final double dailyTargetHours;

  /// Total hours allocated from contract + all extensions.
  /// From: trx_jobdesc_core.target_hours_revised
  /// Example: 40.0 hours (initial 30 + extension 10)
  final double targetHoursRevised;

  /// Remaining hours to complete the full job.
  /// From: trx_jobdesc_core.remaining_hours
  /// Calculated as: target_hours_revised - total_actual_hours
  /// Example: 15.0 hours left
  final double remainingHours;

  /// Date this assignment was created.
  /// From: trx_jobdesc_plandaily.task_date
  /// ISO 8601 format: "2026-02-20"
  final String taskDate;

  /// ISO 8601 formatted timestamp when this plandaily was created.
  /// From: trx_jobdesc_plandaily.created_at
  final String createdAt;

  /// ISO 8601 formatted timestamp when mechanic started work.
  /// From: trx_jobdesc_actual.start_time (first log for this plandaily)
  /// Null if work hasn't started yet.
  final String? startedAt;

  /// ISO 8601 formatted timestamp when mechanic finished work.
  /// From: trx_jobdesc_actual.finish_time (last completed log)
  /// Null if work is still in progress or not started.
  final String? completedAt;

  /// Task category from trx_jobdesc_core.task_category.
  /// Valid values: "MAIN", "ADDITIONAL", "WO", "WOV"
  final String taskCategory;

  /// Detailed task description from trx_jobdesc_core.custom_description.
  /// Example: "SETTING SHIFT FORK TRANSMISI DAN PENDATAAN PART ORDERAN TRANSMISI"
  final String customDescription;

  /// Name of the mechanic who currently holds the panel lock.
  /// Null if panel is not locked or locked by the current user.
  final String? lockedByName;

  /// Owner / customer name from cars table.
  /// From: cars.owner_name
  /// Example: "Mr. JAMES", "Mr. SILMY"
  final String ownerName;

  /// Total actual hours accumulated across all days.
  /// From: trx_jobdesc_core.total_actual_hours
  final double totalActualHours;

  /// True after OP has submitted at least one monitoring/progress record.
  /// Once set, OP can no longer reopen or resubmit this task from the mobile flow.
  final bool hasMonitoringRecord;

  /// Indicates if this task is a rework
  final bool isRework;

  /// Indicates if this task was performed during overtime
  final bool isOvertime;

  /// Indicates if this task is marked as priority
  final bool isPriority;

  const TaskEntity({
    required this.plandailyId,
    required this.coreId,
    required this.carId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    required this.divisionName,
    required this.status,
    required this.isPanelLocked,
    required this.dailyTargetHours,
    required this.targetHoursRevised,
    required this.remainingHours,
    required this.taskDate,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.taskCategory,
    required this.customDescription,
    this.lockedByName,
    required this.ownerName,
    required this.totalActualHours,
    this.hasMonitoringRecord = false,
    this.isRework = false,
    this.isOvertime = false,
    this.isPriority = false,
  });

  /// Returns true if the mechanic can start this task now.
  /// Business Rule #1: Panel must NOT be locked and task must be assigned/ready.
  /// Also must not already be in progress or completed.
  bool get canStart {
    final normalizedStatus = status.trim().toUpperCase();
    final blockedByOtherWorker = isPanelLocked && lockedByName != null;
    return !blockedByOtherWorker &&
        (normalizedStatus == 'PLAN' ||
            normalizedStatus == 'ASSIGNED' ||
            normalizedStatus == 'PROSES') &&
        !hasMonitoringRecord &&
        !isInProgress &&
        !isCompleted;
  }

  /// Returns true when OP has already submitted the monitoring form.
  bool get isMonitoringLocked => hasMonitoringRecord && !isCompleted;

  /// Returns true if work has started on this task.
  bool get isInProgress {
    final normalizedStatus = status.trim().toUpperCase();
    return (startedAt != null && completedAt == null) ||
        normalizedStatus == 'ONPROGRESS' ||
        normalizedStatus == 'ON_PROGRESS' ||
        normalizedStatus == 'PROSES';
  }

  /// Returns true if work has been completed.
  bool get isCompleted {
    final normalizedStatus = status.trim().toUpperCase();
    return completedAt != null ||
        normalizedStatus == 'READY_QC' ||
        normalizedStatus == 'DONE' ||
        normalizedStatus == 'CANCEL';
  }

  /// Returns progress percentage based on target hours.
  /// Returns progress percentage as double (0-100).
  /// Calculated as: (targetHoursRevised - remainingHours) / targetHoursRevised * 100
  /// If target is 0, returns 0%
  double get progressPercent {
    if (targetHoursRevised <= 0) return 0;
    final hoursUsed = targetHoursRevised - remainingHours;
    return (hoursUsed / targetHoursRevised) * 100;
  }

  /// Returns hours used so far.
  /// Calculated as: targetHoursRevised - remainingHours
  double get hoursUsed => targetHoursRevised - remainingHours;

  /// Compares all properties for equality.
  /// This is critical for BLoC state comparisons and UI rebuilds.
  @override
  List<Object?> get props => [
        plandailyId,
        coreId,
        carId,
        unitName,
        panelName,
        jobName,
        divisionName,
        status,
        isPanelLocked,
        dailyTargetHours,
        targetHoursRevised,
        remainingHours,
        taskDate,
        createdAt,
        startedAt,
        completedAt,
        taskCategory,
        customDescription,
        lockedByName,
        ownerName,
        totalActualHours,
        hasMonitoringRecord,
        isRework,
        isOvertime,
        isPriority,
      ];
}
