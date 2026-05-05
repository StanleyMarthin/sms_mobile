import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/time_parser.dart';
import '../../domain/entities/task_filter.dart';
import '../../domain/entities/view_task_entity.dart';
import '../bloc/task_view/task_view_bloc.dart';
import '../bloc/task_view/task_view_event.dart';
import '../bloc/task_view/task_view_state.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/task_filters.dart';
import '../widgets/view_task_card.dart';

/// Management task page — displays task list for a specific [TaskType].
///
/// Creates its own [BlocProvider]<[TaskViewBloc]> internally.
/// Used as a direct tab content in the management dashboard — one
/// instance per task type (Harian / Lembur / Plan).
///
/// Roles: OP sees own tasks, KD sees division, ADV/PM sees all.
class TaskViewPage extends StatelessWidget {
  final TaskType taskType;
  final String? focusTaskId;
  final DateTime? initialDate;

  const TaskViewPage({
    super.key,
    this.taskType = TaskType.daily,
    this.focusTaskId,
    this.initialDate,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TaskViewBloc>()
        ..add(LoadViewTasks(
            filter: TaskFilter(
                type: taskType, date: initialDate ?? DateTime.now()))),
      child: _TaskViewContent(taskType: taskType, focusTaskId: focusTaskId),
    );
  }
}

