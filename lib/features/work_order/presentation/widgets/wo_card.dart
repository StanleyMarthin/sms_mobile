/*
Tujuan: Item list Work Order yang padat untuk daftar aktif/selesai tanpa card besar.
Caller: WorkOrderPage list builder.
Dependensi: AppColors, intl, dan WorkOrder entity/helper status.
Main Functions: WoCard.
Side Effects: Tidak ada; render UI dan trigger callback tap.
*/
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/work_order.dart';

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? AppColors.gold
                : wo.isActive
                ? stageColor.withValues(alpha: 0.22)
                : AppColors.borderSubtle,
            width: isHighlighted ? 1.2 : 0.9,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 52,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _primaryLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(label: stageLabel, color: stageColor),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      wo.jobDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${wo.unitName} • ${wo.ownerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _metaLine(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textDisabled,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _primaryLabel() {
    final panel = wo.panelName?.trim();
    if (panel != null && panel.isNotEmpty) return panel;
    return wo.toDivName;
  }

  String _metaLine() {
    final sections = <String>[
      '${wo.fromDivName} → ${wo.toDivName}',
      if (wo.picName != null && wo.picName!.trim().isNotEmpty)
        'PIC ${wo.picName!.trim()}'
      else
        'PIC belum ditentukan',
      if (wo.estimatedHours != null && wo.estimatedHours! > 0)
        '${wo.estimatedHours!.toStringAsFixed(1)} jam',
      if (_formatDate(wo.requestDate) != null) _formatDate(wo.requestDate)!,
    ];
    return sections.join(' • ');
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed != null) {
      final local = parsed.isUtc ? parsed.toLocal() : parsed;
      return DateFormat('d MMM yyyy', 'id_ID').format(local);
    }

    final datePart = raw.split('T').first;
    final pieces = datePart.split('-');
    if (pieces.length == 3) {
      final year = int.tryParse(pieces[0]);
      final month = int.tryParse(pieces[1]);
      final day = int.tryParse(pieces[2]);
      if (year != null && month != null && day != null) {
        return DateFormat(
          'd MMM yyyy',
          'id_ID',
        ).format(DateTime(year, month, day));
      }
    }
    return raw;
  }

  (String, Color) _stageInfo(String stage) => switch (stage) {
    'PENDING_KD_TARGET' => ('MENUNGGU KD', AppColors.gold),
    'PENDING_ADVISOR' => ('MENUNGGU ADV', const Color(0xFFFF9800)),
    'PENDING_KP' => ('MENUNGGU KP', const Color(0xFF2196F3)),
    'PENDING_MP' => ('MENUNGGU MP', const Color(0xFF9C27B0)),
    'COUNTDOWN_CREATED' => ('SIAP JOBDESC', AppColors.statusDone),
    'APPROVED' => ('APPROVED', AppColors.statusDone),
    'ON_PROGRESS' => ('PROSES', Colors.blueAccent),
    'REJECTED' => ('DITOLAK', AppColors.statusLocked),
    'DONE' => ('SELESAI', AppColors.statusDone),
    _ => (stage, AppColors.textMuted),
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
