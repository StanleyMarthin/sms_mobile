import 'package:equatable/equatable.dart';

/// Represents a task submission payload for POST /api/v1/tasks/submit.
///
/// Maps to `sm_jobdesc_actual` table in the backend.
///
/// The mechanic fills a simple AppSheet-style form with:
/// - Start / finish times (manual time pickers)
/// - Break duration in minutes
/// - Progress percentage (manual number input)
/// - Status dropdown: pending | onprogress | done | cancel
/// - Photos: Before (optional), Process (optional), After (required)
/// - Daily notes (optional free text)
///
/// Backend calculates `duration_hours` automatically.
class TaskExecutionLog extends Equatable {
  /// Reference to the daily assignment.
  /// From: trx_jobdesc_plandaily.id
  final String plandailyId;

  /// ISO 8601 timestamp when mechanic started working.
  /// Example: "2026-03-04T08:00:00Z"
  final String startTime;

  /// ISO 8601 timestamp when mechanic finished working.
  /// Example: "2026-03-04T12:00:00Z"
  final String finishTime;

  /// Break duration in minutes (e.g. 60 = 1 hour lunch break).
  final int breakDurationMinutes;

  /// Current progress percentage (0–100).
  /// Self-reported by the mechanic via manual number input.
  final double progressPercent;

  /// Task status: ENUM('pending', 'onprogress', 'done', 'cancel') DEFAULT 'pending'.
  final String status;

  /// File path to the "Before" photo (optional).
  final String? photoBefore;

  /// File path to the "Process" photo (optional).
  final String? photoProcess;

  /// File path to the "After" photo (required).
  final String? photoAfter;

  /// Optional daily notes / catatan harian.
  final String? dailyNotes;

  const TaskExecutionLog({
    required this.plandailyId,
    required this.startTime,
    required this.finishTime,
    required this.breakDurationMinutes,
    required this.progressPercent,
    required this.status,
    this.photoBefore,
    this.photoProcess,
    this.photoAfter,
    this.dailyNotes,
  });

  /// Whether this submission marks the job as done.
  bool get isDone => status == 'done';

  @override
  List<Object?> get props => [
        plandailyId,
        startTime,
        finishTime,
        breakDurationMinutes,
        progressPercent,
        status,
        photoBefore,
        photoProcess,
        photoAfter,
        dailyNotes,
      ];
}
