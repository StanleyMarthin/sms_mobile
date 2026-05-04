import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/work_order.dart';

/// WO Card untuk list — compact, informatif, role-aware badge
class WoCard extends StatelessWidget {
  const WoCard({
    super.key,
    required this.wo,
    required this.onTap,
    this.isHighlighted = false,
  });

  final WorkOrder wo;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final (stageLabel, stageColor) = _stageInfo(wo.stageBadge);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? AppColors.gold
                : wo.isActive
                    ? stageColor.withValues(alpha: 0.3)
                    : AppColors.border,
            width: isHighlighted ? 1.5 : 1,
          ),
          boxShadow: isHighlighted
              ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  wo.woNumber,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              _Badge(label: stageLabel, color: stageColor),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Unit
              Row(children: [
                const Icon(Icons.directions_car_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${wo.unitName} — ${wo.ownerName}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              // Divisi
              Row(children: [
                const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${wo.fromDivName} → ${wo.toDivName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              if (wo.panelName != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.layers_outlined, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(wo.panelName!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ],
              const SizedBox(height: 8),
              // Job detail
              Text(
                wo.jobDetail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
              ),
              if (wo.estimatedHours != null && wo.estimatedHours! > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.gold),
                  const SizedBox(width: 5),
                  Text(
                    '${wo.estimatedHours!.toStringAsFixed(1)} jam',
                    style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600),
                  ),
                ]),
              ],
            ]),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textDisabled),
              const SizedBox(width: 4),
              Text(wo.requestDate ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textDisabled),
            ]),
          ),
        ]),
      ),
    );
  }

  (String, Color) _stageInfo(String stage) => switch (stage) {
        'PENDING_KD_TARGET' => ('MENUNGGU KD', AppColors.gold),
        'PENDING_ADVISOR'   => ('MENUNGGU ADV', const Color(0xFFFF9800)),
        'PENDING_KP'        => ('MENUNGGU KP', const Color(0xFF2196F3)),
        'PENDING_MP'        => ('MENUNGGU MP', const Color(0xFF9C27B0)),
        'APPROVED'          => ('APPROVED', AppColors.statusDone),
        'REJECTED'          => ('DITOLAK', AppColors.statusLocked),
        'DONE'              => ('SELESAI', AppColors.statusDone),
        _                   => (stage, AppColors.textMuted),
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );
}
