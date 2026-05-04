library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../widgets/warehouse_request_sheet.dart';

class ActiveJobPicker extends StatefulWidget {
  const ActiveJobPicker._();

  static Future<WarehouseJobContext?> show(BuildContext context) =>
      showModalBottomSheet<WarehouseJobContext>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ActiveJobPicker._(),
      );

  @override
  State<ActiveJobPicker> createState() => _ActiveJobPickerState();
}

class _ActiveJobPickerState extends State<ActiveJobPicker> {
  static final _df = DateFormat('d MMM yyyy', 'id_ID');

  DateTime _selectedDate = DateTime.now();
  bool _overtimeOnly = false;
  bool _isLoading = true;
  String? _error;
  List<_TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final session = sl<SessionManager>();
      final client = sl<ApiClient>();
      final userId = session.userId ?? session.employeeId ?? '';
      final dateStr = _fmt(_selectedDate);

      final params = <String, dynamic>{'userId': userId, 'date': dateStr};
      if (_overtimeOnly) {
        params['isOvertime'] = 1;
      }

      final res = await client.get(ApiEndpoints.tasks, queryParameters: params);

      final raw = res.data;
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        final inner = raw['data'];
        if (inner is List) {
          items = inner;
        } else if (inner is Map) {
          items = (inner['data'] as List?) ?? [];
        }
      }

      final tasks = items
          .whereType<Map<String, dynamic>>()
          .map(_TaskItem.fromJson)
          .where((t) => t.carId.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _isLoading = false;
        });
      }
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _isTomorrow => _selectedDate.difference(_today()).inDays == 1;
  bool get _isToday => _selectedDate.difference(_today()).inDays == 0;
  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _shift(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _load();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // ── Handle ──────────────────────────────────────────
              Center(
                  child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),

              // ── Header ──────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Icon(Icons.link_rounded, color: AppColors.gold, size: 20),
                  SizedBox(width: 8),
                  Text('Pilih Pekerjaan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Date + Overtime controls ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  // Prev day
                  _iconBtn(Icons.chevron_left_rounded, () => _shift(-1)),
                  const SizedBox(width: 6),
                  // Date chip
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Text(_dateLabel(),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Next day
                  _iconBtn(Icons.chevron_right_rounded, () => _shift(1)),
                  const Spacer(),
                  // Overtime toggle
                  GestureDetector(
                    onTap: () {
                      setState(() => _overtimeOnly = !_overtimeOnly);
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _overtimeOnly
                            ? AppColors.statusInProgress.withValues(alpha: 0.12)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _overtimeOnly
                                ? AppColors.statusInProgress
                                : AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.nightlight_round,
                            size: 13,
                            color: _overtimeOnly
                                ? AppColors.statusInProgress
                                : AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text('Lembur',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _overtimeOnly
                                    ? AppColors.statusInProgress
                                    : AppColors.textMuted)),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Task list ────────────────────────────────────────
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.gold, strokeWidth: 2.5)),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text('Gagal memuat: $_error',
                      style: const TextStyle(
                          color: AppColors.statusLocked, fontSize: 12)),
                )
              else if (_tasks.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  child: Column(children: [
                    const Icon(Icons.inbox_outlined,
                        size: 36, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      _overtimeOnly
                          ? 'Tidak ada task lembur untuk ${_dateLabel()}.'
                          : 'Tidak ada pekerjaan untuk ${_dateLabel()}.',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Anda tetap bisa lanjut tanpa memilih pekerjaan.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TaskTile(
                      task: _tasks[i],
                      isOvertime: _overtimeOnly,
                      onTap: () => Navigator.of(context).pop(
                          _tasks[i].toJobContext(targetDate: _selectedDate)),
                    ),
                  ),
                ),

              // ── Skip ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.do_not_disturb_alt_outlined, size: 15),
                  label: const Text('Lanjut tanpa memilih pekerjaan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── helpers ────────────────────────────────────────────────
  String _dateLabel() {
    if (_isToday) return 'Hari ini';
    if (_isTomorrow) return 'Besok';
    final yesterday = _today().subtract(const Duration(days: 1));
    if (_selectedDate == yesterday) return 'Kemarin';
    return _df.format(_selectedDate);
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border)),
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.surfaceCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }
}

// ── Tile ──────────────────────────────────────────────────────────
class _TaskTile extends StatelessWidget {
  const _TaskTile(
      {required this.task, required this.isOvertime, required this.onTap});
  final _TaskItem task;
  final bool isOvertime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (isOvertime ? AppColors.statusInProgress : AppColors.gold)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isOvertime
                    ? Icons.nightlight_round
                    : Icons.directions_car_outlined,
                size: 18,
                color: isOvertime ? AppColors.statusInProgress : AppColors.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.unitName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${task.panelName}  ·  ${task.jobName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (task.status.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(task.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_statusLabel(task.status),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(task.status))),
                  ),
                ],
              ],
            )),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
      );

  Color _statusColor(String s) {
    switch (s) {
      case 'PROSES':
      case 'ON_PROGRESS':
        return AppColors.statusInProgress;
      case 'DONE':
      case 'READY_QC':
        return AppColors.statusDone;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'PROSES':
      case 'ON_PROGRESS':
        return 'ON PROGRESS';
      case 'PLAN':
      case 'ASSIGNED':
        return 'PLANNED';
      case 'DONE':
        return 'SELESAI';
      default:
        return s;
    }
  }
}

