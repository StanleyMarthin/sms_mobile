/*
Tujuan: Kartu monitoring task management yang ringkas untuk PIC/KD/leader dengan detail expandable.
Caller: TaskViewPage dan drilldown jobdesc management.
Dependensi: AppColors, ViewTaskEntity, TaskExecutionDetailSheet.
Main Functions: build, _buildProgressSection, _buildMonitoringHistory.
Side Effects: Tidak ada; hanya render UI dan meneruskan tap detail monitoring.
*/
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/view_task_entity.dart';
import './task_execution_detail_sheet.dart';

int? _clockToMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour * 60) + minute;
}

String _formatMinutesLabel(int minutes) {
  if (minutes <= 0) return '-';
  final hours = minutes ~/ 60;
  final remainMinutes = minutes % 60;
  if (hours > 0 && remainMinutes > 0) {
    return '${hours}j ${remainMinutes}m';
  }
  if (hours > 0) {
    return '${hours}j';
  }
  return '${remainMinutes}m';
}

String _formatHoursWithDayAlias(double hours) {
  if (hours <= 0) return '-';
  final compact = _formatMinutesLabel((hours * 60).round());
  final dayValue = hours / 8.0;
  final dayText = dayValue == dayValue.roundToDouble()
      ? dayValue.toStringAsFixed(0)
      : dayValue.toStringAsFixed(dayValue < 1 ? 2 : 1);
  return '$compact ($dayText hari)';
}

String _estimateLabel(TaskDetail detail) {
  if (detail.targetHours > 0) {
    return _formatMinutesLabel((detail.targetHours * 60).round());
  }

  final startMinutes = _clockToMinutes(detail.startTime);
  final finishMinutes = _clockToMinutes(detail.targetFinishTime);
  if (startMinutes == null ||
      finishMinutes == null ||
      finishMinutes < startMinutes) {
    return '-';
  }

  final breakMinutes = detail.breakDuration.clamp(0, 24 * 60);
  final totalMinutes = (finishMinutes - startMinutes) - breakMinutes;
  return _formatMinutesLabel(totalMinutes);
}

String _jobTitle(ViewTaskEntity task) {
  final title = task.task.jobDescription.trim();
  if (title.isNotEmpty) return title;
  return task.task.jobName.trim().isNotEmpty ? task.task.jobName : '-';
}

String _firstActualStartLabel(List<TaskCheckpointSession> history) {
  final ordered = List<TaskCheckpointSession>.from(history)
    ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
  for (final session in ordered) {
    if (_clockToMinutes(session.startWorkTime) != null) {
      return session.startWorkTime;
    }
    if (_clockToMinutes(session.checkpointTime) != null) {
      return session.checkpointTime;
    }
  }
  return '--:--';
}

String _lastActualFinishLabel(List<TaskCheckpointSession> history) {
  final ordered = List<TaskCheckpointSession>.from(history)
    ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
  for (final session in ordered.reversed) {
    if (_clockToMinutes(session.finishWorkTime) != null) {
      return session.finishWorkTime;
    }
    if (_clockToMinutes(session.checkpointTime) != null) {
      return session.checkpointTime;
    }
  }
  return '--:--';
}

class ViewTaskCard extends StatefulWidget {
  final ViewTaskEntity task;
  final bool showEmployee;
  final bool showDivision;
  final VoidCallback? onTap;
  final Widget? actionArea;
  final bool isHighlighted;
  final ValueChanged<TaskCheckpointSession>? onCheckpointTap;
  final EdgeInsetsGeometry margin;
  final String taskDate;

  const ViewTaskCard({
    super.key,
    required this.task,
    this.showEmployee = true,
    this.showDivision = true,
    this.onTap,
    this.actionArea,
    this.isHighlighted = false,
    this.onCheckpointTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.taskDate = '-',
  });

  @override
  State<ViewTaskCard> createState() => _ViewTaskCardState();
}

