library;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/countdown_entities.dart';
import '../widgets/countdown_shared.dart';

/// Visual representation of a countdown status.
class CountdownStatusVisual {
  const CountdownStatusVisual({
    required this.color,
    required this.icon,
    required this.shortLabel,
    required this.longLabel,
  });

  final Color color;
  final IconData icon;
  final String shortLabel;
  final String longLabel;
}

/// Stateless utility class for countdown feature helpers.
class CountdownHelper {
  // Not instantiable.
  CountdownHelper._();

  // ── Status helpers ────────────────────────────────────────

  /// Returns the effective display status of a [CountdownJobdesc],
  /// taking QC and revision data into account.
  static String effectiveCountdownStatus(CountdownJobdesc item) {
    final raw = item.status.toLowerCase();
    if (raw == 'done') return 'DONE';
    if (raw == 'qcready' || raw == 'qc_ready' || raw == 'ready_qc') {
      return 'QC READY';
    }
    if (item.qcLastStatus?.toLowerCase() == 'lolos') return 'DONE';
    if (raw == 'proses') return 'PROSES';
    return item.status.toUpperCase();
  }

  /// Returns true when workshop execution is finished, including items that
  /// are already waiting for QC after reaching 100% progress.
  static bool isWorkCompleted(CountdownJobdesc item) {
    final effectiveStatus = effectiveCountdownStatus(item).toUpperCase();
    return effectiveStatus == 'DONE' ||
        effectiveStatus == 'QC READY' ||
        item.progress >= 100;
  }

  /// Returns visual data (color, icon, label) for a given status string.
  static CountdownStatusVisual statusVisual(String status) {
    switch (status.toUpperCase()) {
      case 'DONE':
        return const CountdownStatusVisual(
          color: AppColors.statusDone,
          icon: Icons.check_circle_rounded,
          shortLabel: 'Done',
          longLabel: 'Selesai',
        );
      case 'QC READY':
      case 'QCREADY':
      case 'QC_READY':
      case 'READY_QC':
        return const CountdownStatusVisual(
          color: AppColors.gold,
          icon: Icons.verified_rounded,
          shortLabel: 'QC Ready',
          longLabel: 'Menunggu QC',
        );
      case 'PROSES':
        return const CountdownStatusVisual(
          color: AppColors.statusInProgress,
          icon: Icons.timelapse_rounded,
          shortLabel: 'Proses',
          longLabel: 'Sedang Proses',
        );
      case 'PLAN':
        return const CountdownStatusVisual(
          color: AppColors.textMuted,
          icon: Icons.schedule_rounded,
          shortLabel: 'Plan',
          longLabel: 'Belum Mulai',
        );
      default:
        return CountdownStatusVisual(
          color: AppColors.textSecondary,
          icon: Icons.help_outline_rounded,
          shortLabel: status,
          longLabel: status,
        );
    }
  }

  /// Returns a human-readable label for status/progress filter values.
  static String statusProgressLabel(String value) {
    switch (value) {
      case 'all':
        return 'Semua Status';
      case 'plan':
        return 'Belum Mulai (Plan)';
      case 'proses':
        return 'Sedang Proses';
      case 'qcready':
        return 'QC Ready';
      case 'done':
        return 'Selesai';
      case 'below50':
        return 'Progress < 50%';
      case 'above50':
        return 'Progress ≥ 50%';
      case 'full':
        return 'Progress 100%';
      default:
        return value;
    }
  }

  // ── Filter helpers ─────────────────────────────────────────

  /// Checks whether a [CountdownJobdesc] matches the given status/progress
  /// filter value.
  static bool matchesStatusProgressWithValue(
      CountdownJobdesc item, String filterValue) {
    if (filterValue == 'all') return true;
    final effective = effectiveCountdownStatus(item).toUpperCase();
    switch (filterValue) {
      case 'plan':
        return effective == 'PLAN';
      case 'proses':
        return effective == 'PROSES';
      case 'qcready':
        return effective == 'QC READY' ||
            effective == 'QCREADY' ||
            effective == 'READY_QC';
      case 'done':
        return effective == 'DONE';
      case 'below50':
        return item.progress < 50;
      case 'above50':
        return item.progress >= 50;
      case 'full':
        return item.progress >= 100;
      default:
        return true;
    }
  }