/// Internal task list content with filters and cards.
class _TaskViewContent extends StatelessWidget {
  final TaskType taskType;
  final String? focusTaskId;
  const _TaskViewContent({required this.taskType, required this.focusTaskId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskViewBloc, TaskViewState>(
      listener: _listener,
      builder: (context, state) {
        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () async {
            context.read<TaskViewBloc>().add(const RefreshViewTasks());
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
          child: _buildContent(context, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, TaskViewState state) {
    if (state is TaskViewInitial || state is TaskViewLoading) {
      final filter = state is TaskViewLoading
          ? state.filter
          : TaskFilter(date: DateTime.now());
      return _buildLoadingView(context, filter);
    }

    if (state is TaskViewError) {
      return _buildErrorView(context, state);
    }

    if (state is TaskViewLoaded) {
      return _buildLoadedView(context, state);
    }

    return const SizedBox.shrink();
  }

  // ── Loading view with filter controls ─────────────────
  Widget _buildLoadingView(BuildContext context, TaskFilter filter) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildFilterSection(context, filter, false)),
        const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      ],
    );
  }

  // ── Error view with retry ─────────────────────────────
  Widget _buildErrorView(BuildContext context, TaskViewError state) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _buildFilterSection(context, state.filter, false)),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: AppColors.statusLocked),
                  const SizedBox(height: 16),
                  const Text(
                    'Terjadi Kesalahan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context
                        .read<TaskViewBloc>()
                        .add(LoadViewTasks(filter: state.filter)),
                    icon: const Icon(Icons.refresh, color: AppColors.gold),
                    label: const Text('Coba Lagi',
                        style: TextStyle(color: AppColors.gold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Loaded view with task list ────────────────────────
  Widget _buildLoadedView(BuildContext context, TaskViewLoaded state) {
    final tasks = _sortTasks(state.tasks);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildFilterSection(
              context, state.filter, state.canFilterDivision),
        ),
        SliverToBoxAdapter(child: _buildSectionHeader(state)),
        if (tasks.isEmpty)
          const SliverFillRemaining(child: _EmptyView())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final divisionEntry = _groupByDivision(tasks)[index];
                return _DrilldownTile(
                  icon: Icons.category_outlined,
                  title: divisionEntry.key,
                  subtitle:
                      '${_uniqueUnitCount(divisionEntry.value)} kendaraan • ${divisionEntry.value.length} pekerjaan',
                  trailingLabel: _statusSummary(divisionEntry.value),
                  onTap: () {
                    final taskViewBloc = context.read<TaskViewBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: taskViewBloc,
                          child: _TaskUnitDrilldownPage(
                            title: divisionEntry.key,
                            divisionName: divisionEntry.key,
                            taskType: taskType,
                            focusTaskId: focusTaskId,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: _groupByDivision(tasks).length,
            ),
          ),
        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<ViewTaskEntity> _sortTasks(List<ViewTaskEntity> tasks) {
    if (focusTaskId == null) return tasks;
    final sorted = List<ViewTaskEntity>.from(tasks);
    sorted.sort((a, b) {
      final aFocus = a.planDailyId == focusTaskId ? 1 : 0;
      final bFocus = b.planDailyId == focusTaskId ? 1 : 0;
      return bFocus.compareTo(aFocus);
    });
    return sorted;
  }

  List<MapEntry<String, List<ViewTaskEntity>>> _groupByDivision(
      List<ViewTaskEntity> tasks) {
    final grouped = <String, List<ViewTaskEntity>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.division.divisionName, () => []).add(task);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  int _uniqueUnitCount(List<ViewTaskEntity> tasks) =>
      tasks.map((task) => task.unit.unitId).toSet().length;

  String _statusSummary(List<ViewTaskEntity> tasks) {
    final active = tasks
        .where((task) =>
            task.status == 'PROSES' ||
            task.status == 'CHECK_PROGRESS' ||
            task.status == 'SUBMITTED')
        .length;
    if (active > 0) {
      return '$active berjalan';
    }
    final done = tasks.where((task) => task.status == 'DONE').length;
    if (done == tasks.length) {
      return 'Selesai semua';
    }
    return '${tasks.length} task';
  }

  // ── Filter section ────────────────────────────────────
  Widget _buildFilterSection(
      BuildContext context, TaskFilter filter, bool canFilterDivision) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DateFilterBar(
              selectedDate: filter.date,
              onDateChanged: (date) =>
                  context.read<TaskViewBloc>().add(ChangeTaskDate(date: date)),
            ),
          ),

          if (canFilterDivision) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_hasActiveFilter(filter))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _activeFilterLabel(filter),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                  InkWell(
                    onTap: () => _showFilterSheet(context, filter),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.tune_rounded,
                              size: 18, color: AppColors.gold),
                          if (_activeFilterCount(filter) > 0)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_activeFilterCount(filter)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.background,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActiveFilter(TaskFilter filter) =>
      filter.divisionId != null || filter.unitId != null;

  int _activeFilterCount(TaskFilter filter) {
    var count = 0;
    if (filter.divisionId != null) count++;
    if (filter.unitId != null) count++;
    return count;
  }

  String _activeFilterLabel(TaskFilter filter) {
    final labels = <String>[];
    if (filter.divisionId != null) labels.add('Divisi');
    if (filter.unitId != null) labels.add('Unit');
    return labels.join(' • ');
  }

  Future<void> _showFilterSheet(BuildContext context, TaskFilter filter) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Task',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TaskDivisionFilter(
                  selectedDivisionId: filter.divisionId,
                  onDivisionChanged: (id) => context
                      .read<TaskViewBloc>()
                      .add(ChangeTaskDivision(divisionId: id)),
                ),
                const SizedBox(height: 12),
                TaskUnitFilter(
                  selectedUnitId: filter.unitId,
                  onUnitChanged: (id) => context
                      .read<TaskViewBloc>()
                      .add(ChangeTaskUnit(unitId: id)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context
                              .read<TaskViewBloc>()
                              .add(const ChangeTaskDivision(divisionId: null));
                          context
                              .read<TaskViewBloc>()
                              .add(const ChangeTaskUnit(unitId: null));
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.background,
                        ),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Section header with context info ──────────────────
  Widget _buildSectionHeader(TaskViewLoaded state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daftar Task — ${state.filter.type.label}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Context subtitle intentionally hidden from UI.
                const SizedBox(height: 4),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${state.tasks.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _listener(BuildContext context, TaskViewState state) {
    if (state is! TaskViewLoaded || state.feedbackMessage == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.feedbackMessage!),
        behavior: SnackBarBehavior.floating,
        backgroundColor: state.isFeedbackError
            ? AppColors.statusLocked.withValues(alpha: 0.92)
            : AppColors.statusDone.withValues(alpha: 0.92),
      ),
    );
  }

  Widget? _buildTaskActionArea(
    BuildContext context,
    TaskViewLoaded state,
    dynamic task,
  ) {
    final isBusy = state.actionTaskId == task.planDailyId;
    final checkpointClosed =
        task.isDone || !task.hasRemainingCheckpointSessions;
    final canInputCheckpoint =
        hasPermission(state.role, Permission.taskCheckpoint) &&
            _canCheckpoint(task.status) &&
            !checkpointClosed;
    final canReviewCheckpoint =
        hasPermission(state.role, Permission.taskCheckpoint) &&
            task.checkpointHistory.isNotEmpty;
    final canFinalValidate =
        hasPermission(state.role, Permission.taskCheckpoint) &&
            _canFinalValidate(task.status);

    if (!canInputCheckpoint && !canReviewCheckpoint && !canFinalValidate) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canInputCheckpoint) ...[
          _buildCheckpointActionPanel(
            context,
            state,
            task,
            isBusy,
            checkpointClosed: checkpointClosed,
          ),
        ],
        if (canReviewCheckpoint) ...[
          if (canInputCheckpoint) const SizedBox(height: 10),
          _buildCheckpointReviewPanel(state, task, isBusy),
        ],
        if (canFinalValidate) ...[
          if (canInputCheckpoint || canReviewCheckpoint)
            const SizedBox(height: 10),
          _buildFinalValidationPanel(context, state, task, isBusy),
        ],
      ],
    );
  }

  Widget _buildFinalValidationPanel(
    BuildContext context,
    TaskViewLoaded state,
    dynamic task,
    bool isBusy,
  ) {
    final roleLabel = state.role.toUpperCase();
    final alreadyValidatedByRole = task.hasFinalValidationByRole(state.role);
    final validatorCount = task.finalValidations.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 16, color: AppColors.statusDone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validasi akhir oleh $roleLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            validatorCount > 0
                ? 'Minimal 1 role sudah validasi. KD/ADV/PM bisa lanjut tambah validasi.'
                : 'Wajib minimal 1 validasi (KD/ADV/PM).',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (validatorCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Sudah validasi: ${task.finalValidations.map((item) => item.roleLabel).join(', ')}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.statusDone,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy || alreadyValidatedByRole
                  ? null
                  : () => _showFinalValidationDialog(context, task),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusDone,
                foregroundColor: AppColors.background,
              ),
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                isBusy
                    ? 'Memvalidasi...'
                    : alreadyValidatedByRole
                        ? 'Role ini sudah validasi'
                        : validatorCount > 0
                            ? 'Tambah validasi role ini'
                            : 'Validasi pekerjaan',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointReviewPanel(
    TaskViewLoaded state,
    dynamic task,
    bool isBusy,
  ) {
    final roleLabel = state.role.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_folder_outlined,
                  size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review sesi oleh $roleLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.isDone
                ? 'Pekerjaan sudah selesai. Buka sesi yang ada jika ingin meninjau catatan terakhir.'
                : 'Buka sesi yang sudah diisi untuk melihat atau meninjau hasil checkpoint.',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckpointActionPanel(
      BuildContext context, TaskViewLoaded state, dynamic task, bool isBusy,
      {required bool checkpointClosed}) {
    final canCheckpointByRole =
        hasPermission(state.role, Permission.taskCheckpoint);
    final canSubmitCheckpoint =
        canCheckpointByRole && !checkpointClosed && !isBusy;
    final sessionNow = task.checkpointHistory.length;
    final sessionMax = task.maxCheckpointSessions as int;
    final statusLabel = task.isDone
        ? 'Done'
        : (sessionNow >= sessionMax
            ? 'Batas Tercapai'
            : '$sessionNow/$sessionMax');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Monitoring Jobdesc',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSubmitCheckpoint
                ? () => _showCheckpointDialog(context, task)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: Text(
              isBusy
                  ? 'Menyimpan...'
                  : !canCheckpointByRole
                      ? 'Role Tidak Diizinkan'
                      : task.isDone
                          ? 'Sudah Done'
                          : task.hasRemainingCheckpointSessions
                              ? 'Input Monitoring'
                              : 'Batas Tercapai',
            ),
          ),
        ),
      ],
    );
  }

  bool _canCheckpoint(String status) {
    final normalized = status.trim().toUpperCase();
    return normalized == 'ASSIGNED' ||
        normalized == 'PLAN' ||
        normalized == 'PROSES' ||
        normalized == 'ONPROGRESS' ||
        normalized == 'ON_PROGRESS' ||
        normalized == 'DONE' ||
        normalized == 'READY_QC' ||
        normalized == 'CHECK_PROGRESS' ||
        normalized == 'SUBMITTED';
  }

  bool _canFinalValidate(String status) {
    return false;
  }

  Future<void> _showCheckpointDialog(
    BuildContext context,
    dynamic task, {
    dynamic editingSession,
  }) async {
    final progressCtrl = TextEditingController(
      text: editingSession != null
          ? editingSession.progress.toString()
          : (task.isAssigned ? '20' : '80'),
    );
    final startWorkTimeCtrl = TextEditingController(
      text: editingSession?.startWorkTime ?? '08:00',
    );
    final finishWorkTimeCtrl = TextEditingController(
      text: editingSession?.finishWorkTime ?? _defaultCheckpointTime(),
    );
    final checkpointTimeCtrl = TextEditingController(
      text: editingSession?.checkpointTime ?? _defaultCheckpointTime(),
    );
    String jobStatus = editingSession?.jobStatus ??
        (progressCtrl.text == '100' ? 'DONE' : 'ON_PROGRESS');
    final isEditing = editingSession != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Text(
            isEditing ? 'Edit Monitoring' : 'Monitoring Jobdesc',
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${task.unit.unitName} • ${task.task.namaPanel}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Riwayat: ${task.checkpointHistory.length}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  if (task.checkpointHistory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 30,
                          dataRowMinHeight: 30,
                          dataRowMaxHeight: 42,
                          horizontalMargin: 8,
                          columnSpacing: 14,
                          columns: const [
                            DataColumn(label: Text('Sesi')),
                            DataColumn(label: Text('Start')),
                            DataColumn(label: Text('Finish')),
                            DataColumn(label: Text('Check')),
                            DataColumn(label: Text('Durasi')),
                            DataColumn(label: Text('Prog')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: task.checkpointHistory.map<DataRow>((session) {
                            return DataRow(
                              cells: [
                                DataCell(Text('${session.sessionNumber}')),
                                DataCell(Text(session.startWorkTime)),
                                DataCell(Text(session.finishWorkTime)),
                                DataCell(Text(session.checkpointTime)),
                                DataCell(Text(session.workedDurationLabel)),
                                DataCell(Text('${session.progress}%')),
                                DataCell(Text(session.jobStatusLabel)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: startWorkTimeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [HHMMFormatter()],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Jam mulai kerja',
                      suffixIcon: IconButton(
                        onPressed: () async {
                          final picked = await _pickClockTime(
                            context: dialogContext,
                            initialValue: startWorkTimeCtrl.text.trim(),
                          );
                          if (picked == null) return;

                          setDialogState(() {
                            startWorkTimeCtrl.text = picked;

                            final startMinutes = _parseClockToMinutes(picked);
                            final finishMinutes = _parseClockToMinutes(
                                finishWorkTimeCtrl.text.trim());
                            if (startMinutes != null &&
                                (finishMinutes == null ||
                                    finishMinutes < startMinutes)) {
                              finishWorkTimeCtrl.text =
                                  _addMinutesToClock(picked, 60);
                            }

                            final updatedFinishMinutes = _parseClockToMinutes(
                                finishWorkTimeCtrl.text.trim());
                            final checkpointMinutes = _parseClockToMinutes(
                                checkpointTimeCtrl.text.trim());
                            if (updatedFinishMinutes != null &&
                                (checkpointMinutes == null ||
                                    checkpointMinutes < updatedFinishMinutes)) {
                              checkpointTimeCtrl.text =
                                  finishWorkTimeCtrl.text.trim();
                            }
                          });
                        },
                        icon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: finishWorkTimeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [HHMMFormatter()],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Jam selesai kerja',
                      suffixIcon: IconButton(
                        onPressed: () async {
                          final picked = await _pickClockTime(
                            context: dialogContext,
                            initialValue: finishWorkTimeCtrl.text.trim(),
                          );
                          if (picked == null) return;

                          setDialogState(() {
                            finishWorkTimeCtrl.text = picked;

                            final finishMinutes = _parseClockToMinutes(picked);
                            final checkpointMinutes = _parseClockToMinutes(
                                checkpointTimeCtrl.text.trim());
                            if (finishMinutes != null &&
                                (checkpointMinutes == null ||
                                    checkpointMinutes < finishMinutes)) {
                              checkpointTimeCtrl.text = picked;
                            }
                          });
                        },
                        icon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: progressCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Progres (%)'),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim()) ?? 0;
                      if (parsed >= 100 && jobStatus != 'DONE') {
                        setDialogState(() => jobStatus = 'DONE');
                      } else if (parsed < 100 && jobStatus == 'DONE') {
                        setDialogState(() => jobStatus = 'ON_PROGRESS');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: checkpointTimeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [HHMMFormatter()],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Jam monitoring',
                      suffixIcon: IconButton(
                        onPressed: () async {
                          final picked = await _pickClockTime(
                            context: dialogContext,
                            initialValue: checkpointTimeCtrl.text.trim(),
                          );
                          if (picked == null) return;
                          setDialogState(
                              () => checkpointTimeCtrl.text = picked);
                        },
                        icon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: jobStatus,
                    decoration:
                        const InputDecoration(labelText: 'Status pekerjaan'),
                    dropdownColor: AppColors.surfaceCard,
                    items: const [
                      DropdownMenuItem(
                          value: 'ON_PROGRESS', child: Text('On Progress')),
                      DropdownMenuItem(value: 'DONE', child: Text('Selesai')),
                      DropdownMenuItem(value: 'CANCEL', child: Text('Cancel')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => jobStatus = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final validationMessage = _validateCheckpointTimes(
                  startWorkTime: startWorkTimeCtrl.text.trim(),
                  finishWorkTime: finishWorkTimeCtrl.text.trim(),
                  checkpointTime: checkpointTimeCtrl.text.trim(),
                );
                if (validationMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validationMessage),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor:
                          AppColors.statusLocked.withValues(alpha: 0.92),
                    ),
                  );
                  return;
                }

                if (isEditing) {
                  context.read<TaskViewBloc>().add(
                        UpdateTaskCheckpointSession(
                          planDailyId: task.planDailyId,
                          sessionNumber: editingSession.sessionNumber as int,
                          startWorkTime: startWorkTimeCtrl.text.trim(),
                          finishWorkTime: finishWorkTimeCtrl.text.trim(),
                          progress: int.tryParse(progressCtrl.text.trim()) ?? 0,
                          checkpointTime: checkpointTimeCtrl.text.trim(),
                          jobStatus: jobStatus,
                        ),
                      );
                } else {
                  context.read<TaskViewBloc>().add(
                        SaveTaskCheckpoint(
                          planDailyId: task.planDailyId,
                          startWorkTime: startWorkTimeCtrl.text.trim(),
                          finishWorkTime: finishWorkTimeCtrl.text.trim(),
                          progress: int.tryParse(progressCtrl.text.trim()) ?? 0,
                          checkpointTime: checkpointTimeCtrl.text.trim(),
                          jobStatus: jobStatus,
                        ),
                      );
                }
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
              ),
              child: Text(isEditing ? 'Simpan Edit' : 'Simpan Sesi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCheckpointReviewDialog(
    BuildContext context,
    dynamic task,
    dynamic session,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Sesi ${session.sessionNumber} • Review Check Progress',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.unit.unitName} • ${task.task.namaPanel}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              'Mulai ${session.startWorkTime} • selesai ${session.finishWorkTime} • check ${session.checkpointTime} • ${session.workedDurationLabel} • ${session.progress}% • ${session.jobStatusLabel}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              session.isValidated
                  ? 'Tervalidasi: ${session.reviewersLabel}'
                  : 'Checkpoint backend langsung tercatat ke validation saat disimpan.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showCheckpointDialog(context, task, editingSession: session);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  String _defaultCheckpointTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<String?> _pickClockTime({
    required BuildContext context,
    required String initialValue,
  }) async {
    final initialTime = _parseClockToTimeOfDay(initialValue) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return null;
    return _formatTimeOfDay(picked);
  }

  TimeOfDay? _parseClockToTimeOfDay(String value) {
    final minutes = _parseClockToMinutes(value);
    if (minutes == null) return null;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _addMinutesToClock(String value, int minutesToAdd) {
    final minutes = _parseClockToMinutes(value);
    if (minutes == null) return value;
    final totalMinutes = (minutes + minutesToAdd).clamp(0, (24 * 60) - 1);
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _validateCheckpointTimes({
    required String startWorkTime,
    required String finishWorkTime,
    required String checkpointTime,
  }) {
    final startMinutes = _parseClockToMinutes(startWorkTime);
    if (startMinutes == null) {
      return 'Jam mulai kerja harus memakai format HH:mm.';
    }

    final finishMinutes = _parseClockToMinutes(finishWorkTime);
    if (finishMinutes == null) {
      return 'Jam selesai kerja harus memakai format HH:mm.';
    }

    final checkpointMinutes = _parseClockToMinutes(checkpointTime);
    if (checkpointMinutes == null) {
      return 'Jam check progress harus memakai format HH:mm.';
    }

    if (finishMinutes < startMinutes) {
      return 'Jam selesai kerja tidak boleh lebih awal dari jam mulai kerja.';
    }

    if (checkpointMinutes < finishMinutes) {
      return 'Jam check progress tidak boleh lebih awal dari jam selesai kerja.';
    }

    return null;
  }

  int? _parseClockToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return hour * 60 + minute;
  }

  Future<void> _showFinalValidationDialog(
      BuildContext context, dynamic task) async {
    final noteCtrl = TextEditingController(
      text: 'Pekerjaan selesai dan siap ditutup final.',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Validasi Final Task',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.unit.unitName} • ${task.task.jobName}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Minimal satu dari KD, ADV, atau PM harus memvalidasi pekerjaan ini. Role lain tetap bisa menambah validasi masing-masing untuk penilaian.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              minLines: 2,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration:
                  const InputDecoration(labelText: 'Catatan Validasi Final'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TaskViewBloc>().add(
                    ValidateTaskFinal(
                      planDailyId: task.planDailyId,
                      note: noteCtrl.text.trim(),
                    ),
                  );
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusDone,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Validasi Final'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Empty view
// ═══════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined,
                size: 56, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text(
              'Tidak Ada Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tidak ditemukan task dengan filter yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrilldownTile extends StatelessWidget {
  const _DrilldownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(icon, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskUnitDrilldownPage extends StatelessWidget {
  const _TaskUnitDrilldownPage({
    required this.title,
    required this.divisionName,
    required this.taskType,
    required this.focusTaskId,
  });

  final String title;
  final String divisionName;
  final TaskType taskType;
  final String? focusTaskId;

  String _operatorSummary(List<ViewTaskEntity> tasks) {
    final employees = tasks.map((task) => task.employee.employeeName).toSet();
    if (employees.length == 1) {
      return employees.first;
    }
    return '${employees.length} mekanik';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text(title),
      ),
      body: BlocBuilder<TaskViewBloc, TaskViewState>(
        builder: (context, state) {
          final tasks =
              state is TaskViewLoaded ? state.tasks : const <ViewTaskEntity>[];
          final divisionTasks = tasks
              .where((task) => task.division.divisionName == divisionName)
              .toList();
          final groupedUnits = <String, List<ViewTaskEntity>>{};
          for (final task in divisionTasks) {
            groupedUnits.putIfAbsent(task.unit.unitName, () => []).add(task);
          }
          final entries = groupedUnits.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Divisi $divisionName memiliki ${entries.length} kendaraan.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...entries.map((entry) {
                final unitTasks = List<ViewTaskEntity>.from(entry.value)
                  ..sort((a, b) =>
                      a.task.jobDescription.compareTo(b.task.jobDescription));
                final active = unitTasks
                    .where((task) =>
                        task.status == 'PROSES' ||
                        task.status == 'CHECK_PROGRESS' ||
                        task.status == 'SUBMITTED')
                    .length;
                final trailingLabel = active > 0
                    ? '$active berjalan'
                    : '${unitTasks.length} tugas';
                return _DrilldownTile(
                  icon: Icons.directions_car_filled_outlined,
                  title: entry.key,
                  subtitle:
                      '${unitTasks.length} pekerjaan • ${_operatorSummary(unitTasks)}',
                  trailingLabel: trailingLabel,
                  onTap: () {
                    final taskViewBloc = context.read<TaskViewBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: taskViewBloc,
                          child: _TaskJobdescPage(
                            title: entry.key,
                            unitName: entry.key,
                            taskType: taskType,
                            focusTaskId: focusTaskId,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _TaskJobdescPage extends StatelessWidget {
  const _TaskJobdescPage({
    required this.title,
    required this.unitName,
    required this.taskType,
    required this.focusTaskId,
  });

  final String title;
  final String unitName;
  final TaskType taskType;
  final String? focusTaskId;

  @override
  Widget build(BuildContext context) {
    final viewContent =
        _TaskViewContent(taskType: taskType, focusTaskId: focusTaskId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text(title),
      ),
      body: BlocBuilder<TaskViewBloc, TaskViewState>(
        builder: (context, state) {
          if (state is! TaskViewLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final tasks = List<ViewTaskEntity>.from(
            state.tasks.where((task) => task.unit.unitName == unitName),
          )..sort((a, b) {
              final aFocus = a.planDailyId == focusTaskId ? 1 : 0;
              final bFocus = b.planDailyId == focusTaskId ? 1 : 0;
              if (aFocus != bFocus) {
                return bFocus.compareTo(aFocus);
              }
              return a.task.jobDescription.compareTo(b.task.jobDescription);
            });

          if (tasks.isEmpty) {
            return const _EmptyView();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Kendaraan ini memiliki ${tasks.length} pekerjaan.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...tasks.map(
                (task) => ViewTaskCard(
                  task: task,
                  isHighlighted: task.planDailyId == focusTaskId,
                  showEmployee: state.role != 'op',
                  showDivision: false,
                  onCheckpointTap:
                      hasPermission(state.role, Permission.taskCheckpoint) &&
                              task.checkpointHistory.isNotEmpty
                          ? (session) =>
                              viewContent._showCheckpointReviewDialog(
                                  context, task, session)
                          : null,
                  actionArea:
                      viewContent._buildTaskActionArea(context, state, task),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
