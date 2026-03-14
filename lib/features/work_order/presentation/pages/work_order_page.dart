import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/work_order.dart';
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_event.dart';
import '../bloc/work_order_state.dart';
import '../widgets/wo_card.dart';
import '../widgets/wo_input_sheet.dart';

/// Unified Work Order page — single module for all roles.
///
/// RBAC controls what is visible:
/// - FAB (create WO) → visible only with [Permission.woCreate]
/// - Approve/Reject buttons → visible with [Permission.woApproveAdvisor] or [Permission.woApprovePm]
/// - Extend deadline → visible with [Permission.woExtendDeadline]
/// - OP role sees only their own WOs (read-only)
/// - KD/ADV/PM see all WOs
class WorkOrderPage extends StatelessWidget {
  const WorkOrderPage({super.key, this.focusWorkOrderId});

  final String? focusWorkOrderId;

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final role = session.role;
    final isManagement = hasPermission(role, Permission.dashboardKd);

    return BlocProvider(
      create: (_) {
        final bloc = sl<WorkOrderBloc>();
        if (isManagement) {
          bloc.add(const LoadAllWorkOrders());
        } else {
          bloc.add(const LoadMyWorkOrders());
        }
        return bloc;
      },
      child: _WorkOrderBody(role: role, focusWorkOrderId: focusWorkOrderId),
    );
  }
}

class _WorkOrderBody extends StatefulWidget {
  final String? role;
  final String? focusWorkOrderId;
  const _WorkOrderBody({required this.role, this.focusWorkOrderId});

  @override
  State<_WorkOrderBody> createState() => _WorkOrderBodyState();
}

class _WorkOrderBodyState extends State<_WorkOrderBody> {
  String _statusFilter = 'ACTIVE';
  String _typeFilter = 'ALL';
  bool _onlyReadyTask = false;

