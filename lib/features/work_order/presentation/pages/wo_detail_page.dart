import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/work_order.dart';
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_event.dart';
import '../bloc/work_order_state.dart';

class WoDetailPage extends StatefulWidget {
  const WoDetailPage({super.key, required this.woId});
  final String woId;

  @override
  State<WoDetailPage> createState() => _WoDetailPageState();
}

class _WoDetailPageState extends State<WoDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<WorkOrderBloc>().add(LoadWorkOrderDetail(widget.woId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkOrderBloc, WorkOrderState>(
      listener: (ctx, state) {
        if (state is WorkOrderActionSuccess) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.statusDone,
            behavior: SnackBarBehavior.floating,
          ));
          ctx.read<WorkOrderBloc>().add(LoadWorkOrderDetail(widget.woId));
        }
        if (state is WorkOrderError) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.statusLocked,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (ctx, state) {
        if (state is WorkOrderLoading || state is WorkOrderActionLoading) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
            body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          );
        }

        final wo = state is WorkOrderDetailLoaded
            ? state.workOrder
            : null;

        if (wo == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background, elevation: 0,
                title: const Text('Detail WO', style: TextStyle(color: AppColors.textPrimary))),
            body: const Center(child: Text('Data tidak tersedia', style: TextStyle(color: AppColors.textMuted))),
          );
        }

        return _WoDetailContent(wo: wo);
      },
    );
  }
}

class _WoDetailContent extends StatelessWidget {
  const _WoDetailContent({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final role = (session.role ?? '').toUpperCase();

    // Cek apakah role ini perlu aksi
    final stageRoleMap = {
      'PENDING_KD_TARGET': ['KD', 'KETUA_DIVISI'],
      'PENDING_ADVISOR': ['ADV', 'ADVISOR'],
      'PENDING_KP': ['KP', 'KEPALA_PRODUKSI'],
      'PENDING_MP': ['MP', 'MANAGER_PRODUKSI', 'ADMIN'],
    };
    final currentStage = wo.currentStage ?? '';
    final allowedRoles = stageRoleMap[currentStage] ?? [];
    final canAct = wo.isActive && allowedRoles.any((r) => r == role);
    final needsEstimate = currentStage == 'PENDING_KD_TARGET';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(wo.woNumber, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15)),
        leading: const BackButton(color: AppColors.textMuted),
        actions: [
          if (wo.isActive)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
              onPressed: () => context.read<WorkOrderBloc>().add(LoadWorkOrderDetail(wo.id)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(wo: wo),
          const SizedBox(height: 12),
          if (wo.isActive) _ProgressCard(wo: wo),
          if (wo.isActive) const SizedBox(height: 12),
          _InfoCard(wo: wo),
          if (canAct) ...[
            const SizedBox(height: 16),
            _ActionArea(wo: wo, needsEstimate: needsEstimate),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Header Card ──────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gold.withValues(alpha: 0.15), AppColors.surfaceCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wo.unitName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(wo.ownerName, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          _StageBadge(stage: wo.stageBadge),
        ]),
        const Divider(color: AppColors.border, height: 20),
        Row(children: [
          const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text('${wo.fromDivName} → ${wo.toDivName}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
        ]),
        if (wo.panelName != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.layers_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(wo.panelName!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
          child: Text(wo.jobDetail, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
        ),
        if (wo.estimatedHours != null && wo.estimatedHours! > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 14, color: AppColors.gold),
            const SizedBox(width: 6),
            Text('Estimasi: ${wo.estimatedHours!.toStringAsFixed(1)} jam',
                style: const TextStyle(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600)),
            if (wo.estimatedByName != null) ...[
              const Text(' oleh ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text(wo.estimatedByName!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ]),
        ],
      ]),
    );
  }
}

// ── Progress Card ─────────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.wo});
  final WorkOrder wo;

  static const _allStages = [
    ('PENDING_KD_TARGET', 'KD Target', Icons.person_outline),
    ('PENDING_ADVISOR', 'Advisor', Icons.supervisor_account_outlined),
    ('PENDING_KP', 'KP', Icons.manage_accounts_outlined),
    ('PENDING_MP', 'MP', Icons.stars_rounded),
    ('APPROVED', 'Selesai', Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final current = wo.currentStage ?? '';
    final stages = _allStages.where((s) {
      if (s.$1 == 'PENDING_ADVISOR' && !wo.needsAdvisor) return false;
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Progress Approval', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        ...stages.map((s) {
          final stageId = s.$1;
          final label = s.$2;
          final icon = s.$3;

          final done = wo.stagesDone.any((d) => _stageMatchesRole(stageId, d.role));
          final isCurrentPending = stageId == current;
          final isPast = done;

          final stageRecord = wo.stagesDone.where((d) => _stageMatchesRole(stageId, d.role)).firstOrNull;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPast
                        ? AppColors.statusDone
                        : isCurrentPending
                            ? AppColors.gold
                            : AppColors.surfaceInput,
                    border: Border.all(
                      color: isPast ? AppColors.statusDone : isCurrentPending ? AppColors.gold : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    isPast ? Icons.check : icon,
                    size: 16,
                    color: isPast || isCurrentPending ? Colors.white : AppColors.textDisabled,
                  ),
                ),
                if (s != stages.last)
                  Container(width: 2, height: 24, color: isPast ? AppColors.statusDone : AppColors.border),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(label, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isCurrentPending ? AppColors.gold : isPast ? AppColors.textPrimary : AppColors.textDisabled,
                    )),
                    const Spacer(),
                    if (isCurrentPending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('MENUNGGU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ),
                  ]),
                  if (stageRecord != null) ...[
                    const SizedBox(height: 2),
                    Text(stageRecord.name ?? '-',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    if (stageRecord.estimatedHours != null)
                      Text('${stageRecord.estimatedHours!.toStringAsFixed(1)} jam',
                          style: const TextStyle(fontSize: 11, color: AppColors.gold)),
                    if (stageRecord.notes != null && stageRecord.notes!.isNotEmpty)
                      Text('"${stageRecord.notes}"',
                          style: const TextStyle(fontSize: 11, color: AppColors.textDisabled, fontStyle: FontStyle.italic)),
                  ],
                ]),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  bool _stageMatchesRole(String stage, String role) {
    const map = {
      'PENDING_KD_TARGET': ['KD', 'KETUA_DIVISI'],
      'PENDING_ADVISOR': ['ADV', 'ADVISOR'],
      'PENDING_KP': ['KP', 'KEPALA_PRODUKSI'],
      'PENDING_MP': ['MP', 'MANAGER_PRODUKSI', 'ADMIN'],
    };
    return (map[stage] ?? []).contains(role.toUpperCase());
  }
}

// ── Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Info WO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _row('Nomor WO', wo.woNumber),
        _row('Tanggal', wo.requestDate ?? '-'),
        _row('Dari Divisi', wo.fromDivName),
        _row('Ke Divisi', wo.toDivName),
        if (wo.approvalDate != null) _row('Tanggal ACC', wo.approvalDate!),
        if (wo.coreId != null) _row('Core ID', wo.coreId!),
        if (wo.notes != null && wo.notes!.isNotEmpty) ...[
          const Divider(color: AppColors.border, height: 16),
          Text('Catatan: ${wo.notes}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
        ]),
      );
}

// ── Action Area ───────────────────────────────────────────────
class _ActionArea extends StatefulWidget {
  const _ActionArea({required this.wo, required this.needsEstimate});
  final WorkOrder wo;
  final bool needsEstimate;