// ── Data class ────────────────────────────────────────────────────
class _TaskItem {
  const _TaskItem({
    required this.planDailyId,
    required this.coreId,
    required this.carId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    required this.status,
    this.deadlineDate,
  });

  final String planDailyId;
  final String coreId;
  final String carId;
  final String unitName;
  final String panelName;
  final String jobName;
  final String status;
  final DateTime? deadlineDate;

  factory _TaskItem.fromJson(Map<String, dynamic> j) {
    String coreId = _s(j['coreId']) ?? _s(j['core_id']) ?? '';
    String carId = _s(j['carId']) ?? _s(j['car_id']) ?? '';
    String unitName = '';
    String panel = '';
    String job = '';

    // Nested format (ViewTaskModel)
    if (j['unit'] is Map) {
      final u = j['unit'] as Map;
      carId = _s(u['unitId']) ?? _s(u['unit_id']) ?? carId;
      unitName = _s(u['unitName']) ?? _s(u['unit_name']) ?? '';
    }
    if (j['task'] is Map) {
      final t = j['task'] as Map;
      panel = _s(t['namaPanel']) ?? _s(t['panel_name']) ?? '';
      job = _s(t['jobName']) ?? _s(t['job_name']) ?? '';
      // coreId mungkin ada di level task
      if (coreId.isEmpty) coreId = _s(t['coreId']) ?? _s(t['core_id']) ?? '';
    }

    // Flat format fallback
    if (carId.isEmpty) {
      carId = _s(j['car_id']) ?? '';
    }
    if (unitName.isEmpty) {
      unitName = _s(j['unit_name']) ?? _s(j['unitName']) ?? '';
    }
    if (panel.isEmpty) {
      panel = _s(j['panel_name']) ?? _s(j['namaPanel']) ?? '';
    }
    if (job.isEmpty) {
      job =
          _s(j['job_name']) ?? _s(j['jobName']) ?? _s(j['task_category']) ?? '';
    }
    // coreId fallback ke planDailyId jika tidak ada
    if (coreId.isEmpty) {
      coreId = _s(j['planDailyId']) ?? _s(j['plandaily_id']) ?? '';
    }

    // Deadline dari target_finish_time atau deadline_date
    DateTime? deadline;
    final raw = j['task'] is Map
        ? (j['task'] as Map)['targetFinishTime']
        : j['deadline_date'];
    if (raw != null) {
      deadline = DateTime.tryParse('$raw');
    }

    return _TaskItem(
      planDailyId: _s(j['planDailyId']) ?? _s(j['plandaily_id']) ?? '',
      coreId: coreId,
      carId: carId,
      unitName: unitName,
      panelName: panel,
      jobName: job,
      status: (_s(j['status']) ?? 'PLAN').toUpperCase(),
      deadlineDate: deadline,
    );
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  WarehouseJobContext toJobContext({DateTime? targetDate}) =>
      WarehouseJobContext(
        carId: carId,
        coreId: coreId,
        unitName: unitName,
        panelName: panelName,
        jobName: jobName,
        targetSearchDate: targetDate,
        deadlineDate: deadlineDate,
      );
}
