/*
Tujuan: Halaman detail Work Order untuk review approval bertingkat, penentuan PIC/jam kerja, dan visibilitas status countdown.
Caller: WorkOrderPage dan deep-link route `/work-orders?woId=...`.
Dependensi: SessionManager, WorkOrderRepository, WorkOrderBloc, WorkOrder entity.
Main Functions: WoDetailPage, _ApprovalStatusBar, _ActionArea, _StageBadge.
Side Effects: HTTP load detail, approve/reject WO, dan refresh state bloc.
*/
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/time_parser.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/work_order.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_event.dart';
import '../bloc/work_order_state.dart';

String? _formatWoDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed != null) {
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateFormat('d MMM yyyy', 'id_ID').format(local);
  }
  return raw;
}

String? _formatWoDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed != null) {
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(local);
  }
  return raw;
}

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
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.statusDone,
              behavior: SnackBarBehavior.floating,
            ),
          );
          ctx.read<WorkOrderBloc>().add(LoadWorkOrderDetail(widget.woId));
        }
        if (state is WorkOrderError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.statusLocked,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (ctx, state) {
        if (state is WorkOrderLoading || state is WorkOrderActionLoading) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final wo = state is WorkOrderDetailLoaded ? state.workOrder : null;

        if (wo == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              title: const Text(
                'Detail WO',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            body: const Center(
              child: Text(
                'Data tidak tersedia',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
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
        title: Text(
          wo.woNumber,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        leading: const BackButton(color: AppColors.textMuted),
        actions: [
          if (wo.isActive)
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textMuted,
              ),
              onPressed: () =>
                  context.read<WorkOrderBloc>().add(LoadWorkOrderDetail(wo.id)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _ApprovalStatusBar(wo: wo),
          const SizedBox(height: 16),
          _HeaderCard(wo: wo),
          if (canAct) ...[
            const SizedBox(height: 16),
            _ActionArea(wo: wo, needsEstimate: needsEstimate),
          ],
          const SizedBox(height: 24),
          _InfoCard(wo: wo),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── New Compact Approval Status Bar ──────────────────────────
class _ApprovalStatusBar extends StatelessWidget {
  const _ApprovalStatusBar({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('KD', _isKdDone(wo), wo.waitingKdTarget),
      ('KP', _isKpDone(wo), wo.waitingAdvisor || wo.waitingKp),
      ('MP', _isMpDone(wo), wo.waitingMp),
      (
        'PROSES',
        wo.isDone,
        wo.status == 'APPROVED' ||
            wo.status == 'COUNTDOWN_CREATED' ||
            wo.isInProgress,
      ),
      ('DONE', wo.isDone, wo.isDone),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final isDone = step.$2;
              final isCurrent = step.$3;
              final color = isDone
                  ? AppColors.statusDone
                  : isCurrent
                  ? AppColors.gold
                  : AppColors.textDisabled;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone || isCurrent
                                  ? color
                                  : AppColors.surfaceInput,
                              border: Border.all(
                                color: isDone || isCurrent
                                    ? color
                                    : AppColors.border,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.$1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          color: isDone
                              ? AppColors.statusDone
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _isKdDone(WorkOrder wo) {
    return wo.stagesDone.any(
          (d) => _stageMatchesRole('PENDING_KD_TARGET', d.role),
        ) ||
        wo.waitingAdvisor ||
        wo.waitingKp ||
        wo.waitingMp ||
        wo.hasCountdownLink;
  }

  bool _isKpDone(WorkOrder wo) {
    return wo.stagesDone.any((d) => _stageMatchesRole('PENDING_KP', d.role)) ||
        wo.waitingMp ||
        wo.hasCountdownLink;
  }

  bool _isMpDone(WorkOrder wo) {
    return wo.stagesDone.any((d) => _stageMatchesRole('PENDING_MP', d.role)) ||
        wo.hasCountdownLink;
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

// ── Header Card ──────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wo.unitName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wo.ownerName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StageBadge(stage: wo.stageBadge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${wo.fromDivName} → ${wo.toDivName}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            wo.jobDetail,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (wo.panelName != null && wo.panelName!.isNotEmpty)
                _chip(wo.panelName!),
              _chip(
                wo.picName != null && wo.picName!.trim().isNotEmpty
                    ? 'PIC ${wo.picName!}'
                    : 'PIC belum ditentukan',
              ),
              if (wo.estimatedHours != null && wo.estimatedHours! > 0)
                _chip('Estimasi ${wo.estimatedHours!.toStringAsFixed(1)} jam'),
              if (wo.requestDate != null && wo.requestDate!.trim().isNotEmpty)
                _chip(_formatWoDate(wo.requestDate!) ?? wo.requestDate!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.wo});
  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Administrasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _row('No. WO', wo.woNumber),
          _row('Status', _statusLabel(wo)),
          _row('Tahap aktif', _stageLabel(wo)),
          _row(
            'Alur approval',
            wo.needsAdvisor ? 'KD → Advisor → KP → MP' : 'KD → KP → MP',
          ),
          _row('Tanggal Request', _formatWoDate(wo.requestDate) ?? '-'),
          _row('Divisi', '${wo.fromDivName} → ${wo.toDivName}'),
          if (wo.panelName != null && wo.panelName!.isNotEmpty)
            _row('Panel', wo.panelName!),
          _row(
            'Pelaksana / PIC',
            wo.picName != null && wo.picName!.trim().isNotEmpty
                ? wo.picName!
                : 'Belum ditentukan',
          ),
          if (wo.estimatedHours != null && wo.estimatedHours! > 0)
            _row('Estimasi', '${wo.estimatedHours!.toStringAsFixed(1)} jam'),
          if (wo.approvalDate != null)
            _row(
              'Tanggal Disetujui',
              _formatWoDateTime(wo.approvalDate!) ?? wo.approvalDate!,
            ),
          if (wo.coreId != null && wo.coreId!.isNotEmpty)
            _row('Referensi', wo.coreId!),
          if (wo.stagesDone.isNotEmpty) ...[
            const Divider(color: AppColors.border, height: 16),
            const Text(
              'Approval',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...wo.stagesDone.map(
              (stage) => _row(
                stage.role,
                [
                  if (stage.name != null && stage.name!.trim().isNotEmpty)
                    stage.name!.trim(),
                  if (stage.actionAt != null &&
                      stage.actionAt!.trim().isNotEmpty)
                    stage.actionAt!.trim(),
                ].join(' • '),
              ),
            ),
          ],
          if (wo.notes != null && wo.notes!.isNotEmpty) ...[
            const Divider(color: AppColors.border, height: 16),
            Text(
              'Catatan',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              wo.notes!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(WorkOrder wo) {
    final stage = wo.stageBadge;
    return switch (stage) {
      'PENDING_KD_TARGET' => 'Menunggu KD tujuan',
      'PENDING_ADVISOR' => 'Menunggu Advisor',
      'PENDING_KP' => 'Menunggu KP',
      'PENDING_MP' => 'Menunggu MP',
      'COUNTDOWN_CREATED' => 'Siap jobdesc',
      'APPROVED' => 'Approved',
      'ON_PROGRESS' => 'Proses',
      'DONE' => 'Selesai',
      'REJECTED' => 'Ditolak',
      _ => stage,
    };
  }

  String _stageLabel(WorkOrder wo) {
    if (wo.waitingKdTarget) return 'KD';
    if (wo.waitingAdvisor) return 'Advisor';
    if (wo.waitingKp) return 'KP';
    if (wo.waitingMp) return 'MP';
    if (wo.isInProgress) return 'Proses';
    if (wo.isDone) return 'Selesai';
    if (wo.hasCountdownLink) return 'Siap jobdesc';
    return '-';
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
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

  bool _isLoadingUsers = false;
  List<Map<String, dynamic>> _users = [];
  String? _selectedPicId;

  @override
  void initState() {
    super.initState();
    if (widget.needsEstimate) {
      _fetchUsers();
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final repo = sl<WorkOrderRepository>();
      final res = await repo.getDropdowns(divisionId: widget.wo.toDivId);
      res.fold((l) => null, (r) {
        if (mounted) {
          setState(() {
            _users = List<Map<String, dynamic>>.from(r['users'] ?? []);
            _isLoadingUsers = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.needsEstimate
                    ? 'Berikan Estimasi Jam'
                    : 'Tinjau & Putuskan',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Estimasi jam
          TextField(
            controller: _estCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [HHHMMFormatter()],
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.needsEstimate
                  ? 'Estimasi jam kerja (000:00) *'
                  : 'Override estimasi jam (000:00, opsional)',
              hintStyle: const TextStyle(color: AppColors.textDisabled),
              prefixIcon: const Icon(
                Icons.schedule_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              suffixText: 'jam',
              suffixStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          if (widget.needsEstimate) ...[
            const SizedBox(height: 10),
            _isLoadingUsers
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      'Memuat daftar PIC...',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _selectedPicId,
                    dropdownColor: AppColors.surfaceCard,
                    isExpanded: true,
                    items: _users.map((u) {
                      final name = u['full_name'] ?? u['name'] ?? '-';
                      final grade = u['grade'] != null
                          ? ' (${u['grade']})'
                          : '';
                      return DropdownMenuItem<String>(
                        value: u['id'].toString(),
                        child: Text(
                          '$name$grade',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPicId = v),
                    decoration: InputDecoration(
                      hintText: 'Pilih Pelaksana / PIC *',
                      hintStyle: const TextStyle(color: AppColors.textDisabled),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
          ],
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectSheet(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text(
                    'Tolak',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusLocked,
                    side: const BorderSide(color: AppColors.statusLocked),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _confirmApprove(context),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'Setujui',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmApprove(BuildContext context) {
    final est = TimeParser.parseHHmmToDecimal(_estCtrl.text.trim());
    if (widget.needsEstimate) {
      if (est == null || est <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estimasi jam wajib diisi'),
            backgroundColor: AppColors.statusLocked,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_selectedPicId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pelaksana / PIC wajib dipilih'),
            backgroundColor: AppColors.statusLocked,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final nextLabel = _nextRoleLabel(
      widget.wo.currentStage ?? '',
      widget.wo.needsAdvisor,
    );
    final estStr = est != null
        ? '${est.toStringAsFixed(1)} jam'
        : 'estimasi sebelumnya';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Konfirmasi Setujui',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          nextLabel == 'FINAL'
              ? 'WO akan disetujui final dengan $estStr, countdown akan dibuat, dan WO siap dijadikan source jobdesc.'
              : 'WO akan diteruskan ke $nextLabel dengan $estStr.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<WorkOrderBloc>().add(
                ApproveWo(
                  woId: widget.wo.id,
                  estimatedHours: est,
                  notes: _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                  picId: _selectedPicId,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tolak Work Order',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Alasan penolakan wajib diisi',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Tulis alasan penolakan...',
                  hintStyle: TextStyle(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surfaceInput,
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
                    context.read<WorkOrderBloc>().add(
                      RejectWo(woId: widget.wo.id, rejectReason: reason),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusLocked,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Tolak WO',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
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

  (String, Color) _resolve(String stage) => switch (stage) {
    'PENDING_KD_TARGET' => ('MENUNGGU KD', AppColors.gold),
    'PENDING_ADVISOR' => ('MENUNGGU ADV', Colors.orange),
    'PENDING_KP' => ('MENUNGGU KP', Colors.blue),
    'PENDING_MP' => ('MENUNGGU MP', Colors.purple),
    'COUNTDOWN_CREATED' => ('SIAP JOBDESC', AppColors.statusDone),
    'APPROVED' => ('APPROVED', AppColors.statusDone),
    'ON_PROGRESS' => ('PROSES', Colors.blueAccent),
    'REJECTED' => ('DITOLAK', AppColors.statusLocked),
    'DONE' => ('SELESAI', AppColors.statusDone),
    _ => (stage, AppColors.textMuted),
  };
}