  /// Returns the count of active (non-default) filters.
  static int activeFilterCount({
    required String selectedSection,
    required String selectedPanel,
    required String selectedStatus,
    required String selectedSort,
  }) {
    int count = 0;
    if (selectedSection != 'all') count++;
    if (selectedPanel != 'all') count++;
    if (selectedStatus != 'all') count++;
    if (selectedSort != 'deadline_asc') count++;
    return count;
  }

  /// Returns human-readable labels for active filters.
  static List<String> activeFilterLabels({
    required String selectedSection,
    required String selectedPanel,
    required String selectedStatus,
    required String selectedSort,
  }) {
    final labels = <String>[];
    if (selectedSection != 'all') labels.add('Section: $selectedSection');
    if (selectedPanel != 'all') labels.add('Panel: $selectedPanel');
    if (selectedStatus != 'all') {
      labels.add(statusProgressLabel(selectedStatus));
    }
    if (selectedSort != 'deadline_asc') labels.add(_sortLabel(selectedSort));
    return labels;
  }

  static String _sortLabel(String value) {
    switch (value) {
      case 'deadline_desc':
        return 'Deadline Terjauh';
      case 'progress_desc':
        return 'Progress Tertinggi';
      case 'progress_asc':
        return 'Progress Terendah';
      case 'panel_asc':
        return 'Panel A-Z';
      default:
        return 'Deadline Terdekat';
    }
  }

  // ── Date / time helpers ────────────────────────────────────

  /// Formats a [DateTime] or date-string (yyyy-MM-dd) to a human-readable form.
  /// Accepts [DateTime] or [String] (duck-typed via [Object?]).
  static String formatDate(Object? date) {
    if (date == null) return '-';
    if (date is DateTime) {
      return _formatDateParts(
          date.year.toString(),
          date.month.toString().padLeft(2, '0'),
          date.day.toString().padLeft(2, '0'));
    }
    final str = '$date';
    if (str.isEmpty) return '-';
    final parts = str.split('-');
    if (parts.length < 3) return str;
    return _formatDateParts(parts[0], parts[1], parts[2]);
  }

