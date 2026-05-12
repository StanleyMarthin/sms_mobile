/*
Tujuan: Kartu task mekanik dengan status, progress realtime, dan CTA mulai/selesaikan.
Caller: TaskListPage dan _MechanicJobdescPage.
Dependensi: AppColors, AlarmTimerService, TaskEntity, TaskExecutionDetailSheet.
Main Functions: build, _buildProgressBar, _buildActionButton, _RealtimeProgressBar.
Side Effects: Men-trigger alarm pengingat visual/audio saat timer kerja mendekati habis.
*/
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/alarm_timer_service.dart';
import '../../domain/entities/task_entity.dart';
import './task_execution_detail_sheet.dart';

double _taskDisplayTargetHours(TaskEntity task) {
  if (task.dailyTargetHours > 0) return task.dailyTargetHours;
  final startMinutes = _clockMinutes(task.startTime);
  final finishMinutes = _clockMinutes(task.targetFinishTime);
  if (startMinutes != null &&
      finishMinutes != null &&
      finishMinutes >= startMinutes) {
    return (finishMinutes - startMinutes) / 60.0;
  }
  if (task.targetHoursRevised > 0) return task.targetHoursRevised;
  return 0.0;
}

double _taskOverallTargetHours(TaskEntity task) {
  if (task.targetHoursRevised > 0) return task.targetHoursRevised;
  return _taskDisplayTargetHours(task);
}

int? _clockMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour * 60) + minute;
}

double _taskRecordedWorkedHours(TaskEntity task) {
  final target = _taskOverallTargetHours(task);
  final clampMax = target > 0 ? target : 9999.0;
  return task.hoursUsed.clamp(0.0, clampMax);
}

String _formatCompactHours(double decimalHours) {
  final totalMinutes = (decimalHours * 60).round();
  if (totalMinutes <= 0) return '-';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0 && minutes > 0) {
    return '${hours}j ${minutes}m';
  }
  if (hours > 0) {
    return '${hours}j';
  }
  return '${minutes}m';
}

String _formatHoursWithDayAlias(double decimalHours) {
  if (decimalHours <= 0) return '-';
  final compact = _formatCompactHours(decimalHours);
  final dayValue = decimalHours / 8.0;
  final dayText = dayValue == dayValue.roundToDouble()
      ? dayValue.toStringAsFixed(0)
      : dayValue.toStringAsFixed(dayValue < 1 ? 2 : 1);
  return '$compact ($dayText hari)';
}

