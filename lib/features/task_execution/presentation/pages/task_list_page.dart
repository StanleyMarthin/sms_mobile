/*
Tujuan: Menampilkan daftar task mekanik per tanggal/unit termasuk mode self-only.
Caller: MechanicTaskPage.
Dependensi: TaskBloc, SessionManager, TaskCard, sheet start/submit task.
Main Functions: build, _checkAutoNavigate, _showExecutionSheet.
Side Effects: Dispatch event load/retry task dan buka modal eksekusi.
*/
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_entity.dart';
import '../bloc/task_bloc.dart';
import '../bloc/task_event.dart';
import '../bloc/task_state.dart';
import '../widgets/task_card.dart';
import '../widgets/task_execution_sheet.dart';
import '../widgets/task_start_sheet.dart';
import '../widgets/task_execution_detail_sheet.dart';

/// Mechanic's task list — shows today's assignments.
///
/// [isOvertime] controls whether to load normal or overtime tasks.
/// Each instance gets its own [BlocProvider]<[TaskBloc]> from the dashboard.
///
/// No Scaffold; the parent dashboard provides AppBar and bottom nav.
class TaskListPage extends StatefulWidget {
  final bool isOvertime;
  final DateTime selectedDate;
  final String title;
  final String? focusTaskId;
  final bool forceOwnOnly;

