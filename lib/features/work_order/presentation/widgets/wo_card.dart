import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/work_order.dart';

class WoCard extends StatelessWidget {
  final WorkOrder wo;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final void Function(double newHours, String newDeadline, String reason)?
      onRequestRevision;
  final void Function(String? note)? onRespondRevisionApprove;
  final void Function(String? note)? onRespondRevisionReject;
  final void Function(String newDeadline, String reason)? onRequestExtension;
  final void Function(String? note)? onRespondExtensionApprove;
  final void Function(String? note)? onRespondExtensionReject;
  final VoidCallback? onCreateTask;
  final bool isHighlighted;

  const WoCard({
    super.key,
    required this.wo,
    this.onEdit,
    this.onDelete,
    this.onApprove,
    this.onReject,
    this.onRequestRevision,
    this.onRespondRevisionApprove,
    this.onRespondRevisionReject,
    this.onRequestExtension,
    this.onRespondExtensionApprove,
    this.onRespondExtensionReject,
    this.onCreateTask,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel, statusIcon) = _statusInfo(wo.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? AppColors.gold : AppColors.border,
          width: isHighlighted ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${wo.woNumber}  ·  ${wo.woType}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusBadge(statusLabel, statusColor),
              ],
            ),
          ),
          // ── Unit · Owner · Division flow ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 3, 14, 0),
            child: Text(
              '${wo.unitName}  ·  ${wo.ownerName}  ·  ${wo.fromDivision} → ${wo.toDivision}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isHighlighted)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 4, 14, 0),
              child: _statusBadge('Target notifikasi', AppColors.gold),
            ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, indent: 14, endIndent: 14),
          // ── Meta rows ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: _buildMetaTable(),
          ),
          // ── Description ─────────────────────────────────────────
          if (wo.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Text(
                wo.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          // ── Revision alert ──────────────────────────────────────
          if (wo.revisionRequestStatus != null)
            _buildInlineAlert(
              Icons.edit_calendar_outlined,
              AppColors.gold,
              _revisionAlertText(),
            ),
          // ── Extension alert ─────────────────────────────────────
          if (wo.extensionRequestStatus != null)
            _buildInlineAlert(
              Icons.schedule,
              AppColors.orange,
              _extensionAlertText(),
            ),
          // ── Notes ───────────────────────────────────────────────
          if (wo.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Text(
                'Catatan: ${wo.notes}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 8),
          _buildActionArea(context),
        ],
      ),
    );
  }

  Widget _buildMetaTable() {
    final rows = <(String, String)>[
      ('Panel', wo.panelName),
      if ((wo.partName ?? '').isNotEmpty) ('Part', wo.partName!),
      if ((wo.jobdescName ?? '').isNotEmpty) ('Jobdesc', wo.jobdescName!),
      ('Estimasi', '${wo.estimatedHours.toStringAsFixed(1)} jam'),
      if (wo.deadline != null) ('Deadline', wo.deadline!),
      ('Approval', _approvalText()),
    ];

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(68),
        1: FlexColumnWidth(),
      },
      children: rows.map((row) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                row.$1,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                ': ${row.$2}',
                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _approvalText() {
    final advisorDone = wo.advisorApprovedBy != null;
    final pmDone = wo.pmApprovedBy != null;
    final advisorRev = wo.status == 'REVISION_REQUESTED_ADVISOR';
    final pmRev = wo.status == 'REVISION_REQUESTED_PM';
    final advLabel = advisorDone ? 'ADV ✓' : advisorRev ? 'ADV (rev)' : 'ADV ○';
    final pmLabel = pmDone ? 'PM ✓' : pmRev ? 'PM (rev)' : 'PM ○';
    return 'KD  →  $advLabel  →  $pmLabel';
  }

  String _revisionAlertText() {
    final parts = <String>['Revisi: ${wo.revisionRequestStatus}'];
    if (wo.requestedEstimatedHours != null) {
      parts.add('Est: ${wo.requestedEstimatedHours!.toStringAsFixed(1)}j');
    }
    if (wo.requestedDeadline != null) parts.add('DL: ${wo.requestedDeadline}');
    if ((wo.revisionReason ?? '').isNotEmpty) parts.add(wo.revisionReason!);
    return parts.join('  ·  ');
  }

  String _extensionAlertText() {
    final parts = <String>['Perpanjangan: ${wo.extensionRequestStatus}'];
    if (wo.extensionRequestedDeadline != null) {
      parts.add('DL baru: ${wo.extensionRequestedDeadline}');
    }
    if ((wo.extensionRequestedReason ?? '').isNotEmpty) {
      parts.add(wo.extensionRequestedReason!);
    }
    return parts.join('  ·  ');
  }

  Widget _buildInlineAlert(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context) {
    if (onRespondRevisionApprove != null || onRespondRevisionReject != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Row(
          children: [
            if (onRespondRevisionReject != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showNoteDialog(
                    context,
                    title: 'Tolak Revisi',
                    onSubmit: onRespondRevisionReject!,
                  ),
                  child: const Text('Tolak Revisi'),
                ),
              ),
            if (onRespondRevisionReject != null && onRespondRevisionApprove != null)
              const SizedBox(width: 8),
            if (onRespondRevisionApprove != null)
              Expanded(
                child: FilledButton(
                  onPressed: () => _showNoteDialog(
                    context,
                    title: 'Setujui Revisi',
                    onSubmit: onRespondRevisionApprove!,
                    allowEmpty: true,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusDone,
                    foregroundColor: AppColors.background,
                  ),
                  child: const Text('Acc Revisi'),
                ),
              ),
          ],
        ),
      );
    }

    if (onApprove != null || onReject != null || onRequestRevision != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onReject != null)
              OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusLocked,
                  side: const BorderSide(color: AppColors.statusLocked),
                ),
                child: const Text('Tolak'),
              ),
            if (onRequestRevision != null)
              OutlinedButton(
                onPressed: () => _showRevisionDialog(context),
                child: const Text('Revisi'),
              ),
            if (onApprove != null)
              FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusDone,
                  foregroundColor: AppColors.background,
                ),
                child: Text(wo.isPendingAdvisor ? 'Acc Adv' : 'Acc PM'),
              ),
          ],
        ),
      );
    }

    if (onRespondExtensionApprove != null || onRespondExtensionReject != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Row(
          children: [
            if (onRespondExtensionReject != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showNoteDialog(
                    context,
                    title: 'Tolak Perpanjangan',
                    onSubmit: onRespondExtensionReject!,
                  ),
                  child: const Text('Tolak Perpanjangan'),
                ),
              ),
            if (onRespondExtensionReject != null && onRespondExtensionApprove != null)
              const SizedBox(width: 8),
            if (onRespondExtensionApprove != null)
              Expanded(
                child: FilledButton(
                  onPressed: () => _showNoteDialog(
                    context,
                    title: 'Setujui Perpanjangan',
                    onSubmit: onRespondExtensionApprove!,
                    allowEmpty: true,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusDone,
                    foregroundColor: AppColors.background,
                  ),
                  child: const Text('Acc Perpanjangan'),
                ),
              ),
          ],
        ),
      );
    }

    if (onRequestExtension != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showExtensionDialog(context),
            icon: const Icon(Icons.schedule, size: 16),
            label: const Text('Ajukan Perpanjangan Deadline'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        ),
      );
    }

    if (onCreateTask != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateTask,
            icon: const Icon(Icons.add_task_rounded, size: 16),
            label: const Text('Create Task'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
          ),
        ),
      );
    }

    if (wo.isDraft && (onEdit != null || onDelete != null)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Row(
          children: [
            if (onDelete != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: onDelete,
                  child: const Text('Hapus'),
                ),
              ),
            if (onDelete != null && onEdit != null) const SizedBox(width: 8),
            if (onEdit != null)
              Expanded(
                child: FilledButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox(height: 12);
  }

  void _showRevisionDialog(BuildContext context) {
    final estCtrl = TextEditingController(
      text: wo.estimatedHours.toStringAsFixed(1),
    );
    final reasonCtrl = TextEditingController();
    DateTime? newDeadline =
        wo.deadline != null ? DateTime.tryParse(wo.deadline!) : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              title: const Text('Minta Revisi WO'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: estCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Estimasi jam baru *'),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            newDeadline ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => newDeadline = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        newDeadline == null
                            ? 'Pilih deadline baru *'
                            : '${newDeadline!.year}-${newDeadline!.month.toString().padLeft(2, '0')}-${newDeadline!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Alasan revisi *'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(estCtrl.text.trim());
                    if (parsed == null ||
                        newDeadline == null ||
                        reasonCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final date =
                        '${newDeadline!.year}-${newDeadline!.month.toString().padLeft(2, '0')}-${newDeadline!.day.toString().padLeft(2, '0')}';
                    onRequestRevision!(parsed, date, reasonCtrl.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: const Text('Kirim Revisi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExtensionDialog(BuildContext context) {
    DateTime? newDeadline;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              title: const Text('Ajukan Perpanjangan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => newDeadline = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        newDeadline == null
                            ? 'Pilih deadline baru *'
                            : '${newDeadline!.year}-${newDeadline!.month.toString().padLeft(2, '0')}-${newDeadline!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Alasan *'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (newDeadline == null || reasonCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final date =
                        '${newDeadline!.year}-${newDeadline!.month.toString().padLeft(2, '0')}-${newDeadline!.day.toString().padLeft(2, '0')}';
                    onRequestExtension!(date, reasonCtrl.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: const Text('Ajukan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNoteDialog(
    BuildContext context, {
    required String title,
    required void Function(String? note) onSubmit,
    bool allowEmpty = false,
  }) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(title),
        content: TextField(
          controller: noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Catatan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (!allowEmpty && noteCtrl.text.trim().isEmpty) return;
              onSubmit(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  (Color, String, IconData) _statusInfo(String status) {
    return switch (status) {
      'DRAFT' => (AppColors.textSecondary, 'Draft', Icons.edit_note),
      'PENDING_ADVISOR' =>
        (AppColors.orange, 'Menunggu Adv', Icons.hourglass_empty),
      'PENDING_PM' =>
        (const Color(0xFFE88D2A), 'Menunggu PM', Icons.hourglass_top),
      'REVISION_REQUESTED_ADVISOR' =>
        (AppColors.gold, 'Revisi KD (Adv)', Icons.edit_calendar_outlined),
      'REVISION_REQUESTED_PM' =>
        (AppColors.gold, 'Revisi KD (PM)', Icons.edit_calendar_outlined),
      'APPROVED' => (AppColors.statusDone, 'Approved', Icons.check_circle),
      'REJECTED' => (AppColors.statusLocked, 'Ditolak', Icons.cancel),
      'IN_PROGRESS' =>
        (AppColors.gold, 'Dikerjakan', Icons.play_circle_filled),
      'DONE' => (AppColors.textSecondary, 'Selesai', Icons.task_alt),
      _ => (AppColors.textMuted, status, Icons.help_outline),
    };
  }
}