  bool get _canCreate => hasPermission(widget.role, Permission.woCreate);
  bool get _canApproveAdv => hasPermission(widget.role, Permission.woApproveAdvisor);
  bool get _canApprovePm => hasPermission(widget.role, Permission.woApprovePm);
  bool get _canExtend => hasPermission(widget.role, Permission.woExtendDeadline);
  bool get _canCreateTask => hasPermission(widget.role, Permission.jobPlanCreate);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkOrderBloc, WorkOrderState>(
      listener: (context, state) {
        if (state is WorkOrderError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.statusLocked,
            behavior: SnackBarBehavior.floating,
          ));
        }
        if (state is WorkOrderActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.statusDone,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        if (state is WorkOrderLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }

        if (state is WorkOrderError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.statusLocked),
                const SizedBox(height: 12),
                Text(state.message,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    final bloc = context.read<WorkOrderBloc>();
                    if (hasPermission(widget.role, Permission.dashboardKd)) {
                      bloc.add(const LoadAllWorkOrders());
                    } else {
                      bloc.add(const LoadMyWorkOrders());
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    foregroundColor: AppColors.gold,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }

        final workOrders = _sortWorkOrders(state is WorkOrderLoaded
            ? state.workOrders
            : state is WorkOrderActionSuccess
                ? state.workOrders
                : <WorkOrder>[]);
        final filteredWorkOrders = _applyFilters(workOrders);

        if (workOrders.isEmpty) {
          return Stack(
            children: [
              _buildEmpty(),
              if (_canCreate)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'wo_create_empty_fab',
                    onPressed: () => _showAddSheet(context),
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.background,
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
            ],
          );
        }

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                _buildFilterPanel(workOrders, filteredWorkOrders),
                const SizedBox(height: 12),
                if (widget.focusWorkOrderId != null &&
                    filteredWorkOrders.any((wo) => wo.id == widget.focusWorkOrderId)) ...[
                  _buildFocusInfo(),
                  const SizedBox(height: 12),
                ],
                _buildApprovalFlowInfo(),
                const SizedBox(height: 16),
                if (filteredWorkOrders.isEmpty)
                  _buildFilteredEmpty()
                else
                  ...filteredWorkOrders.map((wo) => _buildWoCard(context, wo)),
              ],
            ),
            if (_canCreate)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'wo_create_fab',
                  onPressed: () => _showAddSheet(context),
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.background,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWoCard(BuildContext context, WorkOrder wo) {
    final session = sl<SessionManager>();
    final userName = session.fullName ?? '';
    final userId = session.employeeId ?? '';
    final bloc = context.read<WorkOrderBloc>();
    final currentDivision = session.divisionName ?? '';

    // Determine which actions this user can perform on this WO
    final canApproveThis = (wo.isPendingAdvisor && _canApproveAdv) ||
      (wo.isPendingPm && _canApprovePm);
    final canRequestRevisionThis = canApproveThis;

    final canRespondRevisionThis =
      (wo.status == 'REVISION_REQUESTED_ADVISOR' && _canApproveAdv) ||
        (wo.status == 'REVISION_REQUESTED_PM' && _canApprovePm);

    final isRequestingKd =
        _canExtend && wo.requestedById == userId;
    final canRequestExtensionThis = isRequestingKd &&
        !wo.isDone &&
        !wo.isRejected &&
        wo.deadline != null;

    final canRespondExtensionThis = wo.extensionRequestStatus == 'PENDING' &&
      ((_canApproveAdv && (wo.isPendingAdvisor || wo.status == 'REVISION_REQUESTED_ADVISOR')) ||
        (_canApprovePm && (wo.isPendingPm || wo.status == 'REVISION_REQUESTED_PM' || wo.isApproved || wo.isInProgress)));

    final canCreateTaskThis = _canCreateTask &&
      wo.isWO &&
      (wo.isApproved || wo.isInProgress) &&
      currentDivision == wo.toDivision;

    return WoCard(
      wo: wo,
      isHighlighted: wo.id == widget.focusWorkOrderId,
      onApprove: canApproveThis
          ? () => bloc.add(ApproveWo(woId: wo.id, approverName: userName))
          : null,
      onReject: canApproveThis
          ? () => bloc.add(
              RejectWo(woId: wo.id, rejectedBy: userName))
          : null,
      onRequestRevision: canRequestRevisionThis
          ? (newHours, newDeadline, reason) => bloc.add(
                RequestWoRevision(
                  woId: wo.id,
                  requestedEstimatedHours: newHours,
                  requestedDeadline: newDeadline,
                  reason: reason,
                  reviewerName: userName,
                ),
              )
          : null,
      onRespondRevisionApprove: canRespondRevisionThis
          ? (note) => bloc.add(
                RespondWoRevision(
                  woId: wo.id,
                  approve: true,
                  reviewerName: userName,
                  note: note,
                ),
              )
          : null,
      onRespondRevisionReject: canRespondRevisionThis
          ? (note) => bloc.add(
                RespondWoRevision(
                  woId: wo.id,
                  approve: false,
                  reviewerName: userName,
                  note: note,
                ),
              )
          : null,
      onRequestExtension: canRequestExtensionThis
          ? (newDeadline, reason) => bloc.add(
                RequestWoExtension(
                  woId: wo.id,
                  newDeadline: newDeadline,
                  reason: reason,
                  requesterName: userName,
                ),
              )
          : null,
      onRespondExtensionApprove: canRespondExtensionThis
          ? (note) => bloc.add(
                RespondWoExtension(
                  woId: wo.id,
                  approve: true,
                  reviewerName: userName,
                  note: note,
                ),
              )
          : null,
      onRespondExtensionReject: canRespondExtensionThis
          ? (note) => bloc.add(
                RespondWoExtension(
                  woId: wo.id,
                  approve: false,
                  reviewerName: userName,
                  note: note,
                ),
              )
          : null,
      onCreateTask: canCreateTaskThis ? () => _showCreateTaskDialog(context, wo) : null,
      onEdit: wo.isDraft && _canCreate
          ? () {} // TODO: open edit sheet
          : null,
      onDelete: wo.isDraft && _canCreate
          ? () => bloc.add(DeleteWorkOrder(woId: wo.id))
          : null,
    );
  }

  Future<void> _showCreateTaskDialog(BuildContext context, WorkOrder wo) async {
    final date = wo.deadline ?? DateTime.now().toIso8601String().split('T').first;
    context.go(
      '/plans?source=wo&sourceRefId=${Uri.encodeComponent(wo.id)}&date=${Uri.encodeComponent(date)}&autoOpenCreate=1',
    );
  }

  List<WorkOrder> _sortWorkOrders(List<WorkOrder> items) {
    if (widget.focusWorkOrderId == null) return items;
    final ordered = List<WorkOrder>.from(items);
    ordered.sort((a, b) {
      final aFocus = a.id == widget.focusWorkOrderId ? 1 : 0;
      final bFocus = b.id == widget.focusWorkOrderId ? 1 : 0;
      return bFocus.compareTo(aFocus);
    });
    return ordered;
  }