  const TaskListPage({
    super.key,
    this.isOvertime = false,
    required this.selectedDate,
    required this.title,
    this.focusTaskId,
    this.forceOwnOnly = false,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  bool _hasAutoNavigated = false;

  void _checkAutoNavigate(List<TaskEntity>? tasks) {
    if (widget.focusTaskId == null ||
        _hasAutoNavigated ||
        tasks == null ||
        tasks.isEmpty)
      return;

    try {
      final targetTask = tasks.firstWhere(
        (t) => t.plandailyId == widget.focusTaskId,
      );
      _hasAutoNavigated = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final taskBloc = context.read<TaskBloc>();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: taskBloc,
              child: _MechanicJobdescPage(
                title: targetTask.unitName,
                unitName: targetTask.unitName,
                focusTaskId: widget.focusTaskId,
                isOvertime: widget.isOvertime,
              ),
            ),
          ),
        );
      });
    } catch (_) {
      // Task not found
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskBloc, TaskState>(
      listener: _blocListener,
      builder: (context, state) {
        if (state is TaskInitial || state is TaskLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }

        if (state is TaskError) {
          return _ErrorView(
            message: state.message,
            onRetry: () => context.read<TaskBloc>().add(
              LoadTodaysTasksEvent(
                isOvertime: widget.isOvertime,
                date: widget.selectedDate,
                forceOwnOnly: widget.forceOwnOnly,
              ),
            ),
          );
        }

        final tasks = _sortedTasks(
          _extractTasks(state)
              .where((t) => t.isOvertime == widget.isOvertime)
              .toList(),
        );


        // Auto navigate if needed
        _checkAutoNavigate(tasks);

        if (tasks == null || tasks.isEmpty) {
          return _EmptyView(
            onRefresh: () =>
                context.read<TaskBloc>().add(const RefreshTasksEvent()),
          );
        }

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () async {
            context.read<TaskBloc>().add(const RefreshTasksEvent());
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _buildSectionHeader(tasks.length),
              ..._groupByUnit(tasks).map(
                (unitEntry) => _DrilldownTile(
                  icon: Icons.directions_car_filled_outlined,
                  title: unitEntry.key,
                  subtitle:
                      '${unitEntry.value.first.ownerName} • ${unitEntry.value.length} jobdesc',
                  trailingLabel: _statusSummary(unitEntry.value),
                  onTap: () {
                    final taskBloc = context.read<TaskBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: taskBloc,
                          child: _MechanicJobdescPage(
                            title: unitEntry.key,
                            unitName: unitEntry.key,
                            focusTaskId: widget.focusTaskId,
                            isOvertime: widget.isOvertime,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<TaskEntity>? _sortedTasks(List<dynamic>? rawTasks) {
    final tasks = rawTasks?.cast<TaskEntity>();
    if (tasks == null || widget.focusTaskId == null) return tasks;

    final ordered = List<TaskEntity>.from(tasks);
    ordered.sort((a, b) {
      final aFocus = a.plandailyId == widget.focusTaskId ? 1 : 0;
      final bFocus = b.plandailyId == widget.focusTaskId ? 1 : 0;
      return bFocus.compareTo(aFocus);
    });
    return ordered;
  }

  List<MapEntry<String, List<TaskEntity>>> _groupByUnit(
    List<TaskEntity> tasks,
  ) {
    final grouped = <String, List<TaskEntity>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.unitName, () => []).add(task);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  String _statusSummary(List<TaskEntity> tasks) {
    final active = tasks.where((task) => task.isInProgress).length;
    if (active > 0) return '$active aktif';
    final done = tasks.where((task) => task.isCompleted).length;
    if (done == tasks.length) return 'semua selesai';
    return '${tasks.length} task';
  }

  // ── Section header with name, division, date ──────────────
  Widget _buildSectionHeader(int count) {
    final session = sl<SessionManager>();
    final name = session.fullName ?? 'MECHANIC';
    final date = widget.selectedDate;
    final dayNames = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final monthNames = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dateStr =
        '${dayNames[date.weekday % 7]}, ${date.day} ${monthNames[date.month]} ${date.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: "My Assignments" + count badge
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.title} — $name',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Date row
          Row(
            children: [
              const Icon(Icons.today, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '|  $dateStr',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Listener ──────────────────────────────────────────────
  void _blocListener(BuildContext context, TaskState state) {
    if (state is TaskActionSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.statusDone.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (state is TaskActionError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.statusLocked.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  List<TaskEntity> _extractTasks(TaskState state) {
    if (state is TaskLoaded) return state.tasks;
    if (state is TaskActionLoading) return state.tasks;
    if (state is TaskActionSuccess) return state.tasks;
    if (state is TaskActionError) return state.tasks;
    return const [];
  }
}

// ═══════════════════════════════════════════════════════════════
// Error view
// ═══════════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.statusLocked,
            ),
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: AppColors.gold),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(color: AppColors.gold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Empty view
// ═══════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 56,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak Ada Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Belum ada task yang dijadwalkan untuk hari ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.gold),
              label: const Text(
                'Refresh',
                style: TextStyle(color: AppColors.gold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailingLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 2),
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

class _MechanicJobdescPage extends StatefulWidget {
  const _MechanicJobdescPage({
    required this.title,
    required this.unitName,
    required this.focusTaskId,
    required this.isOvertime,
  });

  final String title;
  final String unitName;
  final String? focusTaskId;
  final bool isOvertime;

  @override
  State<_MechanicJobdescPage> createState() => _MechanicJobdescPageState();
}

class _MechanicJobdescPageState extends State<_MechanicJobdescPage> {
  bool _hasAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _checkAutoOpen();
  }

  void _checkAutoOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusTaskId == null || _hasAutoOpened || !mounted) return;

      final taskBloc = context.read<TaskBloc>();
      final state = taskBloc.state;
      final tasks = _extractTasks(state);

      try {
        final task = tasks.firstWhere(
          (t) => t.plandailyId == widget.focusTaskId,
        );
        _hasAutoOpened = true;
        _showExecutionSheet(context, task);
      } catch (_) {
        // focusTaskId not found in this unit list
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text(widget.title),
      ),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          final tasks =
              _extractTasks(state)
                  .where(
                    (task) =>
                        task.unitName == widget.unitName &&
                        task.isOvertime == widget.isOvertime,
                  )
                  .toList()
                ..sort(
                  (a, b) => a.customDescription.compareTo(b.customDescription),
                );
          final drafts = _extractDrafts(state);
          final actionTaskId = state is TaskActionLoading
              ? state.actionTaskId
              : null;

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
                  '${tasks.length} jobdesc untuk kendaraan ini.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...tasks.map(
                (task) => TaskCard(
                  task: task,
                  isHighlighted: task.plandailyId == widget.focusTaskId,
                  isActionLoading: actionTaskId == task.plandailyId,
                  hasDraft: drafts.containsKey(task.plandailyId),
                  onTap: () => _showExecutionSheet(context, task),
                  onStartPressed: () => _showExecutionSheet(context, task),
                  onFinishPressed: () => _showExecutionSheet(context, task),
                  onViewDetail: () => _showTaskDetailSheet(context, task),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TaskEntity> _extractTasks(TaskState state) {
    if (state is TaskLoaded) return state.tasks;
    if (state is TaskActionLoading) return state.tasks;
    if (state is TaskActionSuccess) return state.tasks;
    if (state is TaskActionError) return state.tasks;
    return const [];
  }

  Map<String, TaskDraft> _extractDrafts(TaskState state) {
    if (state is TaskLoaded) return state.drafts;
    if (state is TaskActionLoading) return state.drafts;
    if (state is TaskActionSuccess) return state.drafts;
    if (state is TaskActionError) return state.drafts;
    return const {};
  }

  void _showExecutionSheet(BuildContext context, TaskEntity task) {
    if (task.isCompleted) return;
    if (task.isMonitoringLocked) return;
    if (task.isPanelLocked && task.lockedByName != null && !task.isInProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Panel dikunci oleh ${task.lockedByName ?? "Divisi lain"}. Tidak dapat memulai pekerjaan.',
          ),
          backgroundColor: AppColors.statusLocked.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final drafts = _extractDrafts(context.read<TaskBloc>().state);
    final existingDraft = drafts[task.plandailyId];
    final shouldOpenFinishSheet = task.isInProgress || existingDraft != null;

    if (shouldOpenFinishSheet) {
      TaskExecutionSheet.show(
        context: context,
        task: task,
        draft: existingDraft,
        onSubmit: (executionLog) {
          context.read<TaskBloc>().add(
            SubmitExecutionEvent(executionLog: executionLog),
          );
        },
        onDraftSave: (draft) {
          context.read<TaskBloc>().add(SaveDraftEvent(draft: draft));
        },
      );
    } else {
      TaskStartSheet.show(
        context: context,
        task: task,
        onStart: (draft) {
          context.read<TaskBloc>().add(
            StartTaskFlowEvent(plandailyId: task.plandailyId, draft: draft),
          );
        },
      );
    }
  }

  void _showTaskDetailSheet(BuildContext context, TaskEntity task) {
    final target = task.dailyTargetHours > 0
        ? task.dailyTargetHours
        : task.targetHoursRevised;

    String _fmtTime(String? iso) {
      if (iso == null || iso.isEmpty) return '--:--';
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '--:--';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    String _formatDuration(double hours) {
      final totalMinutes = (hours * 60).round();
      if (totalMinutes <= 0) return '0j 0m';
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      if (h > 0 && m > 0) return '${h}j ${m}m';
      if (h > 0) return '${h}j';
      return '${m}m';
    }

    double actualHours = task.totalActualHours;
    if (task.isInProgress && task.startedAt != null) {
      final start = DateTime.tryParse(task.startedAt!);
      if (start != null) {
        final now = DateTime.now();
        actualHours += now.difference(start).inSeconds / 3600.0;
      }
    }

    TaskExecutionDetailSheet.show(
      context: context,
      title: 'Detail Pengerjaan',
      unitName: task.unitName,
      panelName: task.panelName,
      jobName: task.jobName,
      description: task.customDescription,
      divisionName: task.divisionName,
      taskDate: task.taskDate,
      planStartTime: task.startTime,
      planFinishTime: task.targetFinishTime,
      planDuration: _formatDuration(task.dailyTargetHours),
      actualStartTime: _fmtTime(task.startedAt),
      actualFinishTime: _fmtTime(task.completedAt),
      actualDuration: _formatDuration(actualHours),
      progress: task.progressPercent,
      status: task.status,
      category: task.taskCategory,
      operatorName: task.ownerName,
      isOvertime: task.isOvertime,
      isRework: task.isRework,
      isPriority: task.isPriority,
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13, color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