  static String _formatDateParts(String year, String month, String day) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final m = int.tryParse(month) ?? 0;
    return '${day.replaceAll('-', '').padLeft(2, '0')} ${m < months.length ? months[m] : month} $year';
  }

  /// Formats a [TimeOfDay] or time-string (HH:mm or HH:mm:ss) to HH:mm.
  /// Accepts [TimeOfDay] or [String] (duck-typed via [Object?]).
  static String formatTime(Object? time) {
    if (time == null) return '-';
    if (time is TimeOfDay) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    final str = '$time';
    if (str.isEmpty) return '-';
    final parts = str.split(':');
    if (parts.length < 2) return str;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  /// Formats hours to a string including workdays (1 day = 8 hours).
  static String formatWorkHours(double hours) {
    if (hours <= 0) return '0j';
    
    // Jika kurang dari 1 jam, tampilkan menit
    if (hours < 1.0) {
      final mins = (hours * 60).round();
      return '${mins}m';
    }
    
    final hrsStr = hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1);
    
    // Hanya tampilkan hari jika durasi cukup signifikan (misal >= 4 jam / 0.5 hari)
    if (hours >= 4.0) {
      final workDays = hours / 8.0;
      final daysStr = workDays.toStringAsFixed(workDays.truncateToDouble() == workDays ? 0 : 2);
      return '${hrsStr}j (${daysStr} hari)';
    }
    
    return '${hrsStr}j';
  }

  /// Returns break duration in minutes for a given [date].
  /// Mon–Thu & Sat: 60 min (12:00–13:00)
  /// Fri: 90 min (11:30–13:00)
  /// Sun: 0 min
  static int breakMinutesForDate(DateTime date) {
    return switch (date.weekday) {
      DateTime.friday => 90,
      DateTime.sunday => 0,
      _ => 60,
    };
  }

  /// Break start time in minutes from midnight for a given [date].
  static int breakStartMinutesForDate(DateTime date) {
    return date.weekday == DateTime.friday
        ? 11 * 60 + 30   // 11:30
        : 12 * 60;       // 12:00
  }

  /// Returns true if finish time is into overtime territory based on day of week.
  /// Mon–Fri: > 17:00
  /// Sat: > 14:00
  /// Sun: Always true (overtime)
  static bool isOvertimeByTime(TimeOfDay finishTime, {DateTime? date}) {
    final refDate = date ?? DateTime.now();
    final hour = finishTime.hour;
    final minute = finishTime.minute;

    if (refDate.weekday == DateTime.sunday) return true;

    if (refDate.weekday == DateTime.saturday) {
      return hour > 14 || (hour == 14 && minute > 0);
    }

    // Mon-Fri
    return hour > 17 || (hour == 17 && minute > 0);
  }

  /// Returns the "Normal" threshold time for a given [date].
  /// Mon-Fri: 17:00
  /// Sat: 14:00
  static TimeOfDay normalThresholdForDate(DateTime date) {
    if (date.weekday == DateTime.saturday) {
      return const TimeOfDay(hour: 14, minute: 0);
    }
    return const TimeOfDay(hour: 17, minute: 0);
  }

  /// Calculates finish time given start time and work duration.
  /// Automatically adds break time (based on [date]) if the work period
  /// overlaps the rest window.
  /// [date] defaults to today when null (break calculation only).
  static TimeOfDay calculateFinishTime({
    required TimeOfDay startTime,
    required double durationHours,
    DateTime? date,
  }) {
    final startMins = startTime.hour * 60 + startTime.minute;
    final workMins = (durationHours * 60).round();

    var extra = 0;
    final refDate = date ?? DateTime.now();
    final breakStart = breakStartMinutesForDate(refDate);
    const breakEnd = 13 * 60; // always 13:00
    final breakDuration = breakMinutesForDate(refDate);
    if (breakDuration > 0 &&
        startMins < breakEnd &&
        (startMins + workMins) > breakStart) {
      extra = breakDuration;
    }

    final totalMins = startMins + workMins + extra;
    return TimeOfDay(hour: (totalMins ~/ 60) % 24, minute: totalMins % 60);
  }

  // ── Revision helpers ───────────────────────────────────────

  /// Returns a [RevisionBannerData] for the revision status of a [CountdownJobdesc],
  /// or null if no banner should be shown.
  static RevisionBannerData? revisionStatusBanner(CountdownJobdesc item) {
    final status = item.revisionRequestStatus?.toUpperCase();
    switch (status) {
      case 'REQUESTED':
        return RevisionBannerData(
          color: AppColors.orange,
          icon: Icons.hourglass_top_rounded,
          title: 'Menunggu Persetujuan Revisi',
          detail:
              'Permintaan +${item.requestedRevisionHours?.toStringAsFixed(1) ?? '?'} jam'
              '${item.requestedRevisionDeadline != null ? " • DL ${item.requestedRevisionDeadline}" : ""}',
        );
      case 'APPROVED':
        return RevisionBannerData(
          color: AppColors.statusDone,
          icon: Icons.check_circle_rounded,
          title: 'Revisi Disetujui',
          detail:
              '+${item.approvedRevisionHours?.toStringAsFixed(1) ?? '?'} jam'
              '${item.approvedRevisionDeadline != null ? " • DL baru ${item.approvedRevisionDeadline}" : ""}',
        );
      case 'REJECTED':
        return RevisionBannerData(
          color: AppColors.statusLocked,
          icon: Icons.cancel_rounded,
          title: 'Revisi Ditolak',
          detail: 'Oleh ${item.rejectedRevisionByName ?? "PM"}',
        );
      default:
        return null;
    }
  }
}