String _formatTaskClock(String? isoDate) {
  if (isoDate == null || isoDate.trim().isEmpty) return '--:--';

  final parsed = DateTime.tryParse(isoDate);
  if (parsed != null) {
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  final timePart = isoDate.split('T').last;
  if (timePart.length >= 5) {
    return timePart.substring(0, 5);
  }
  return '--:--';
}

String _formatPlanClock(String value) {
  if (value.trim().isEmpty) return '--:--';
  final minutes = _clockMinutes(value);
  if (minutes == null) return '--:--';
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatPlanWindow(TaskEntity task) {
  final start = _formatPlanClock(task.startTime);
  final finish = _formatPlanClock(task.targetFinishTime);
  if (start == '--:--' && finish == '--:--') return '-';
  return '$start-$finish';
}

String _formatActualWindow(TaskEntity task) {
  final start = _formatTaskClock(task.startedAt);
  final finish = _formatTaskClock(task.completedAt);
  if (start == '--:--' && finish == '--:--') return '-';
  return '$start-$finish';
}

double _taskCurrentSessionHours(TaskEntity task) {
  final startedAt = task.startedAt;
  if (startedAt == null || startedAt.isEmpty) return 0.0;

  final parsedStart = DateTime.tryParse(startedAt);
  if (parsedStart == null) return 0.0;

  final parsedFinish = (task.completedAt == null || task.completedAt!.isEmpty)
      ? DateTime.now()
      : (DateTime.tryParse(task.completedAt!) ?? DateTime.now());
  return parsedFinish.difference(parsedStart).inSeconds / 3600.0;
}

class TaskCard extends StatelessWidget {
  final TaskEntity task;
  final bool isActionLoading;
  final bool hasDraft;
  final bool isHighlighted;
  final VoidCallback? onStartPressed;
  final VoidCallback? onFinishPressed;
  final VoidCallback? onTap;
  final VoidCallback? onViewDetail;
  final EdgeInsetsGeometry margin;

  const TaskCard({
    super.key,
    required this.task,
    this.isActionLoading = false,
    this.hasDraft = false,
    this.isHighlighted = false,
    this.onStartPressed,
    this.onFinishPressed,
    this.onTap,
    this.onViewDetail,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  void _showDetail(BuildContext context) {
    String fmtTime(String? iso) {
      if (iso == null || iso.isEmpty) return '--:--';
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '--:--';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    String formatDuration(double hours) {
      final totalMinutes = (hours * 60).round();
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      return '${h}j ${m}m';
    }

    final dailyTargetHours = _taskDisplayTargetHours(task);
    final totalTargetHours = _taskOverallTargetHours(task);
    final sessionHours = _taskCurrentSessionHours(task);
    final workedTotalHours = task.hoursUsed;
    final sessionDurationLabel = sessionHours > 0
        ? formatDuration(sessionHours)
        : '-';

    TaskExecutionDetailSheet.show(
      context: context,
      title: 'Detail Pengerjaan',
      unitName: task.unitName,
      panelName: task.panelName,
      jobName: task.jobName,
      description: task.jobDescription,
      instruction: task.instruction,
      divisionName: task.divisionName,
      taskDate: task.taskDate,
      planStartTime: task.startTime,
      planFinishTime: task.targetFinishTime,
      planDuration: _formatHoursWithDayAlias(dailyTargetHours),
      planTotalDuration: _formatHoursWithDayAlias(totalTargetHours),
      planRemainingDuration: _formatHoursWithDayAlias(task.remainingHours),
      actualStartTime: fmtTime(task.startedAt),
      actualFinishTime: fmtTime(task.completedAt),
      actualDuration: sessionDurationLabel,
      actualWorkedTotal: _formatHoursWithDayAlias(workedTotalHours),
      progress: task.progressPercent,
      status: task.status,
      category: task.taskCategory,
      isOvertime: task.isOvertime,
      isRework: task.isRework,
      isPriority: task.isPriority,
      actions: _buildActionButton(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? AppColors.gold
              : (task.isInProgress || hasDraft)
              ? AppColors.gold.withValues(alpha: 0.4)
              : AppColors.border,
          width: isHighlighted ? 1.4 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            InkWell(
              onTap: () => _showDetail(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    if (isHighlighted) ...[
                      const SizedBox(height: 8),
                      _buildFocusBadge(),
                    ],
                    const SizedBox(height: 10),
                    _buildDescription(),
                    const SizedBox(height: 10),
                    _buildSummaryRow(),
                    const SizedBox(height: 10),
                    _buildBadgeRow(),
                    if (task.isPanelLocked && !task.isInProgress) ...[
                      const SizedBox(height: 10),
                      _buildLockWarning(),
                    ],
                    const SizedBox(height: 12),
                    if (task.isInProgress || hasDraft)
                      _RealtimeProgressBar(task: task)
                    else
                      _buildProgressBar(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildActionButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Notifikasi',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.panelName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                task.unitName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildStatusDot(),
      ],
    );
  }

  Widget _buildStatusDot() {
    Color dotColor;
    String label;

    if (task.isCompleted) {
      dotColor = AppColors.statusDone;
      label = 'Selesai';
    } else if (task.isInProgress || hasDraft) {
      dotColor = AppColors.gold;
      label = 'Berjalan';
    } else {
      dotColor = AppColors.orange;
      label = 'Siap';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: dotColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.jobDescription,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (task.instruction != null && task.instruction!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            task.instruction!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.gold,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metaPill('Target', _formatCompactHours(_taskDisplayTargetHours(task))),
        _metaPill('Plan', _formatPlanWindow(task)),
        _metaPill('Aktual', _formatActualWindow(task)),
      ],
    );
  }

  Widget _buildBadgeRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _badge(task.divisionName, AppColors.textDisabled),
        _badge(
          _categoryLabel(task.taskCategory),
          _categoryColor(task.taskCategory),
        ),
        if (task.isPriority) _badge('Priority', AppColors.statusLocked),
        if (task.isRework) _badge('Rework', AppColors.orange),
        if (task.isOvertime) _badge('Overtime', AppColors.gold),
      ],
    );
  }

  Widget _metaPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'MAIN':
        return 'Main Job';
      case 'ADDITIONAL':
        return 'Additional';
      case 'WO':
        return 'Work Order';
      case 'WOV':
        return 'WO Vendor';
      default:
        return cat;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'MAIN':
        return AppColors.gold;
      case 'WO':
      case 'WOV':
        return AppColors.orange;
      default:
        return AppColors.textTertiary;
    }
  }

  Widget _buildLockWarning() {
    final lockerName = task.lockedByName ?? 'mekanik lain';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.statusLocked.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.statusLocked.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 14,
            color: AppColors.statusLocked,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Panel dikunci oleh $lockerName',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.statusLocked,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double decimalHours) {
    final totalMinutes = (decimalHours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Widget _buildProgressBar() {
    final target = _taskOverallTargetHours(task);
    final runningTime = _taskRecordedWorkedHours(task);
    final progress = target > 0 ? (runningTime / target).clamp(0.0, 1.0) : 0.0;
    final progressPercent = progress * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatDuration(runningTime)} / ${_formatDuration(target)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${progressPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (task.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.statusDone.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 16, color: AppColors.statusDone),
            SizedBox(width: 6),
            Text(
              'Selesai',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.statusDone,
              ),
            ),
          ],
        ),
      );
    }

    if (task.isMonitoringLocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_outlined, size: 16, color: AppColors.gold),
            SizedBox(width: 6),
            Text(
              'Tercatat',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      );
    }

    if (hasDraft || task.isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isActionLoading ? null : onFinishPressed,
          icon: isActionLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.background,
                  ),
                )
              : const Icon(Icons.edit_note_rounded, size: 18),
          label: Text(isActionLoading ? 'Menyimpan...' : 'Update Progress'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    final canAct = task.canStart && !isActionLoading;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canAct ? onStartPressed : null,
        icon: isActionLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.background,
                ),
              )
            : const Icon(Icons.play_circle_outline, size: 18),
        label: Text(isActionLoading ? 'Memulai...' : 'Mulai Kerjakan'),
        style: FilledButton.styleFrom(
          backgroundColor: canAct ? AppColors.gold : AppColors.border,
          foregroundColor: canAct
              ? AppColors.background
              : AppColors.textDisabled,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textDisabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _RealtimeProgressBar extends StatefulWidget {
  final TaskEntity task;
  const _RealtimeProgressBar({required this.task});

  @override
  State<_RealtimeProgressBar> createState() => _RealtimeProgressBarState();
}

class _RealtimeProgressBarState extends State<_RealtimeProgressBar> {
  Timer? _timer;
  final Set<int> _triggeredThresholds = {};

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        _checkAlarms();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _parseStartTime(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso);
    if (dt != null) return dt;

    if (iso.length == 5 && iso.contains(':')) {
      final parts = iso.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }
    return null;
  }

  void _checkAlarms() {
    if (!widget.task.isInProgress || widget.task.isCompleted) return;

    final startedAt = _parseStartTime(widget.task.startedAt);
    if (startedAt == null) return;

    final targetHours = widget.task.dailyTargetHours > 0
        ? widget.task.dailyTargetHours
        : (widget.task.targetHoursRevised > 0
              ? widget.task.targetHoursRevised
              : 1.0);

    final targetTime = startedAt.add(
      Duration(seconds: (targetHours * 3600).round()),
    );
    final remaining = targetTime.difference(DateTime.now());
    final remainingSeconds = remaining.inSeconds;

    if (remainingSeconds <= 600 &&
        remainingSeconds > 598 &&
        !_triggeredThresholds.contains(10)) {
      _triggerVisualAlarm(10, 1);
      _triggeredThresholds.add(10);
    } else if (remainingSeconds <= 300 &&
        remainingSeconds > 298 &&
        !_triggeredThresholds.contains(5)) {
      _triggerVisualAlarm(5, 2);
      _triggeredThresholds.add(5);
    } else if (remainingSeconds <= 0 &&
        remainingSeconds > -2 &&
        !_triggeredThresholds.contains(0)) {
      _triggerVisualAlarm(0, 3);
      _triggeredThresholds.add(0);
    }
  }

  void _triggerVisualAlarm(int minuteMark, int beeps) {
    String message =
        'Waktu pengerjaan ${widget.task.unitName} tersisa $minuteMark menit lagi.';
    if (minuteMark == 0) {
      message =
          'Waktu pengerjaan ${widget.task.unitName} sudah HABIS! Segera selesaikan.';
    }

    AlarmTimerService().playReminder(
      beeps,
      taskId: widget.task.plandailyId,
      unitName: widget.task.unitName,
      message: message,
    );
  }

  String _formatDuration(double decimalHours) {
    final totalMinutes = (decimalHours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = _parseStartTime(widget.task.startedAt);
    final completedAtStr = widget.task.completedAt;
    double currentSessionHours = 0;

    if (startedAt != null) {
      final now = DateTime.now();
      final endTime = completedAtStr != null
          ? DateTime.tryParse(completedAtStr) ?? now
          : now;
      currentSessionHours = endTime.difference(startedAt).inSeconds / 3600.0;
    }

    final totalTarget = _taskOverallTargetHours(widget.task);

    final runningTime =
        (_taskRecordedWorkedHours(widget.task) + currentSessionHours).clamp(
          0.0,
          totalTarget > 0 ? totalTarget : 9999.0,
        );
    final progress = totalTarget > 0
        ? (runningTime / totalTarget).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatDuration(runningTime)} / ${_formatDuration(totalTarget)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}