class _ViewTaskCardState extends State<ViewTaskCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isHighlighted;
  }

  void _showDetail(BuildContext context) {
    final task = widget.task;

    final lastCp = task.checkpointHistory.isNotEmpty
        ? task.checkpointHistory.last
        : null;

    final isDone = task.isDone || task.progressPercent >= 100;

    // FILTER: Hanya tampilkan sesi monitoring dari level manajemen (bukan lapangan/op)
    final managementHistory = task.checkpointHistory
        .where(
          (cp) =>
              cp.actorRole != 'op' &&
              cp.actorRole != 'operator' &&
              cp.actorRole != 'lapangan',
        )
        .toList();

    final List<Map<String, dynamic>> checkpointItems = isDone
        ? (managementHistory.isNotEmpty
              ? [
                  {
                    'session': managementHistory.last.sessionNumber,
                    'time': managementHistory.last.checkpointTime,
                    'progress': 100,
                    'status': 'Selesai',
                  },
                ]
              : [])
        : managementHistory
              .map(
                (cp) => {
                  'session': cp.sessionNumber,
                  'time': cp.checkpointTime,
                  'progress': cp.progress,
                  'status': cp.jobStatusLabel,
                },
              )
              .toList();

    TaskExecutionDetailSheet.show(
      context: context,
      title: 'Detail Monitoring',
      unitName: task.unit.unitName,
      panelName: task.task.namaPanel,
      jobName: task.task.jobName,
      description: task.task.jobDescription,
      instruction: task.task.note,
      divisionName: task.division.divisionName,
      taskDate: widget.taskDate,
      planStartTime: task.task.startTime,
      planFinishTime: task.task.targetFinishTime,
      planDuration: _formatHoursWithDayAlias(task.dailyTargetHours),
      planTotalDuration: _formatHoursWithDayAlias(task.targetHoursTotal),
      planRemainingDuration: _formatHoursWithDayAlias(task.remainingHours),
      actualStartTime: task.checkpointHistory.isNotEmpty
          ? _firstActualStartLabel(task.checkpointHistory)
          : '--:--',
      actualFinishTime: task.checkpointHistory.isNotEmpty
          ? _lastActualFinishLabel(task.checkpointHistory)
          : '--:--',
      actualDuration: lastCp?.workedDurationLabel ?? '-',
      actualWorkedTotal: _formatHoursWithDayAlias(task.hoursUsed),
      progress: task.progressPercent.toDouble(),
      status: task.status,
      category: 'MAIN', // Default
      operatorName: task.employee.employeeName,
      checkpoints: checkpointItems,
      actions: widget.actionArea,
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final lastCheckpoint = task.checkpointHistory.isNotEmpty
        ? task.checkpointHistory.last
        : null;
    final lastMonitorTime = lastCheckpoint?.checkpointTime;
    final currentProgress = task.progressPercent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isHighlighted ? AppColors.gold : AppColors.borderSubtle,
          width: widget.isHighlighted ? 1.2 : 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                _showDetail(context);
                widget.onTap?.call();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.showEmployee) ...[
                            Text(
                              task.employee.employeeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  task.task.namaPanel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusPill(currentProgress),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _jobTitle(task),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          if (task.task.note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              task.task.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Text(
                            _summaryLine(task, lastMonitorTime),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textDisabled,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress $currentProgress% • ${task.task.startTime} - ${task.task.targetFinishTime} • ${task.checkpointHistory.length}/${task.maxCheckpointSessions} sesi',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildProgressSection(currentProgress),
                    if (task.checkpointHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildMonitoringHistory(),
                    ],
                    if (task.finalValidations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildFinalValidationSummary(),
                    ],
                    if (widget.actionArea != null) ...[
                      const SizedBox(height: 10),
                      widget.actionArea!,
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _summaryLine(ViewTaskEntity task, String? lastMonitorTime) {
    final sections = <String>[
      'Target ${_estimateLabel(task.task)}',
      '${task.task.startTime} - ${task.task.targetFinishTime}',
      if (widget.showDivision) task.division.divisionName,
      lastMonitorTime == null ? 'Belum monitoring' : 'Cek $lastMonitorTime',
    ];
    return sections.join(' • ');
  }

  Widget _statusPill(int progress) {
    final status = widget.task.status;
    Color color = AppColors.gold;
    String label = '$progress%';

    if (status == 'DONE' || status == 'VALIDATED') {
      color = AppColors.statusDone;
      label = 'Selesai';
    } else if (status == 'SUBMITTED' || status == 'ASSIGNED') {
      color = AppColors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProgressSection(int progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progress',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '$progress%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: progress >= 100 ? AppColors.statusDone : AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: progress >= 100 ? AppColors.statusDone : AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringHistory() {
    final managementLogs = widget.task.checkpointHistory
        .where(
          (cp) =>
              cp.actorRole != 'op' &&
              cp.actorRole != 'operator' &&
              cp.actorRole != 'team_lapangan',
        )
        .toList();

    if (managementLogs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monitoring',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...managementLogs.map((session) {
          return InkWell(
            onTap: widget.onCheckpointTap != null
                ? () => widget.onCheckpointTap!(session)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sesi ${session.sessionNumber} • ${session.checkpointTime}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${session.progress}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.jobStatusLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (widget.onCheckpointTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AppColors.textDisabled,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFinalValidationSummary() {
    return Row(
      children: [
        const Icon(
          Icons.verified_user_rounded,
          size: 14,
          color: AppColors.statusDone,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Final: ${widget.task.finalValidations.map((v) => v.roleLabel).join(', ')}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.statusDone,
            ),
          ),
        ),
      ],
    );
  }
}
