/*
Tujuan: Halaman monitoring task management dengan polymorphic UI untuk self-task vs checkpoint.
Caller: TasksPage dan drilldown task section/unit management.
Dependensi: TaskViewBloc, SessionManager, RBAC, MechanicTaskPage.
Main Functions: build, _buildTaskActionArea, _openSelfExecutionFlow, _showCheckpointDialog.
Side Effects: Load task management, navigasi ke flow mekanik, submit checkpoint management.
*/
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/task_filter.dart';
import '../../domain/entities/view_task_entity.dart';
import '../bloc/task_view/task_view_bloc.dart';
import '../bloc/task_view/task_view_event.dart';
import '../bloc/task_view/task_view_state.dart';
import '../widgets/date_filter_bar.dart';
import '../widgets/task_filters.dart';
import '../widgets/view_task_card.dart';
import 'mechanic_task_page.dart';

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
        ..add(
          LoadViewTasks(
            filter: TaskFilter(
              type: taskType,
              date: initialDate ?? DateTime.now(),
            ),
          ),
        ),
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
            context.read<TaskViewBloc>().add(RefreshViewTasks());
            await Future<void>.delayed(Duration(milliseconds: 500));
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

    return SizedBox.shrink();
  }

  // ── Loading view with filter controls ─────────────────
  Widget _buildLoadingView(BuildContext context, TaskFilter filter) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildFilterSection(context, filter, false)),
        SliverFillRemaining(
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
          child: _buildFilterSection(context, state.filter, false),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: AppColors.statusLocked,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Terjadi Kesalahan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => context.read<TaskViewBloc>().add(
                      LoadViewTasks(filter: state.filter),
                    ),
                    icon: Icon(Icons.refresh, color: AppColors.gold),
                    label: Text(
                      'Coba Lagi',
                      style: TextStyle(color: AppColors.gold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
    final groupedDivisions = _groupByDivision(tasks);

    // Jika hanya ada 1 divisi (kasus KD), langsung tampilkan Unitnya saja agar simple.
    final skipDivision = groupedDivisions.length == 1;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildFilterSection(
            context,
            state.filter,
            state.canFilterDivision,
          ),
        ),

        // Tambahkan Ringkasan Status Monitoring di paling atas
        SliverToBoxAdapter(child: _buildMonitoringSummary(tasks)),

        SliverToBoxAdapter(child: _buildSectionHeader(state)),

        if (tasks.isEmpty)
          SliverFillRemaining(child: _EmptyView())
        else if (skipDivision)
          _buildDirectUnitList(context, state, groupedDivisions.first.value)
        else
          _buildDivisionList(context, groupedDivisions),

        // Bottom padding
        SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildMonitoringSummary(List<ViewTaskEntity> tasks) {
    if (tasks.isEmpty) return SizedBox.shrink();

    final active = tasks
        .where((t) => t.status == 'PROSES' || t.status == 'CHECK_PROGRESS')
        .length;
    final done = tasks.where((t) => t.status == 'DONE').length;
    final pending = tasks.length - active - done;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _summaryCounter('Belum', pending, AppColors.orange),
          SizedBox(width: 8),
          _summaryCounter('Aktif', active, AppColors.gold),
          SizedBox(width: 8),
          _summaryCounter('Selesai', done, AppColors.statusDone),
        ],
      ),
    );
  }

  Widget _summaryCounter(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivisionList(
    BuildContext context,
    List<MapEntry<String, List<ViewTaskEntity>>> entries,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = entries[index];
        return _DrilldownTile(
          icon: Icons.category_outlined,
          title: entry.key,
          subtitle:
              '${_uniqueUnitCount(entry.value)} kendaraan • ${entry.value.length} pekerjaan',
          trailingLabel: _statusSummary(entry.value),
          onTap: () => _navigateToUnits(context, entry.key, entry.key),
        );
      }, childCount: entries.length),
    );
  }

  Widget _buildDirectUnitList(
    BuildContext context,
    TaskViewLoaded state,
    List<ViewTaskEntity> divisionTasks,
  ) {
    final groupedUnits = <String, List<ViewTaskEntity>>{};
    for (final task in divisionTasks) {
      groupedUnits.putIfAbsent(task.unit.unitName, () => []).add(task);
    }
    final entries = groupedUnits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = entries[index];
        return _DrilldownTile(
          icon: Icons.directions_car_filled_outlined,
          title: entry.key,
          subtitle:
              '${entry.value.length} pekerjaan • ${_operatorSummary(entry.value)}',
          trailingLabel: _statusSummary(entry.value),
          onTap: () => _navigateToJobdescs(
            context,
            entry.key,
            entry.key,
            state.filter.divisionId ??
                divisionTasks.first.division.divisionName,
          ),
        );
      }, childCount: entries.length),
    );
  }

  void _navigateToUnits(
    BuildContext context,
    String title,
    String divisionName,
  ) {
    final taskViewBloc = context.read<TaskViewBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: taskViewBloc,
          child: _TaskUnitDrilldownPage(
            title: title,
            divisionName: divisionName,
            taskType: taskType,
            focusTaskId: focusTaskId,
          ),
        ),
      ),
    );
  }

  void _navigateToJobdescs(
    BuildContext context,
    String title,
    String unitName,
    String divisionName,
  ) {
    final taskViewBloc = context.read<TaskViewBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: taskViewBloc,
          child: _TaskJobdescPage(
            title: title,
            unitName: unitName,
            divisionName: divisionName,
            taskType: taskType,
            focusTaskId: focusTaskId,
          ),
        ),
      ),
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
    List<ViewTaskEntity> tasks,
  ) {
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

  String _operatorSummary(List<ViewTaskEntity> tasks) {
    final employees = tasks.map((task) => task.employee.employeeName).toSet();
    if (employees.isEmpty) return 'Belum ada mekanik';
    if (employees.length == 1) return employees.first;
    return '${employees.length} mekanik';
  }

  String _statusSummary(List<ViewTaskEntity> tasks) {
    final active = tasks
        .where(
          (task) =>
              task.status == 'PROSES' ||
              task.status == 'CHECK_PROGRESS' ||
              task.status == 'SUBMITTED',
        )
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
    BuildContext context,
    TaskFilter filter,
    bool canFilterDivision,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date filter bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: DateFilterBar(
              selectedDate: filter.date,
              onDateChanged: (date) =>
                  context.read<TaskViewBloc>().add(ChangeTaskDate(date: date)),
            ),
          ),

          if (canFilterDivision) ...[
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_hasActiveFilter(filter))
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        _activeFilterLabel(filter),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () => _showFilterSheet(context, filter),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: AppColors.gold,
                          ),
                          if (_activeFilterCount(filter) > 0)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_activeFilterCount(filter)}',
                                  style: TextStyle(
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Task',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12),
                TaskDivisionFilter(
                  selectedDivisionId: filter.divisionId,
                  onDivisionChanged: (id) => context.read<TaskViewBloc>().add(
                    ChangeTaskDivision(divisionId: id),
                  ),
                ),
                SizedBox(height: 12),
                TaskUnitFilter(
                  selectedUnitId: filter.unitId,
                  onUnitChanged: (id) => context.read<TaskViewBloc>().add(
                    ChangeTaskUnit(unitId: id),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.read<TaskViewBloc>().add(
                            ChangeTaskDivision(divisionId: null),
                          );
                          context.read<TaskViewBloc>().add(
                            ChangeTaskUnit(unitId: null),
                          );
                        },
                        icon: Icon(Icons.refresh_rounded, size: 16),
                        label: Text('Reset'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.background,
                        ),
                        child: Text('Tutup'),
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
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daftar Task — ${state.filter.type.label}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Context subtitle intentionally hidden from UI.
                SizedBox(height: 4),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${state.tasks.length}',
              style: TextStyle(
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
    if (task is! ViewTaskEntity) {
      return null;
    }

    final isBusy = state.actionTaskId == task.planDailyId;
    final isSelfExecutionCandidate = _isSelfExecutionCandidate(
      state: state,
      task: task,
    );

    if (isSelfExecutionCandidate) {
      return _buildSelfExecutionPanel(context, state, task);
    }

    // Pimpinan (KD/ADV/PM) harus selalu bisa melakukan monitoring/intervensi
    // meskipun status sudah DONE atau READY_QC, untuk kebutuhan audit/koreksi.
    final canInputCheckpoint =
        hasPermission(state.role, Permission.taskCheckpoint) &&
        _canCheckpoint(task.status);

    final canFinalValidate =
        hasPermission(state.role, Permission.taskCheckpoint) &&
        _canFinalValidate(task.status);

    if (!canInputCheckpoint && !canFinalValidate) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canInputCheckpoint) ...[
          _buildCheckpointActionPanel(context, state, task, isBusy),
        ],
        if (canFinalValidate) ...[
          if (canInputCheckpoint) SizedBox(height: 10),
          _buildFinalValidationPanel(context, state, task, isBusy),
        ],
      ],
    );
  }

  bool _isSelfExecutionCandidate({
    required TaskViewLoaded state,
    required ViewTaskEntity task,
  }) {
    if (taskType == TaskType.plan) return false;
    if (state.role == 'op') return false;
    if (task.isDone || task.isValidated || task.hasFinalValidation) {
      return false;
    }

    final session = sl<SessionManager>();
    final currentIds = <String>{
      if ((session.userId ?? '').trim().isNotEmpty) session.userId!.trim(),
      if ((session.employeeId ?? '').trim().isNotEmpty)
        session.employeeId!.trim(),
    };

    return currentIds.contains(task.employee.employeeId.trim());
  }

  Widget _buildSelfExecutionPanel(
    BuildContext context,
    TaskViewLoaded state,
    ViewTaskEntity task,
  ) {
    final isOvertime = state.filter.type == TaskType.overtime;
    final ctaLabel = task.isAssigned
        ? 'Mulai sebagai PIC'
        : 'Lanjutkan sebagai PIC';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
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
              Icon(
                Icons.play_circle_outline,
                size: 16,
                color: AppColors.gold,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Self execution',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Jobdesc ini ter-assign ke Anda. Gunakan flow anggota biasa agar tidak perlu input checkpoint manual.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openSelfExecutionFlow(
                context,
                task: task,
                date: state.filter.date,
                isOvertime: isOvertime,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
              ),
              icon: Icon(Icons.play_circle_outline),
              label: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }

  void _openSelfExecutionFlow(
    BuildContext context, {
    required ViewTaskEntity task,
    required DateTime date,
    required bool isOvertime,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MechanicTaskPage(
          isOvertime: isOvertime,
          title: isOvertime ? 'Lembur Saya' : 'Task Saya',
          focusTaskId: task.planDailyId,
          initialDate: date,
          forceOwnOnly: true,
        ),
      ),
    );
  }

  Widget _buildFinalValidationPanel(
    BuildContext context,
    TaskViewLoaded state,
    dynamic task,
    bool isBusy,
  ) {
    final roleLabel = state.role.trim().toUpperCase() == 'ADV'
        ? 'QA'
        : state.role.toUpperCase();
    final alreadyValidatedByRole = task.hasFinalValidationByRole(state.role);
    final validatorCount = task.finalValidations.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
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
              Icon(
                Icons.verified_outlined,
                size: 16,
                color: AppColors.statusDone,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validasi akhir oleh $roleLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            validatorCount > 0
                ? 'Minimal 1 role sudah validasi. KD/QA/PM bisa lanjut tambah validasi.'
                : 'Wajib minimal 1 validasi (KD/QA/PM).',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (validatorCount > 0) ...[
            SizedBox(height: 8),
            Text(
              'Sudah validasi: ${task.finalValidations.map((item) => item.roleLabel).join(', ')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.statusDone,
              ),
            ),
          ],
          SizedBox(height: 10),
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
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : Icon(Icons.verified_outlined),
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

  Widget _buildCheckpointActionPanel(
    BuildContext context,
    TaskViewLoaded state,
    dynamic task,
    bool isBusy,
  ) {
    final canCheckpointByRole = hasPermission(
      state.role,
      Permission.taskCheckpoint,
    );

    final sessionNow = task.managementCheckpointHistory.length;
    final sessionMax = task.maxCheckpointSessions as int;

    // Cek apakah jobdesc sudah dimulai (bukan ASSIGNED/PLAN)
    final hasStarted = _hasTaskStarted(task.status as String);

    // Monitoring manajemen maksimal 3 sesi, berhenti jika sesi terakhir DONE/PENDING.
    final isUnderLimit = task.hasRemainingCheckpointSessions;
    final canSubmitCheckpoint =
        canCheckpointByRole && !isBusy && isUnderLimit && hasStarted;

    final statusLabel = task.isDone || task.isCheckpointFlowFinished
        ? 'Selesai'
        : (!isUnderLimit
              ? 'Batas $sessionNow sesi terpenuhi'
              : 'Sesi $sessionNow/$sessionMax');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
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
                  Expanded(
                    child: Text(
                      'Monitoring',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              // Tampilkan info jika jobdesc belum dimulai
              if (!hasStarted) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.orange,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Jobdesc belum mulai — input monitoring tersedia setelah mekanik memulai pekerjaan.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 10),
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
                  ? 'Tidak diizinkan'
                  : !hasStarted
                  ? 'Belum bisa dimonitor'
                  : !isUnderLimit
                  ? 'Sesi penuh'
                  : 'Input monitoring',
            ),
          ),
        ),
      ],
    );
  }

  bool _hasTaskStarted(String status) {
    final normalized = status.trim().toUpperCase();
    return normalized == 'PROSES' ||
        normalized == 'ONPROGRESS' ||
        normalized == 'ON_PROGRESS' ||
        normalized == 'CHECK_PROGRESS' ||
        normalized == 'SUBMITTED' ||
        normalized == 'DONE' ||
        normalized == 'READY_QC';
  }

  bool _canCheckpoint(String status) {
    // Hanya izinkan monitoring jika mekanik sudah mulai kerja
    return _hasTaskStarted(status);
  }

  bool _canFinalValidate(String status) {
    return false;
  }

  Future<void> _showCheckpointDialog(
    BuildContext context,
    ViewTaskEntity task, {
    TaskCheckpointSession? editingSession,
  }) async {
    final currentSystemProgress = _currentCheckpointProgress(
      task,
      editingSession: editingSession,
    );
    final defaultStartWorkTime = _defaultCheckpointStartTime(
      task,
      editingSession: editingSession,
    );
    final defaultFinishWorkTime = _defaultCheckpointFinishTime(
      task,
      editingSession: editingSession,
    );

    final progressCtrl = TextEditingController(
      text: currentSystemProgress.toString(),
    );

    // KD biasanya melakukan monitoring di waktu sekarang
    final checkpointTimeCtrl = TextEditingController(
      text: editingSession?.checkpointTime ?? _defaultCheckpointTime(),
    );

    String jobStatus =
        editingSession?.jobStatus ??
        (int.tryParse(progressCtrl.text) == 100 ? 'DONE' : 'ON_PROGRESS');

    final isEditing = editingSession != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEditing ? 'Edit Monitoring' : 'Monitoring Progres',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Info Unit & Job ---
                  Text(
                    task.task.namaPanel,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    task.task.jobDescription.isNotEmpty
                        ? task.task.jobDescription
                        : task.task.jobName,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 20),

                  // --- Status Report Mekanik (Informasi Utama) ---
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress terakhir:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '$currentSystemProgress%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // --- Input Progres KD ---
                  Text(
                    'Progress pantauan (0-100)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: progressCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceInput,
                      suffixText: '%',
                      suffixStyle: TextStyle(
                        fontSize: 18,
                        color: AppColors.textMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim()) ?? 0;
                      if (parsed >= 100 && jobStatus != 'DONE') {
                        setDialogState(() => jobStatus = 'DONE');
                      } else if (parsed < 100 && jobStatus == 'DONE') {
                        setDialogState(() => jobStatus = 'ON_PROGRESS');
                      }
                    },
                  ),
                  SizedBox(height: 16),

                  // --- Jam Monitoring ---
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Waktu monitoring:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Spacer(),
                      InkWell(
                        onTap: () async {
                          final picked = await _pickClockTime(
                            context: dialogContext,
                            initialValue: checkpointTimeCtrl.text.trim(),
                          );
                          if (picked != null) {
                            setDialogState(
                              () => checkpointTimeCtrl.text = picked,
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            checkpointTimeCtrl.text,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // --- Status Pekerjaan ---
                  DropdownButtonFormField<String>(
                    initialValue: jobStatus,
                    decoration: InputDecoration(
                      labelText: 'Status monitoring',
                    ),
                    dropdownColor: AppColors.surfaceCard,
                    items: [
                      DropdownMenuItem(
                        value: 'ON_PROGRESS',
                        child: Text('On Progress'),
                      ),
                      DropdownMenuItem(value: 'DONE', child: Text('Selesai')),
                      DropdownMenuItem(
                        value: 'PENDING',
                        child: Text('Pending'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => jobStatus = value);
                      }
                    },
                  ),
                  if (jobStatus == 'PENDING') ...[
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Status pending hanya menandai hasil monitoring, bukan mengubah hasil kerja anggota.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // --- Riwayat Singkat (Vertical Timeline) ---
                  if (task.managementCheckpointHistory.isNotEmpty) ...[
                    SizedBox(height: 24),
                    Text(
                      'Riwayat monitoring',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...task.managementCheckpointHistory.reversed
                        .take(2)
                        .map(
                          (session) => Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sesi ${task.managementCheckpointDisplayNumber(session)} • ${session.checkpointTime} • ${session.progress}% • ${session.jobStatusLabel}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'BATAL',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            FilledButton(
              onPressed: () {
                final progressVal = int.tryParse(progressCtrl.text.trim()) ?? 0;

                if (isEditing) {
                  context.read<TaskViewBloc>().add(
                    UpdateTaskCheckpointSession(
                      planDailyId: task.planDailyId,
                      sessionNumber: editingSession.sessionNumber,
                      startWorkTime: defaultStartWorkTime,
                      finishWorkTime: defaultFinishWorkTime,
                      progress: progressVal,
                      checkpointTime: checkpointTimeCtrl.text.trim(),
                      jobStatus: jobStatus,
                    ),
                  );
                } else {
                  context.read<TaskViewBloc>().add(
                    SaveTaskCheckpoint(
                      planDailyId: task.planDailyId,
                      startWorkTime: defaultStartWorkTime,
                      finishWorkTime: defaultFinishWorkTime,
                      progress: progressVal,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEditing ? 'Simpan perubahan' : 'Simpan monitoring'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCheckpointReviewDialog(
    BuildContext context,
    ViewTaskEntity task,
    TaskCheckpointSession session,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Monitoring ${task.managementCheckpointDisplayNumber(session)}',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.task.namaPanel} • ${task.unit.unitName}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              '${session.progress}% • ${session.jobStatusLabel}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mulai ${session.startWorkTime} • selesai ${session.finishWorkTime} • cek ${session.checkpointTime} • durasi ${session.workedDurationLabel}',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            if (session.isValidated) ...[
              SizedBox(height: 8),
              Text(
                'Tervalidasi: ${session.reviewersLabel}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ] else ...[
              SizedBox(height: 8),
              Text(
                'Catatan monitoring ini tidak mengubah hasil kerja anggota.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Tutup'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showCheckpointDialog(context, task, editingSession: session);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: BorderSide(color: AppColors.gold),
            ),
            child: Text('Ubah'),
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

  int _currentCheckpointProgress(
    ViewTaskEntity task, {
    TaskCheckpointSession? editingSession,
  }) {
    if (editingSession != null) {
      return editingSession.progress.clamp(0, 100);
    }
    return task.progressPercent;
  }

  String _defaultCheckpointStartTime(
    ViewTaskEntity task, {
    TaskCheckpointSession? editingSession,
  }) {
    final candidate = editingSession?.startWorkTime ?? task.task.startTime;
    return _parseClockToMinutes(candidate) == null ? '08:00' : candidate;
  }

  String _defaultCheckpointFinishTime(
    ViewTaskEntity task, {
    TaskCheckpointSession? editingSession,
  }) {
    final candidate =
        editingSession?.finishWorkTime ?? task.task.targetFinishTime;
    if (_parseClockToMinutes(candidate) != null) {
      return candidate;
    }
    return _addMinutesToClock(
      _defaultCheckpointStartTime(task, editingSession: editingSession),
      8 * 60,
    );
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
    BuildContext context,
    dynamic task,
  ) async {
    final noteCtrl = TextEditingController(
      text: 'Pekerjaan selesai dan siap ditutup final.',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Validasi Final Task',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.unit.unitName} • ${task.task.jobName}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              'Minimal satu dari KD, QA, atau PM harus memvalidasi pekerjaan ini. Role lain tetap bisa menambah validasi masing-masing untuk penilaian.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              minLines: 2,
              maxLines: 3,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Catatan Validasi Final',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Batal'),
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
            child: Text('Validasi Final'),
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
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 56,
              color: AppColors.textDisabled,
            ),
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
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
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
        margin: EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: EdgeInsets.all(14),
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                SizedBox(height: 6),
                Icon(
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
          final tasks = state is TaskViewLoaded
              ? state.tasks
              : <ViewTaskEntity>[];
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
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Divisi $divisionName memiliki ${entries.length} kendaraan.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 12),
              ...entries.map((entry) {
                final unitTasks = List<ViewTaskEntity>.from(entry.value)
                  ..sort(
                    (a, b) =>
                        a.task.jobDescription.compareTo(b.task.jobDescription),
                  );
                final active = unitTasks
                    .where(
                      (task) =>
                          task.status == 'PROSES' ||
                          task.status == 'CHECK_PROGRESS' ||
                          task.status == 'SUBMITTED',
                    )
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
                            divisionName: divisionName,
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
    required this.divisionName,
    required this.taskType,
    required this.focusTaskId,
  });

  final String title;
  final String unitName;
  final String divisionName;
  final TaskType taskType;
  final String? focusTaskId;

  @override
  Widget build(BuildContext context) {
    final viewContent = _TaskViewContent(
      taskType: taskType,
      focusTaskId: focusTaskId,
    );

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
            return Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final tasks =
              List<ViewTaskEntity>.from(
                state.tasks.where(
                  (task) =>
                      task.unit.unitName == unitName &&
                      task.division.divisionName == divisionName,
                ),
              )..sort((a, b) {
                final aFocus = a.planDailyId == focusTaskId ? 1 : 0;
                final bFocus = b.planDailyId == focusTaskId ? 1 : 0;
                if (aFocus != bFocus) {
                  return bFocus.compareTo(aFocus);
                }
                return a.task.jobDescription.compareTo(b.task.jobDescription);
              });

          if (tasks.isEmpty) {
            return _EmptyView();
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Kendaraan ini memiliki ${tasks.length} pekerjaan.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 12),
              ...tasks.map(
                (task) => ViewTaskCard(
                  task: task,
                  taskDate: state.filter.date.toIso8601String().substring(
                    0,
                    10,
                  ),
                  isHighlighted: task.planDailyId == focusTaskId,
                  showEmployee: state.role != 'op',
                  showDivision: false,
                  onCheckpointTap:
                      hasPermission(state.role, Permission.taskCheckpoint) &&
                          task.managementCheckpointHistory.isNotEmpty
                      ? (TaskCheckpointSession session) => viewContent
                            ._showCheckpointReviewDialog(context, task, session)
                      : null,
                  actionArea: viewContent._buildTaskActionArea(
                    context,
                    state,
                    task,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
