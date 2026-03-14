import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/qc_item.dart';
import '../../domain/repositories/qc_repository.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';

/// Unified checkpoint page.
///
/// KD submits checkpoint results and ADV/PM validates them,
/// while users without access only see the queue.
class QcTab extends StatefulWidget {
  const QcTab({super.key, this.focusQcId, this.initialDate});

  final String? focusQcId;
  final DateTime? initialDate;

  @override
  State<QcTab> createState() => _QcTabState();
}

class _QcTabState extends State<QcTab> {
  late DateTime _selectedDate;
  late final QcRepository _repository;
  List<QcItem> _qcItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _repository = sl<QcRepository>();
    _reloadItems();
  }

  String get _dateStr =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  String _formatDateLabel(DateTime date) => DateFormat('d MMM yyyy', 'id_ID').format(date);

  String _formatStoredDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return _formatDateLabel(parsed);
  }

  Future<void> _reloadItems() async {
    final session = sl<SessionManager>();
    final canValidate = hasPermission(session.role, Permission.qcValidate);
    final division = session.divisionName ?? 'MECHANIC';
    final items = await _repository.getQcItems(
      date: _dateStr,
      division: division,
      canValidate: canValidate,
    );
    if (!mounted) return;
    setState(() {
      _qcItems = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final canSubmit = hasPermission(session.role, Permission.qcSubmit);
    final canValidate = hasPermission(session.role, Permission.qcValidate);
    final currentRole = session.role ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DateFilterBar(
            selectedDate: _selectedDate,
            onDateChanged: (d) {
              setState(() {
                _selectedDate = d;
                _isLoading = true;
              });
              _reloadItems();
            },
            label: 'Checkpoint',
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _qcItems.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Role hint card intentionally hidden from UI.
                    _buildSummary(_qcItems),
                    const SizedBox(height: 16),
                      ..._sortedQcItems().map((item) => _QcCard(
                          item: item,
                        isHighlighted: item.qcId == widget.focusQcId,
                          canSubmit: canSubmit,
                          canValidate: canValidate,
                          currentRole: currentRole,
                          onSubmitPass: () => _submitQc(context, item, passed: true),
                          onSubmitFail: () => _submitQc(context, item, passed: false),
                          onValidate: () => _validateQc(context, item),
                        )),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<QcItem> items) {
    final waitingKd = items.where((i) => i.kdCheckpointBy == null).length;
    final doneKd = items.where((i) => i.kdCheckpointBy != null).length;
    final doneAdv = items.where((i) => i.advValidatedBy != null).length;
    final donePm = items.where((i) => i.pmValidatedBy != null).length;

    return Row(
      children: [
        Expanded(
            child: _Tile(
                count: waitingKd,
            label: 'Menunggu QC KD',
                color: AppColors.orange)),
        const SizedBox(width: 8),
        Expanded(
            child: _Tile(
          count: doneKd,
          label: 'Sudah QC KD',
            color: AppColors.gold)),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
          count: doneAdv,
          label: 'Sudah QC ADV',
                color: AppColors.gold)),
        const SizedBox(width: 8),
        Expanded(
            child: _Tile(
            count: donePm,
            label: 'Sudah QC PM',
                color: AppColors.statusDone)),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined,
              size: 56, color: AppColors.textDisabled),
          SizedBox(height: 16),
            Text('Tidak ada antrian checkpoint',
              style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<QcItem> _sortedQcItems() {
    if (widget.focusQcId == null) return _qcItems;
    final ordered = List<QcItem>.from(_qcItems);
    ordered.sort((a, b) {
      final aFocus = a.qcId == widget.focusQcId ? 1 : 0;
      final bFocus = b.qcId == widget.focusQcId ? 1 : 0;
      return bFocus.compareTo(aFocus);
    });
    return ordered;
  }

  Future<void> _submitQc(BuildContext context, QcItem item,
      {required bool passed}) async {
    final session = sl<SessionManager>();
    final notesCtrl = TextEditingController(
      text: item.qcNotes ?? '',
    );
    final reworkCtrl = TextEditingController(
      text: passed ? '0' : '2',
    );
    final remainingCtrl = TextEditingController(
      text: passed ? '0' : '2',
    );
    DateTime? reworkDeadline = !passed
        ? DateTime.tryParse(item.reworkDeadlineDate ?? '') ?? _selectedDate.add(const Duration(days: 2))
        : null;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Text(
            passed ? 'Checkpoint KD Lolos' : 'Checkpoint KD Reject',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesCtrl,
                minLines: 2,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: passed ? 'Catatan checkpoint KD' : 'Alasan reject KD',
                ),
              ),
              if (!passed) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: reworkCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Jam kerja rework'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remainingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Remaining hours setelah checkpoint'),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: reworkDeadline ?? _selectedDate.add(const Duration(days: 2)),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2027),
                    );
                    if (picked != null) {
                      setDialogState(() => reworkDeadline = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Deadline rework'),
                    child: Text(
                      reworkDeadline == null ? 'Pilih deadline rework' : _formatDateLabel(reworkDeadline!),
                      style: TextStyle(
                        color: reworkDeadline == null ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (!passed) {
                  final reworkHours = double.tryParse(reworkCtrl.text.trim());
                  if (reworkHours == null || reworkHours <= 0 || reworkDeadline == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Reject checkpoint wajib isi jam kerja rework dan deadline.')),
                    );
                    return;
                  }
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: passed ? AppColors.statusDone : AppColors.statusLocked,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    await _repository.submitQc(
      qcId: item.qcId,
      passed: passed,
      notes: notesCtrl.text.trim(),
      kdRemainingHours: double.tryParse(remainingCtrl.text.trim()) ?? 0.0,
      estimatedReworkHours: double.tryParse(reworkCtrl.text.trim()) ?? 0.0,
      reworkDeadlineDate: reworkDeadline == null ? null : _formatDate(reworkDeadline!),
      kdCheckpointBy: session.fullName ?? 'KD',
      kdCheckpointAt: _formatDateTime(DateTime.now()),
    );
    if (!context.mounted) return;
    setState(() => _isLoading = true);
    await _reloadItems();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(passed
          ? 'QC KD berhasil disimpan.'
          : 'QC KD reject berhasil disimpan dengan rencana rework.'),
        backgroundColor: AppColors.surfaceCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _validateQc(BuildContext context, QcItem item) async {
    final session = sl<SessionManager>();
    final role = session.role ?? '';
    if (role != 'adv' && role != 'pm') {
      return;
    }
    final advisorCtrl = TextEditingController(
      text: role == 'pm' ? (item.pmNotes ?? '') : (item.advNotes ?? ''),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Validasi Checkpoint',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.resultStatus == 'TIDAK_LOLOS'
                    ? 'KD sudah mengajukan rework ${item.estimatedReworkHours?.toStringAsFixed(1) ?? '-'} jam sampai ${item.reworkDeadlineDate == null ? '-' : _formatStoredDate(item.reworkDeadlineDate!)}.'
                    : role == 'adv'
                        ? 'QC ADV bersifat tambahan. QC KD tetap yang wajib.'
                        : 'QC PM bersifat tambahan. Jika belum dilakukan, QC KD tetap dianggap cukup.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: advisorCtrl,
              minLines: 2,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(labelText: role == 'adv' ? 'Catatan ADV' : 'Catatan PM'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Validasi'),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    await _repository.validateQc(
      qcId: item.qcId,
      validatorRole: role,
      validatorName: session.fullName ?? role.toUpperCase(),
      validatorAt: _formatDateTime(DateTime.now()),
      notes: advisorCtrl.text.trim(),
    );
    if (!context.mounted) return;
    setState(() => _isLoading = true);
    await _reloadItems();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(role == 'adv'
          ? 'QC ADV berhasil disimpan.'
          : 'QC PM berhasil disimpan.'),
        backgroundColor: AppColors.surfaceCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ── Mini tile ─────────────────────────────────────────
class _Tile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _Tile(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── QC Card ───────────────────────────────────────────
class _QcCard extends StatelessWidget {
  final QcItem item;
  final bool isHighlighted;
  final bool canSubmit;
  final bool canValidate;
  final String currentRole;
  final VoidCallback onSubmitPass;
  final VoidCallback onSubmitFail;
  final VoidCallback onValidate;

  const _QcCard({
    required this.item,
    required this.isHighlighted,
    required this.canSubmit,
    required this.canValidate,
    required this.currentRole,
    required this.onSubmitPass,
    required this.onSubmitFail,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    final validationStatus = item.validationStatus;
    final resultStatus = item.resultStatus;
    final checklist = item.qcChecklist;
    final notes = item.qcNotes;
    final kdDone = item.kdCheckpointBy != null;
    final advDone = item.advValidatedBy != null;
    final pmDone = item.pmValidatedBy != null;

    Color statusColor;
    String statusLabel;
    if (!kdDone || validationStatus == 'WAITING_KD') {
      statusColor = AppColors.orange;
      statusLabel = 'Menunggu QC KD';
    } else if (resultStatus == 'TIDAK_LOLOS') {
      statusColor = AppColors.statusLocked;
      statusLabel = 'Reject QC KD';
    } else if (pmDone) {
      statusColor = AppColors.statusDone;
      statusLabel = 'Lolos QC PM';
    } else if (advDone) {
      statusColor = AppColors.gold;
      statusLabel = 'Lolos QC ADV';
    } else {
      statusColor = AppColors.statusDone;
      statusLabel = 'Lolos QC KD';
    }

    final canSubmitThis = canSubmit && !kdDone && validationStatus == 'WAITING_KD';
    final canValidateThis = canValidate &&
        kdDone &&
        ((currentRole == 'adv' && !advDone) || (currentRole == 'pm' && !pmDone));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? AppColors.gold : statusColor.withValues(alpha: 0.3),
          width: isHighlighted ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notification target label intentionally hidden from UI.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled_outlined,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.unitName} — ${item.panelName}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(item.jobName,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Text('Mekanik: ${item.mechanicName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                const Spacer(),
                Text(
                  '${item.totalActualHours.toStringAsFixed(1)}/${item.targetHoursRevised.toStringAsFixed(1)} jam',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          ...checklist.map((cl) {
            final passed = cl.passed;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    passed == true
                        ? Icons.check_circle
                        : passed == false
                            ? Icons.cancel
                            : Icons.radio_button_unchecked,
                    size: 18,
                    color: passed == true
                        ? AppColors.statusDone
                        : passed == false
                            ? AppColors.statusLocked
                            : AppColors.textDisabled,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cl.item,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            );
          }),
          if (notes != null && notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInput,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Catatan KD: $notes',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
              ),
            ),
          if (resultStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                resultStatus == 'TIDAK_LOLOS'
                    ? 'Hasil QC KD: reject • Rework ${item.estimatedReworkHours ?? 0}h • DL ${item.reworkDeadlineDate ?? '-'}'
                    : 'Hasil QC KD: lolos • Remaining ${item.finalRemainingHours ?? item.kdRemainingHours ?? 0}h',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kdDone
                      ? (resultStatus == 'TIDAK_LOLOS' ? 'Reject QC KD' : 'Lolos QC KD')
                      : 'Belum QC KD',
                  style: TextStyle(
                    fontSize: 11,
                    color: kdDone
                        ? (resultStatus == 'TIDAK_LOLOS' ? AppColors.statusLocked : AppColors.statusDone)
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  advDone ? 'Lolos QC ADV' : 'Belum QC ADV',
                  style: TextStyle(
                    fontSize: 11,
                    color: advDone ? AppColors.gold : AppColors.textMuted,
                    fontWeight: advDone ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pmDone ? 'Lolos QC PM' : 'Belum QC PM',
                  style: TextStyle(
                    fontSize: 11,
                    color: pmDone ? AppColors.statusDone : AppColors.textMuted,
                    fontWeight: pmDone ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (item.kdCheckpointBy != null || item.advValidatedBy != null || item.pmValidatedBy != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.kdCheckpointBy != null)
                    Text(
                      'KD: ${item.kdCheckpointBy} • ${item.kdCheckpointAt ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  if (item.advValidatedBy != null)
                    Text(
                      'ADV: ${item.advValidatedBy} • ${item.advValidatedAt ?? '-'}${item.advNotes?.isNotEmpty == true ? ' • ${item.advNotes}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  if (item.pmValidatedBy != null)
                    Text(
                      'PM: ${item.pmValidatedBy} • ${item.pmValidatedAt ?? '-'}${item.pmNotes?.isNotEmpty == true ? ' • ${item.pmNotes}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          if (canSubmitThis || canValidateThis)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                children: [
                  if (canSubmitThis) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSubmitFail,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.statusLocked),
                          foregroundColor: AppColors.statusLocked,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onSubmitPass,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusDone,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Submit Checkpoint',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                  if (canValidateThis)
                    Expanded(
                      child: FilledButton(
                        onPressed: onValidate,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(currentRole == 'adv' ? 'Validasi ADV' : 'Validasi PM',
                          style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
