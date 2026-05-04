import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task_entity.dart';

/// A dark-luxury themed task card matching the SM Workshop High-Fidelity UI.
///
/// Shows:
/// - Car name (unit) and panel name
/// - Task description
/// - Task category badge (MAIN / WO / ADDITIONAL)
/// - Status indicator (In Progress / To Do / Completed)
/// - Panel lock warning with locker's name
/// - Hours progress bar
/// - Start / Finish action button
class TaskCard extends StatelessWidget {
  final TaskEntity task;
  final bool isActionLoading;
  final bool hasDraft;
  final bool isHighlighted;
  final VoidCallback? onStartPressed;
  final VoidCallback? onFinishPressed;
  final VoidCallback? onTap;
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
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final isReadOnly = task.isCompleted || task.isMonitoringLocked;
    return GestureDetector(
      onTap: isReadOnly ? null : onTap,
      child: Container(
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
              const SizedBox(height: 12),
              _buildBadgeRow(),
              if (task.isPanelLocked && !task.isInProgress) ...[
                const SizedBox(height: 10),
                _buildLockWarning(),
              ],
              const SizedBox(height: 12),
              _buildProgressBar(),
              const SizedBox(height: 14),
              _buildActionButton(),
            ],
          ),
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
        'Dari notifikasi',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }

  // ── Header: car name + owner + panel ─────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        // Car icon placeholder
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.directions_car_filled_outlined,
              size: 20, color: AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.unitName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${task.ownerName}  •  ${task.panelName}',
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

  // ── Status dot indicator ────────────────────────────────
  Widget _buildStatusDot() {
    Color dotColor;
    String label;

    if (task.isCompleted) {
      dotColor = AppColors.statusDone;
      label = 'Done';
    } else if (task.isInProgress || hasDraft) {
      dotColor = AppColors.gold;
      label = 'In Progress';
    } else {
      dotColor = AppColors.orange;
      label = 'To Do';
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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: dotColor),
        ),
      ],
    );
  }

  // ── Description ─────────────────────────────────────────
  Widget _buildDescription() {
    return Text(
      task.customDescription.isNotEmpty
          ? task.customDescription
          : '${task.jobName} — ${task.divisionName}',
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ── Category + Division badges ──────────────────────────
  Widget _buildBadgeRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _badge(
          _categoryLabel(task.taskCategory),
          _categoryColor(task.taskCategory),
        ),
        _badge(task.divisionName, AppColors.textDisabled),
        if (task.isPriority) _badge('Priority', AppColors.statusLocked),
        if (task.isRework) _badge('Rework', AppColors.orange),
        if (task.isOvertime) _badge('Overtime', AppColors.gold),
      ],
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
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

  // ── Panel lock warning ──────────────────────────────────
  Widget _buildLockWarning() {
    final lockerName = task.lockedByName ?? 'mekanik lain';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.statusLocked.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.statusLocked.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.statusLocked),
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

  // ── Progress bar ────────────────────────────────────────
  Widget _buildProgressBar() {
    final progress = (task.progressPercent / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${task.hoursUsed.toStringAsFixed(1)} / ${task.targetHoursRevised.toStringAsFixed(1)} jam',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            Text(
              '${task.progressPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.border,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }

  // ── Action button ───────────────────────────────────────
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

    if (hasDraft) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isActionLoading ? null : onFinishPressed,
          icon: isActionLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.background),
                )
              : const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(isActionLoading ? 'Menyelesaikan...' : 'Selesaikan'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    // To Do
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
                    strokeWidth: 2, color: AppColors.background),
              )
            : const Icon(Icons.play_circle_outline, size: 18),
        label: Text(isActionLoading ? 'Memulai...' : 'Mulai Kerjakan'),
        style: FilledButton.styleFrom(
          backgroundColor: canAct ? AppColors.gold : AppColors.border,
          foregroundColor:
              canAct ? AppColors.background : AppColors.textDisabled,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textDisabled,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