  @override
  State<_ActionArea> createState() => _ActionAreaState();
}

class _ActionAreaState extends State<_ActionArea> {
  final _estCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _estCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prevEst = widget.wo.estimatedHours;
    if (prevEst != null && prevEst > 0 && _estCtrl.text.isEmpty) {
      _estCtrl.text = prevEst.toStringAsFixed(1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.needsEstimate ? 'Berikan Estimasi Jam' : 'Tinjau & Putuskan',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold),
          ),
        ]),
        const SizedBox(height: 14),
        // Estimasi jam
        TextField(
          controller: _estCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.needsEstimate ? 'Estimasi jam kerja *' : 'Override estimasi jam (opsional)',
            hintStyle: const TextStyle(color: AppColors.textDisabled),
            prefixIcon: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
            suffixText: 'jam',
            suffixStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        // Notes
        TextField(
          controller: _notesCtrl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Catatan (opsional)',
            hintStyle: const TextStyle(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surfaceInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRejectSheet(context),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusLocked,
                side: const BorderSide(color: AppColors.statusLocked),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _confirmApprove(context),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  void _confirmApprove(BuildContext context) {
    final est = double.tryParse(_estCtrl.text.trim());
    if (widget.needsEstimate && (est == null || est <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Estimasi jam wajib diisi'),
        backgroundColor: AppColors.statusLocked,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final nextLabel = _nextRoleLabel(widget.wo.currentStage ?? '', widget.wo.needsAdvisor);
    final estStr = est != null ? '${est.toStringAsFixed(1)} jam' : 'estimasi sebelumnya';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Konfirmasi Setujui', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          nextLabel == 'FINAL'
              ? 'WO akan disetujui final dengan $estStr dan masuk antrean eksekusi.'
              : 'WO akan diteruskan ke $nextLabel dengan $estStr.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<WorkOrderBloc>().add(ApproveWo(
                woId: widget.wo.id,
                estimatedHours: est,
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              ));
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.background),
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectSheet(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tolak Work Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Alasan penolakan wajib diisi', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Tulis alasan penolakan...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                filled: true, fillColor: AppColors.surfaceInput,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final reason = reasonCtrl.text.trim();
                  if (reason.isEmpty) return;
                  Navigator.pop(context);
                  context.read<WorkOrderBloc>().add(RejectWo(woId: widget.wo.id, rejectReason: reason));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusLocked,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tolak WO', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _nextRoleLabel(String stage, bool needsAdvisor) {
    if (stage == 'PENDING_KD_TARGET') return needsAdvisor ? 'Advisor' : 'KP';
    if (stage == 'PENDING_ADVISOR') return 'KP';
    if (stage == 'PENDING_KP') return 'MP';
    if (stage == 'PENDING_MP') return 'FINAL';
    return '-';
  }
}

// ── Stage Badge ───────────────────────────────────────────────
class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});
  final String stage;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  (String, Color) _resolve(String stage) => switch (stage) {
        'PENDING_KD_TARGET' => ('MENUNGGU KD', AppColors.gold),
        'PENDING_ADVISOR'   => ('MENUNGGU ADV', Colors.orange),
        'PENDING_KP'        => ('MENUNGGU KP', Colors.blue),
        'PENDING_MP'        => ('MENUNGGU MP', Colors.purple),
        'APPROVED'          => ('APPROVED', AppColors.statusDone),
        'REJECTED'          => ('DITOLAK', AppColors.statusLocked),
        'DONE'              => ('SELESAI', AppColors.statusDone),
        _                   => (stage, AppColors.textMuted),
      };
}