  List<WorkOrder> _applyFilters(List<WorkOrder> items) {
    final session = sl<SessionManager>();
    final currentDivision = session.divisionName ?? '';
    return items.where((wo) {
      if (_typeFilter != 'ALL' && wo.woType != _typeFilter) {
        return false;
      }

      if (_statusFilter == 'ACTIVE' && (wo.isDone || wo.isRejected)) {
        return false;
      }
      if (_statusFilter == 'PENDING' && !wo.isPending) {
        final isRevisionPending = wo.status == 'REVISION_REQUESTED_ADVISOR' ||
            wo.status == 'REVISION_REQUESTED_PM';
        if (!isRevisionPending) {
          return false;
        }
      }
      if (_statusFilter == 'PENDING' && wo.isPending) {
        // pass
      }
      if (_statusFilter == 'REVISION' &&
          wo.status != 'REVISION_REQUESTED_ADVISOR' &&
          wo.status != 'REVISION_REQUESTED_PM') {
        return false;
      }
      if (_statusFilter == 'EXTENSION' && wo.extensionRequestStatus != 'PENDING') {
        return false;
      }
      if (_statusFilter == 'APPROVED' && !wo.isApproved) {
        return false;
      }
      if (_statusFilter == 'IN_PROGRESS' && !wo.isInProgress) {
        return false;
      }
      if (_statusFilter == 'DONE' && !wo.isDone) {
        return false;
      }

      if (_onlyReadyTask) {
        final readyTask = _canCreateTask &&
            wo.isWO &&
            (wo.isApproved || wo.isInProgress) &&
            currentDivision == wo.toDivision;
        if (!readyTask) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildFilterPanel(List<WorkOrder> allItems, List<WorkOrder> filteredItems) {
    final activeFilterCount = [
      if (_statusFilter != 'ACTIVE') 1,
      if (_typeFilter != 'ALL') 1,
      if (_onlyReadyTask) 1,
    ].length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filter Work Order',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${filteredItems.length}/${allItems.length} item',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (activeFilterCount > 0) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _statusFilter = 'ACTIVE';
                      _typeFilter = 'ALL';
                      _onlyReadyTask = false;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Aktif',
                selected: _statusFilter == 'ACTIVE',
                onTap: () => setState(() => _statusFilter = 'ACTIVE'),
              ),
              _FilterChip(
                label: 'Perlu Acc',
                selected: _statusFilter == 'PENDING',
                onTap: () => setState(() => _statusFilter = 'PENDING'),
              ),
              _FilterChip(
                label: 'Perlu Revisi',
                selected: _statusFilter == 'REVISION',
                onTap: () => setState(() => _statusFilter = 'REVISION'),
              ),
              _FilterChip(
                label: 'Req Extend',
                selected: _statusFilter == 'EXTENSION',
                onTap: () => setState(() => _statusFilter = 'EXTENSION'),
              ),
              _FilterChip(
                label: 'Approved',
                selected: _statusFilter == 'APPROVED',
                onTap: () => setState(() => _statusFilter = 'APPROVED'),
              ),
              _FilterChip(
                label: 'Proses',
                selected: _statusFilter == 'IN_PROGRESS',
                onTap: () => setState(() => _statusFilter = 'IN_PROGRESS'),
              ),
              _FilterChip(
                label: 'Selesai',
                selected: _statusFilter == 'DONE',
                onTap: () => setState(() => _statusFilter = 'DONE'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Semua Tipe',
                selected: _typeFilter == 'ALL',
                onTap: () => setState(() => _typeFilter = 'ALL'),
              ),
              _FilterChip(
                label: 'WO',
                selected: _typeFilter == 'WO',
                onTap: () => setState(() => _typeFilter = 'WO'),
              ),
              _FilterChip(
                label: 'WOV',
                selected: _typeFilter == 'WOV',
                onTap: () => setState(() => _typeFilter = 'WOV'),
              ),
              if (_canCreateTask)
                _FilterChip(
                  label: 'Siap Dibuat Task',
                  selected: _onlyReadyTask,
                  onTap: () => setState(() => _onlyReadyTask = !_onlyReadyTask),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFocusInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_active_outlined, size: 14, color: AppColors.gold),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Work order target dari notifikasi ditampilkan paling atas.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final bloc = context.read<WorkOrderBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WoInputSheet(
        onSubmit: (wo) {
          bloc.add(SubmitWorkOrder(workOrder: wo));
        },
      ),
    );
  }

  Widget _buildApprovalFlowInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.gold),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Flow: KD buat WO -> ADV/PM bisa Tolak/Revisi/Acc. KD bisa ajukan perpanjangan deadline untuk di-acc.',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined,
                size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'Belum ada Work Order',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_canCreate) ...[
              const SizedBox(height: 8),
              const Text(
                'Tekan tombol tambah di kanan bawah untuk membuat WO baru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textDisabled,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.filter_alt_off_rounded,
              size: 42, color: AppColors.textDisabled),
          SizedBox(height: 10),
          Text(
            'Tidak ada work order yang cocok dengan filter ini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.16) : AppColors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.gold : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
