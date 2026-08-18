/*
Tujuan: Halaman job plan untuk approval queue, creator draft/plan, dan alokasi jam kerja harian.
Caller: Route /plans, dashboard management, dan task section plan.
Dependensi: RBAC, SessionManager, JobPlanRepository, WorkOrderRepository, CountdownRepository, JobPlanAllocationHelper, DateFilterBar.
Main Functions: _loadPlans, _save, _showCreateSourceSheet, _showAdditionalTaskDialog, BrowseTab.
Side Effects: HTTP GET/POST/PUT job plan, navigasi ke source route, refresh approval dan browse state.
*/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sm_system/core/constants/app_colors.dart';
import 'package:sm_system/core/di/injection.dart';
import 'package:sm_system/core/errors/error_message.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/task_execution/presentation/widgets/date_filter_bar.dart';
import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';

import 'package:sm_system/features/work_order/domain/repositories/work_order_repository.dart';
import 'package:sm_system/features/work_order/domain/entities/work_order.dart';

import 'package:sm_system/core/widgets/clock_time_input.dart';
import 'package:sm_system/core/widgets/duration_input.dart';
import 'package:sm_system/core/utils/time_parser.dart';
import 'package:sm_system/features/countdown/domain/entities/countdown_entities.dart';
import 'package:sm_system/features/countdown/domain/repositories/countdown_repository.dart';
import 'package:sm_system/features/countdown/presentation/utils/countdown_helper.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_allocation_helper.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_additional_draft_helper.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_job_type_helper.dart';
import 'package:sm_system/features/task_execution/presentation/utils/task_execution_helper.dart';
import 'package:sm_system/core/utils/snackbar_helper.dart';

bool _hasMeaningfulJobPlanText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isNotEmpty && text.toLowerCase() != 'null' && text != '-';
}

String _pickJobPlanText(Iterable<Object?> values, [String fallback = '']) {
  for (final value in values) {
    if (_hasMeaningfulJobPlanText(value)) {
      return value!.toString().trim();
    }
  }
  return fallback;
}

String? _pickNullableJobPlanText(Iterable<Object?> values) {
  final value = _pickJobPlanText(values);
  return value.isEmpty ? null : value;
}

bool _canReviewApprovalStatus(SessionManager session, String status) {
  final s = status.toUpperCase();
  // Hanya status PENDING yang masuk antrean review
  if (!s.startsWith('PENDING')) return false;

  if (session.isGlobalAccess || session.isKpAccess) {
    return true;
  }
  if (session.isAdvisorAccess) {
    return s == 'PENDING_ADV';
  }
  return false;
}

String _formatHours(double hours) {
  if (hours <= 0) return '-';
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (h > 0 && m > 0) return '${h}j ${m}m';
  if (h > 0) return '${h}j';
  return '${m}m';
}

String _formatHoursClock(
  double hours, {
  bool zeroAsClock = false,
  bool isTriple = false,
}) {
  if (hours <= 0) {
    return zeroAsClock ? (isTriple ? '000:00' : '00:00') : '-';
  }
  final formatted = TimeParser.formatDecimalToHHmm(hours, isTriple: isTriple);
  if (formatted.isEmpty) {
    return zeroAsClock ? (isTriple ? '000:00' : '00:00') : '-';
  }
  return formatted;
}

class TotalProjectHoursFormatter extends TextInputFormatter {
  static final RegExp _pattern = RegExp(r'^\d{0,3}(:\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (!_pattern.hasMatch(text)) return oldValue;
    if (text.length == 3 &&
        !text.contains(':') &&
        newValue.selection.end == 3) {
      text = '$text:';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return newValue;
  }
}

int _minutesOfDayTop(TimeOfDay t) => t.hour * 60 + t.minute;

Future<({double usedNormal, double usedOt, TimeOfDay latestFinish})>
_employeeDayLoadFor({
  required JobPlanRepository repository,
  required SessionManager session,
  required DateTime taskDate,
  required String employeeId,
  String? excludeDraftItemId,
}) async {
  var usedNormal = 0.0;
  var usedOt = 0.0;
  var latestFinish = TimeOfDay(hour: 8, minute: 0);
  try {
    final dateStr =
        '${taskDate.year}-${taskDate.month.toString().padLeft(2, '0')}-${taskDate.day.toString().padLeft(2, '0')}';
    final plans = await repository.getPlans();
    for (final p in plans.whereType<Map<String, dynamic>>()) {
      if ('${p['assignedUserId'] ?? ''}' != employeeId) continue;
      if ('${p['workDate'] ?? ''}' != dateStr) continue;
      final status = '${p['status'] ?? ''}'.toUpperCase();
      if (status == 'REJECTED' || status == 'CANCEL' || status == 'READY_QC') {
        continue;
      }
      final hours = (p['targetHours'] as num?)?.toDouble() ?? 0.0;
      if (p['isOvertime'] == true || p['isOvertime'] == 1) {
        usedOt += hours;
      } else {
        usedNormal += hours;
      }
      final end = TimeParser.parseTimeOfDay('${p['finishTime'] ?? ''}');
      if (end != null &&
          _minutesOfDayTop(end) > _minutesOfDayTop(latestFinish)) {
        latestFinish = end;
      }
    }

    final draft = await repository.getDraft(userId: session.employeeId ?? '');
    for (final item
        in (draft?['items'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()) {
      if (excludeDraftItemId != null &&
          '${item['draftItemId'] ?? ''}' == excludeDraftItemId) {
        continue;
      }
      if ('${item['assignedUserId'] ?? ''}' != employeeId) continue;
      if ('${item['taskDate'] ?? ''}' != dateStr) continue;
      final hours = (item['targetHours'] as num?)?.toDouble() ?? 0.0;
      if (item['isOvertime'] == true || item['isOvertime'] == 1) {
        usedOt += hours;
      } else {
        usedNormal += hours;
      }
      final end = TimeParser.parseTimeOfDay('${item['finishTime'] ?? ''}');
      if (end != null &&
          _minutesOfDayTop(end) > _minutesOfDayTop(latestFinish)) {
        latestFinish = end;
      }
    }
  } catch (_) {}
  return (usedNormal: usedNormal, usedOt: usedOt, latestFinish: latestFinish);
}

List<Map<String, dynamic>> normalizeSequentialDraftItems(
  List<Map<String, dynamic>> items,
) {
  final normalized = items.map(Map<String, dynamic>.from).toList();
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final item in normalized) {
    final key = '${item['assignedUserId'] ?? ''}|${item['taskDate'] ?? ''}';
    groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
  }

  for (final group in groups.values) {
    group.sort((a, b) {
      final at =
          TimeParser.parseTimeOfDay('${a['startTime'] ?? ''}') ??
          TimeOfDay(hour: 0, minute: 0);
      final bt =
          TimeParser.parseTimeOfDay('${b['startTime'] ?? ''}') ??
          TimeOfDay(hour: 0, minute: 0);
      return _minutesOfDayTop(at).compareTo(_minutesOfDayTop(bt));
    });

    TimeOfDay? previousFinish;
    for (final item in group) {
      var start =
          TimeParser.parseTimeOfDay('${item['startTime'] ?? ''}') ??
          TimeOfDay(hour: 8, minute: 0);
      if (previousFinish != null &&
          _minutesOfDayTop(start) < _minutesOfDayTop(previousFinish)) {
        start = previousFinish;
        item['startTime'] = CountdownHelper.formatTime(start);
      }
      final hours = (item['targetHours'] as num?)?.toDouble() ?? 0.0;
      final date =
          DateTime.tryParse('${item['taskDate'] ?? ''}') ?? DateTime.now();
      final finish = CountdownHelper.calculateFinishTime(
        startTime: start,
        durationHours: hours,
        date: date,
      );
      item['finishTime'] = CountdownHelper.formatTime(finish);
      item['isOvertime'] = CountdownHelper.isOvertimeByTime(finish, date: date);
      previousFinish = finish;
    }
  }
  return normalized;
}

TimeOfDay _calculateFinishTime({
  required TimeOfDay startTime,
  required double durationHours,
  DateTime? date,
}) {
  return CountdownHelper.calculateFinishTime(
    startTime: startTime,
    durationHours: durationHours,
    date: date,
  );
}

// ── Search pickers ────────────────────────────────────────────────────────────

Future<Map<String, dynamic>?> jobPlanMasterSearchPicker(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> items,
  required String Function(Map<String, dynamic>) labelBuilder,
  String Function(Map<String, dynamic>)? subtitleBuilder,
}) async {
  String query = '';
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) {
        final filtered = items.where((i) {
          final lbl = labelBuilder(i).toLowerCase();
          final sub = subtitleBuilder?.call(i).toLowerCase() ?? '';
          final q = query.toLowerCase();
          return lbl.contains(q) || sub.contains(q);
        }).toList();

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => ss(() => query = v),
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada hasil',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: AppColors.border),
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                labelBuilder(item),
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: subtitleBuilder != null
                                  ? Text(
                                      subtitleBuilder(item),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    )
                                  : null,
                              onTap: () => Navigator.pop(ctx, item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<Set<Map<String, dynamic>>?> jobPlanMultiMasterSearchPicker(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> items,
  required Set<String> initialSelectionIds,
  required String Function(Map<String, dynamic>) labelBuilder,
  String Function(Map<String, dynamic>)? subtitleBuilder,
}) async {
  final selected = List<Map<String, dynamic>>.from(
    items.where((i) => initialSelectionIds.contains(i['id'].toString())),
  );
  var query = '';

  return showModalBottomSheet<Set<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) {
        final filtered = items.where((i) {
          final lbl = labelBuilder(i).toLowerCase();
          final sub = subtitleBuilder?.call(i).toLowerCase() ?? '';
          return lbl.contains(query.toLowerCase()) ||
              sub.contains(query.toLowerCase());
        }).toList();

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: Column(
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (selected.isNotEmpty)
                        Text(
                          '${selected.length} dipilih',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => ss(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari pengerjaan...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final isSelected = selected.any(
                        (s) => s['id'].toString() == item['id'].toString(),
                      );
                      return CheckboxListTile.adaptive(
                        value: isSelected,
                        activeColor: AppColors.gold,
                        title: Text(
                          labelBuilder(item),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: subtitleBuilder != null
                            ? Text(
                                subtitleBuilder(item),
                                style: TextStyle(fontSize: 12),
                              )
                            : null,
                        onChanged: (val) {
                          ss(() {
                            if (val == true) {
                              selected.add(item);
                            } else {
                              selected.removeWhere(
                                (s) =>
                                    s['id'].toString() == item['id'].toString(),
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected.toSet()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                      child: Text(
                        'PILIH PEKERJAAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<Map<String, dynamic>?> jobPlanEmployeePicker(
  BuildContext context,
  List<Map<String, dynamic>> employees,
) async {
  return jobPlanMasterSearchPicker(
    context,
    title: 'Pilih Pelaksana / Anggota',
    items: employees,
    labelBuilder: (m) => (m['full_name'] ?? m['name'] ?? '-').toString(),
    subtitleBuilder: (m) => [
      if (m['employee_id'] != null) m['employee_id'],
      if (m['grade'] != null) 'Grade ${m['grade']}',
    ].join(' • '),
  );
}

Future<Set<String>?> jobPlanMultiJobPicker(
  BuildContext context, {
  required String title,
  required List<String> items,
  required Set<String> initialSelection,
}) async {
  final selected = Set<String>.from(initialSelection);
  var query = '';
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final normalizedQuery = query.toLowerCase();
        final filteredItems = items
            .where((item) => item.toLowerCase().contains(normalizedQuery))
            .toList();
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: InputDecoration(
                      labelText: 'Cari job',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount:
                          filteredItems.length +
                          (query.trim().isNotEmpty &&
                                  !items.any(
                                    (e) =>
                                        e.toLowerCase() ==
                                        query.trim().toLowerCase(),
                                  )
                              ? 1
                              : 0),
                      separatorBuilder: (_, __) =>
                          Divider(color: AppColors.border),
                      itemBuilder: (_, index) {
                        final showManual =
                            query.trim().isNotEmpty &&
                            !items.any(
                              (e) =>
                                  e.toLowerCase() == query.trim().toLowerCase(),
                            );
                        if (showManual && index == filteredItems.length) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.add_circle_outline,
                              color: AppColors.gold,
                            ),
                            title: Text(
                              'Gunakan "${query.trim()}"',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () {
                              setSheetState(() => selected.add(query.trim()));
                            },
                          );
                        }
                        final item = filteredItems[index];
                        final isSelected = selected.contains(item);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          value: isSelected,
                          activeColor: AppColors.gold,
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selected.add(item);
                              } else {
                                selected.remove(item);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                      child: Text(
                        'PILIH PEKERJAAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────

class JobPlanPage extends StatefulWidget {
  final String? focusPlanId;
  final DateTime? initialDate;
  final String? initialSourceType;
  final String? initialSourceRefId;
  final bool autoOpenCreate;

  const JobPlanPage({
    super.key,
    this.focusPlanId,
    this.initialDate,
    this.initialSourceType,
    this.initialSourceRefId,
    this.autoOpenCreate = false,
  });

  @override
  State<JobPlanPage> createState() => _JobPlanPageState();
}

class _JobPlanPageState extends State<JobPlanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final JobPlanRepository _repository;
  late final SessionManager _session;

  // Notifier untuk trigger refresh di child tabs
  final ValueNotifier<int> _refreshNotifier = ValueNotifier(0);

  void _triggerRefresh() {
    if (mounted) _refreshNotifier.value++;
  }

  // Browse state
  DateTime _browseDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
    // Rencana tab hanya untuk KD; ADV/KP/MP hanya Approval
    final isKd = _session.isKdAccess;
    _tabController = TabController(length: isKd ? 2 : 1, vsync: this);
    if (widget.initialDate != null) {
      _browseDate = widget.initialDate!;
    }

    if (widget.autoOpenCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateSourceSheet();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<void> _showApprovalPlanDetail(JobPlan plan) async {
    final raw = _findApprovalPlanRaw(plan.planId) ?? <String, dynamic>{};
    final detailUnit = _pickJobPlanText([plan.unitName, raw['unit_name']], '-');
    final detailPanel = _pickJobPlanText([
      plan.panelName,
      raw['panelSectionName'],
      raw['panelSection'],
    ], '-');
    final detailDivision = _pickJobPlanText([
      plan.assignedDivision,
      raw['divisionName'],
      raw['division_id'],
    ], '-');
    final detailDescription = _pickJobPlanText([
      plan.description,
      raw['jobdescription'],
      raw['description'],
    ], '-');
    final detailNote = _pickJobPlanText([
      plan.note,
      raw['catatan'],
      raw['pok'],
    ]);
    final targetHoursLabel =
        _pickNullableJobPlanText([
          raw['targetHours_alias'],
          raw['targetHoursAlias'],
          plan.targetHoursAlias,
        ]) ??
        _formatHours(plan.targetHours);
    final remainingHoursLabel = _pickNullableJobPlanText([
      raw['remainingHours_alias'],
      raw['remainingHoursAlias'],
      plan.remainingHoursAlias,
    ]);
    final sourceRefId = _pickNullableJobPlanText([plan.sourceRefId]);
    final panelSection = _pickNullableJobPlanText([
      raw['panelSectionName'],
      raw['panelSection'],
      plan.panelCustomNote,
    ]);

    final canReview = _canReviewApprovalStatus(_session, plan.status);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isActing = false;

        return StatefulBuilder(
          builder: (ctx, setLocalState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Detail Approval Plan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Status + meta chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ApprovalMetaChip(
                          icon: Icons.flag_rounded,
                          label: _statusLabel(plan.status),
                        ),
                        _ApprovalMetaChip(
                          icon: Icons.category_rounded,
                          label: _sourceTypeLabel(plan.sourceType),
                        ),
                        _ApprovalMetaChip(
                          icon: plan.isOvertime
                              ? Icons.nights_stay_rounded
                              : Icons.sunny,
                          label: plan.isOvertime ? 'LEMBUR' : 'NORMAL',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Fields
                    _ApprovalDetailField(
                      label: 'Pelaksana',
                      value: _pickJobPlanText([plan.assignedTo], '-'),
                    ),
                    _ApprovalDetailField(label: 'Unit', value: detailUnit),
                    _ApprovalDetailField(label: 'Panel', value: detailPanel),
                    if (panelSection != null)
                      _ApprovalDetailField(
                        label: 'Section',
                        value: panelSection,
                      ),
                    _ApprovalDetailField(
                      label: 'Divisi',
                      value: detailDivision,
                    ),
                    _ApprovalDetailField(
                      label: 'Tanggal Kerja',
                      value: _pickJobPlanText([plan.workDate], '-'),
                    ),
                    _ApprovalDetailField(
                      label: 'Jam Kerja',
                      value:
                          '${_pickJobPlanText([plan.startTime], '-')} - ${_pickJobPlanText([plan.finishTime], '-')}',
                    ),
                    _ApprovalDetailField(
                      label: 'Target Jam',
                      value: targetHoursLabel,
                    ),
                    if (remainingHoursLabel != null)
                      _ApprovalDetailField(
                        label: 'Sisa Countdown',
                        value: remainingHoursLabel,
                      ),
                    _ApprovalDetailField(
                      label: 'Jobdesc',
                      value: detailDescription,
                    ),
                    if (detailNote.isNotEmpty)
                      _ApprovalDetailField(
                        label: 'Instruksi / SPOK',
                        value: detailNote,
                      ),
                    if (sourceRefId != null)
                      _ApprovalDetailField(
                        label: 'Source Ref',
                        value: sourceRefId,
                      ),

                    // ── Action buttons (hanya jika role bisa review) ──
                    if (canReview) ...[
                      SizedBox(height: 24),
                      Divider(color: AppColors.border),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          // Tolak
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isActing
                                  ? null
                                  : () async {
                                      final note = await showDialog<String>(
                                        context: ctx,
                                        builder: (dCtx) {
                                          final ctrl = TextEditingController();
                                          return AlertDialog(
                                            backgroundColor:
                                                AppColors.surfaceCard,
                                            title: Text(
                                              'Alasan Penolakan',
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                              ),
                                            ),
                                            content: TextField(
                                              controller: ctrl,
                                              maxLines: 3,
                                              style: TextStyle(
                                                color: AppColors.textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Tulis alasan...',
                                                hintStyle: TextStyle(
                                                  color: AppColors.textMuted,
                                                ),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: AppColors.border,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: AppColors.gold,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dCtx),
                                                child: Text('Batal'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  dCtx,
                                                  ctrl.text.trim(),
                                                ),
                                                child: Text(
                                                  'Tolak',
                                                  style: TextStyle(
                                                    color: Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (note == null || note.isEmpty) return;
                                      setLocalState(() => isActing = true);
                                      try {
                                        await _repository.rejectPlan(
                                          planId: plan.planId,
                                          userId: _session.employeeId ?? '',
                                          rejectNote: note,
                                        );
                                        _triggerRefresh();
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Plan ditolak.'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      } catch (_) {
                                        if (ctx.mounted) {
                                          setLocalState(() => isActing = false);
                                        }
                                      }
                                    },
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: Text(
                                'Tolak',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.redAccent),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          // Setujui
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isActing
                                  ? null
                                  : () async {
                                      setLocalState(() => isActing = true);
                                      try {
                                        await _repository.approvePlan(
                                          planId: plan.planId,
                                          userId: _session.employeeId ?? '',
                                        );
                                        _triggerRefresh();
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Plan disetujui ✓'),
                                              backgroundColor: Color(
                                                0xFF2E7D32,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (_) {
                                        if (ctx.mounted) {
                                          setLocalState(() => isActing = false);
                                        }
                                      }
                                    },
                              icon: isActing
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(Icons.check_rounded, size: 18),
                              label: Text('Setujui'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _findApprovalPlanRaw(String planId) {
    // Find in repository cache or fresh? For mock:
    return null;
  }

  String _statusLabel(String status) {
    return switch (status.toUpperCase()) {
      'PENDING_ADV' => 'Menunggu QA',
      'PENDING_KP' => 'Menunggu KP',
      'PENDING_MP' => 'Menunggu MP',
      'PLAN' => 'Disetujui',
      'ONPROGRESS' || 'ON_PROGRESS' => 'Dikerjakan',
      'PENDING' => 'Pending Pengerjaan',
      'READY_QC' => 'Siap QC',
      'DONE' => 'Selesai',
      'APPROVED' => 'Disetujui',
      'REJECTED' => 'Ditolak',
      _ => status,
    };
  }

  String _sourceTypeLabel(String sourceType) {
    final s = sourceType.toUpperCase();
    if (s.contains('URGENT')) return 'Urgent';
    if (s.contains('ADDITIONAL')) return 'Tambahan';
    if (s == 'WO') return 'Work Order';
    if (s == 'COUNTDOWN') return 'Countdown';
    return sourceType;
  }

  void _showCreateSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Buat Rencana Kerja Dari:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.timer_outlined, color: AppColors.gold),
              title: Text('Countdown List'),
              subtitle: Text('Gunakan sisa jam dari project car aktif'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _CountdownPlanFormPage(initialDate: _browseDate),
                  ),
                );
                if (res == true) _triggerRefresh();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.gold,
              ),
              title: Text('Work Order / WOV'),
              subtitle: Text('Tarik dari WO internal atau vendor'),
              onTap: () {
                Navigator.pop(ctx);
                _showWoSourcePicker();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.add_task_rounded,
                color: AppColors.gold,
              ),
              title: Text('Additional Task'),
              subtitle: Text('Input pekerjaan manual atau urgent'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await _showAdditionalTaskDialog();
                if (res == true) _triggerRefresh();
              },
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showWoSourcePicker() async {
    final woRepo = sl<WorkOrderRepository>();
    final result = await woRepo.getWorkOrders(view: 'ACTIVE');

    result.fold<void>(
      (failure) => AppNotification.showError(
        context,
        failure.message ?? 'Mohon maaf, terjadi kendala. Silakan coba lagi.',
      ),
      (orders) {
        // Filter those already hasCountdownLink?
        // Actually, JobPlan BE will handle duplication.
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => _WoSourcePicker(
            orders: orders,
            onSelect: (wo) async {
              Navigator.pop(ctx);
              final res = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _SourcePlanFormPage(
                    seed: _PlanSourceSeed(
                      sourceLabel: 'WO',
                      sourceType: 'WO',
                      sourceRefId: wo.id,
                      sourceRoute: '/work-orders?woId=${wo.id}',
                      unitName: wo.unitName,
                      carId: wo.carId,
                      panelName: wo.panelName ?? '-',
                      assignedDivision: wo.toDivName,
                      description: wo.jobDetail,
                      targetHours: wo.estimatedHours ?? 0.0,
                    ),
                    initialDate: _browseDate,
                  ),
                ),
              );
              if (res == true) _triggerRefresh();
            },
          ),
        );
      },
    );
  }

  Future<bool?> _showAdditionalTaskDialog() {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdditionalPlanFormPage(initialDate: _browseDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKd = _session.isKdAccess;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Job Plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.gold,
          tabs: [
            Tab(text: 'Approval Plan'),
            if (isKd) Tab(text: 'Rencana'),
          ],
        ),
        actions: [],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ApprovalTab(
            onPlanTap: _showApprovalPlanDetail,
            refreshNotifier: _refreshNotifier,
            initialDate: _browseDate,
            onRefresh: _triggerRefresh,
          ),
          if (isKd)
            _BrowseTab(
              initialDate: _browseDate,
              refreshNotifier: _refreshNotifier,
              onRefresh: _triggerRefresh,
              onParamsChanged: (date, divId, carId) {
                setState(() {
                  _browseDate = date;
                });
              },
            ),
        ],
      ),
      // FAB untuk KD membuat plan (bila tidak di tab Rencana, tetap bisa akses)
      floatingActionButton: !isKd
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.gold,
              onPressed: _showCreateSourceSheet,
              child: Icon(Icons.add_rounded, color: Colors.black),
            ),
    );
  }
}

// ── Countdown Form ────────────────────────────────────────────────────────────

class _CountdownPlanFormPage extends StatefulWidget {
  const _CountdownPlanFormPage({
    required this.initialDate,
    this.initialDraft,
    this.editIndex,
  });

  final DateTime initialDate;
  final Map<String, dynamic>? initialDraft;
  final int? editIndex;

  @override
  State<_CountdownPlanFormPage> createState() => _CountdownPlanFormPageState();
}

class _CountdownPlanFormPageState extends State<_CountdownPlanFormPage> {
  late final JobPlanRepository _repository;
  late final CountdownRepository _countdownRepo;
  late final SessionManager _session;

  bool _isLoading = true;
  bool _isSaving = false;

  List<CountdownUnit> _units = [];
  List<CountdownSection> _panels = [];
  List<CountdownJobdesc> _jobdescs = [];
  List<Map<String, dynamic>> _employees = [];

  CountdownUnit? _selectedUnit;
  CountdownSection? _selectedPanel;
  final Set<CountdownJobdesc> _selectedJobs = {};
  Map<String, dynamic>? _selectedEmployee;

  late DateTime _selectedDate;
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = TimeOfDay(hour: 16, minute: 0);
  final TextEditingController _hoursCtrl = TextEditingController(text: '08:00');
  final TextEditingController _instructionCtrl = TextEditingController();
  bool _finishTimeEdited = false;
  bool _isOvertime = false;

  String _panelSectionLabel(CountdownSection panel) {
    final name = panel.sectionName.trim();
    final section = panel.section.trim();
    if (section.isNotEmpty &&
        section != '-' &&
        section.toLowerCase() != name.toLowerCase()) {
      return '$name • $section';
    }
    return name;
  }

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _countdownRepo = sl<CountdownRepository>();
    _session = sl<SessionManager>();
    _selectedDate = widget.initialDate;
    _initData();
  }

  Future<void> _initData() async {
    try {
      final units = await _countdownRepo.getUnits(
        role: _session.accessBucket ?? _session.role,
        division: _session.divisionName,
      );
      if (!mounted) return;
      if (widget.initialDraft != null) {
        await _hydrateDraft(widget.initialDraft!, units);
      } else {
        setState(() {
          _units = units;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<void> _hydrateDraft(
    Map<String, dynamic> draft,
    List<CountdownUnit> units,
  ) async {
    final carId = draft['carId']?.toString() ?? '';
    final unit = _firstWhereOrNull(units, (u) => u.carId == carId);
    if (unit == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final divisions = await _countdownRepo.getDivisions(unit.carId);
      final divisionId = int.tryParse('${draft['divisionId'] ?? ''}') ?? 0;
      final division =
          _firstWhereOrNull(divisions, (d) => d.divisionId == divisionId) ??
          (divisions.isNotEmpty ? divisions.first : null);
      if (division == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final panels = await _countdownRepo.getSections(
        carId: unit.carId,
        divisionId: division.divisionId,
        plannable: true,
      );
      final employees = await _repository.getDropdownUsers(
        divisionId: division.divisionId.toString(),
      );

      final coreId = draft['coreId']?.toString() ?? '';
      final panelName = (draft['panelName'] ?? '').toString().trim();
      CountdownSection? panel;
      CountdownJobdesc? job;

      for (final p in panels) {
        final jobs = await _countdownRepo.getJobdescs(
          carId: unit.carId,
          divisionId: division.divisionId,
          panelId: p.panelId,
          plannable: true,
        );
        final found = _firstWhereOrNull(jobs, (j) => j.id == coreId);
        if (found != null) {
          panel = p;
          job = found;
          break;
        }
      }

      if (job == null && panelName.isNotEmpty) {
        panel =
            _firstWhereOrNull(
              panels,
              (p) =>
                  p.sectionName.trim().toLowerCase() == panelName.toLowerCase(),
            ) ??
            panel;
      }

      final employeeId = draft['assignedUserId']?.toString() ?? '';
      final employee = _firstWhereOrNull(
        employees,
        (e) => '${e['id'] ?? ''}' == employeeId,
      );

      final start = TimeParser.parseTimeOfDay('${draft['startTime'] ?? ''}');
      final finish = TimeParser.parseTimeOfDay('${draft['finishTime'] ?? ''}');
      final hours =
          (draft['targetHours'] as num?)?.toDouble() ??
          TimeParser.parseHHmmToDecimal('${draft['targetHours'] ?? ''}') ??
          0.0;

      if (!mounted) return;
      setState(() {
        _units = units;
        _panels = panels;
        _employees = employees;
        _selectedUnit = unit;
        _selectedPanel = panel;
        _selectedJobs.clear();
        if (job != null) _selectedJobs.add(job);
        _selectedEmployee = employee;
        _selectedDate =
            DateTime.tryParse('${draft['taskDate'] ?? ''}') ?? _selectedDate;
        _hoursCtrl.text = TimeParser.formatDecimalToHHmm(
          hours,
          isTriple: false,
        );
        if (start != null) _startTime = start;
        if (finish != null) {
          _finishTime = finish;
          _finishTimeEdited = true;
        } else {
          _finishTime = _calculateFinishTime(
            startTime: _startTime,
            durationHours: hours,
            date: _selectedDate,
          );
          _finishTimeEdited = false;
        }
        _isOvertime = draft['isOvertime'] == true || draft['isOvertime'] == 1;
        _instructionCtrl.text = draft['note']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onUnitSelected(CountdownUnit unit) async {
    setState(() {
      _selectedUnit = unit;
      _selectedPanel = null;
      _selectedJobs.clear();
      _panels = [];
      _jobdescs = [];
      _isLoading = true;
    });

    try {
      final divisions = await _countdownRepo.getDivisions(unit.carId);
      final currentDivName = _session.divisionName?.toUpperCase() ?? '';

      final matchingDiv = divisions.firstWhere(
        (d) => d.divisionName.toUpperCase() == currentDivName,
        orElse: () => divisions.first,
      );

      final panels = await _countdownRepo.getSections(
        carId: unit.carId,
        divisionId: matchingDiv.divisionId,
        plannable: true,
      );
      final employees = await _repository.getDropdownUsers(
        divisionId: matchingDiv.divisionId.toString(),
      );

      if (!mounted) return;
      setState(() {
        _panels = panels.where((p) => p.totalRemainingHours > 0).toList();
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPanelSelected(CountdownSection panel) async {
    setState(() {
      _selectedPanel = panel;
      _selectedJobs.clear();
      _jobdescs = [];
      _isLoading = true;
    });

    try {
      final divisions = await _countdownRepo.getDivisions(_selectedUnit!.carId);
      final currentDivName = _session.divisionName?.toUpperCase() ?? '';
      final matchingDiv = divisions.firstWhere(
        (d) => d.divisionName.toUpperCase() == currentDivName,
        orElse: () => divisions.first,
      );

      final jobdescs = await _countdownRepo.getJobdescs(
        carId: _selectedUnit!.carId,
        divisionId: matchingDiv.divisionId,
        panelId: panel.panelId,
        plannable: true,
      );
      final activeJobsRaw = jobdescs.where((j) {
        final st = j.status.toUpperCase();
        final canPlan = st == 'PLAN' || st == 'PROSES';
        return canPlan && _hasUsableCountdownJobdesc(j);
      }).toList();

      final uniqueJobs = <String, CountdownJobdesc>{};
      for (final j in activeJobsRaw) {
        final key = j.jobdesc.trim().toLowerCase();
        // Hanya masukkan jika belum ada, untuk mencegah duplikasi (bug backend)
        if (!uniqueJobs.containsKey(key)) {
          uniqueJobs[key] = j;
        }
      }
      final activeJobs = uniqueJobs.values.toList();

      // Draft lokal hanya mengurangi kapasitas planning, bukan sisa aktual pekerjaan.
      final draftData = await sl<JobPlanRepository>().getDraft(
        userId: _session.employeeId ?? '',
      );
      if (draftData != null && draftData.containsKey('items')) {
        final items = draftData['items'] as List<dynamic>;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final coreId = item['coreId']?.toString();
            final hrs = (item['targetHours'] as num?)?.toDouble() ?? 0.0;
            if (coreId != null && hrs > 0) {
              final idx = activeJobs.indexWhere((j) => j.id == coreId);
              if (idx != -1) {
                final original = activeJobs[idx];
                final newAvailable = (_availablePlanHours(original) - hrs)
                    .clamp(0.0, double.infinity);
                activeJobs[idx] = CountdownJobdesc(
                  id: original.id,
                  carId: original.carId,
                  divisionId: original.divisionId,
                  panelName: original.panelName,
                  sectionName: original.sectionName,
                  jobdesc: original.jobdesc,
                  taskCategory: original.taskCategory,
                  progress: original.progress,
                  status: original.status,
                  targetHoursInitial: original.targetHoursInitial,
                  timeExtensionHours: original.timeExtensionHours,
                  targetHoursRevised: original.targetHoursRevised,
                  totalActualHours: original.totalActualHours,
                  remainingHours: original.remainingHours,
                  startDate: original.startDate,
                  deadlineDate: original.deadlineDate,
                  qcLastStatus: original.qcLastStatus,
                  qcValidationStatus: original.qcValidationStatus,
                  qcResultStatus: original.qcResultStatus,
                  qcEstimatedReworkHours: original.qcEstimatedReworkHours,
                  qcReworkDeadlineDate: original.qcReworkDeadlineDate,
                  qcAdvisorNotes: original.qcAdvisorNotes,
                  revisionRequestStatus: original.revisionRequestStatus,
                  requestedRevisionHours: original.requestedRevisionHours,
                  requestedRevisionDeadline: original.requestedRevisionDeadline,
                  requestedRevisionReason: original.requestedRevisionReason,
                  requestedRevisionByName: original.requestedRevisionByName,
                  requestedRevisionAt: original.requestedRevisionAt,
                  approvedRevisionHours: original.approvedRevisionHours,
                  approvedRevisionDeadline: original.approvedRevisionDeadline,
                  approvedRevisionByName: original.approvedRevisionByName,
                  approvedRevisionAt: original.approvedRevisionAt,
                  rejectedRevisionByName: original.rejectedRevisionByName,
                  rejectedRevisionAt: original.rejectedRevisionAt,
                  isLockedByOtherDivision: original.isLockedByOtherDivision,
                  targetHoursRevisedAlias: original.targetHoursRevisedAlias,
                  remainingHoursAlias: original.remainingHoursAlias,
                  availablePlanHours: newAvailable,
                  reservedPlanHours: original.reservedPlanHours + hrs,
                  availablePlanHoursAlias: null,
                  reservedPlanHoursAlias: null,
                );
              }
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _jobdescs = activeJobs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncFinishTime() {
    if (_finishTimeEdited) return;
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (targetHours != null && targetHours > 0) {
      setState(() {
        _finishTime = _calculateFinishTime(
          startTime: _startTime,
          durationHours: targetHours,
          date: _selectedDate,
        );
        _isOvertime = CountdownHelper.isOvertimeByTime(
          _finishTime,
          date: _selectedDate,
        );
      });
    }
  }

  double _availablePlanHours(CountdownJobdesc job) {
    final hasExplicitPlanCapacity =
        job.availablePlanHoursAlias != null || job.reservedPlanHours > 0;
    final raw = hasExplicitPlanCapacity
        ? job.availablePlanHours
        : job.remainingHours;
    return raw.clamp(0.0, double.infinity);
  }

  bool _hasUsableCountdownJobdesc(CountdownJobdesc job) {
    final text = job.jobdesc.trim();
    return text.isNotEmpty && text != '-' && _availablePlanHours(job) > 0;
  }

  String _availablePlanHoursLabel(CountdownJobdesc job) {
    final available = _availablePlanHours(job);
    final actual = job.remainingHours.clamp(0.0, double.infinity);
    return '${_formatHoursClock(available, zeroAsClock: true)} tersedia plan • ${_formatHoursClock(actual, zeroAsClock: true)} sisa kerja';
  }

  int _minutesOfDay(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<({double usedNormal, double usedOt, TimeOfDay latestFinish})>
  _employeeDayLoad(String employeeId, {String? excludeDraftItemId}) async {
    return _employeeDayLoadFor(
      repository: _repository,
      session: _session,
      taskDate: _selectedDate,
      employeeId: employeeId,
      excludeDraftItemId: excludeDraftItemId,
    );
  }

  Future<void> _applyEmployeeDayCap() async {
    final employeeId = _selectedEmployee?['id']?.toString() ?? '';
    if (employeeId.isEmpty) return;
    final load = await _employeeDayLoad(employeeId);
    if (!mounted) return;

    final eight = TimeOfDay(hour: 8, minute: 0);
    final startTime = _minutesOfDay(load.latestFinish) > _minutesOfDay(eight)
        ? load.latestFinish
        : _startTime;
    final requested = TimeParser.parseHHmmToDecimal(_hoursCtrl.text) ?? 0.0;
    final allowed = JobPlanAllocationHelper.allowedDayHours(
      usedNormal: load.usedNormal,
      usedOt: load.usedOt,
      isOvertime: _isOvertime,
      isSunday: _selectedDate.weekday == DateTime.sunday,
    );
    final capped = requested > allowed ? allowed : requested;
    final finishTime = _calculateFinishTime(
      startTime: startTime,
      durationHours: capped,
      date: _selectedDate,
    );

    setState(() {
      _startTime = startTime;
      _hoursCtrl.text = TimeParser.formatDecimalToHHmm(capped, isTriple: false);
      _finishTime = finishTime;
      _finishTimeEdited = false;
      _isOvertime = CountdownHelper.isOvertimeByTime(
        finishTime,
        date: _selectedDate,
      );
    });
  }

  String _defaultInstruction() {
    if (_selectedJobs.isEmpty) return '';
    final first = _selectedJobs.first;
    return [
      first.jobdesc.trim(),
      first.panelName.trim(),
    ].where((s) => s.isNotEmpty && s != '-').join(' - ');
  }

  Future<void> _save() async {
    if (_selectedEmployee == null || _selectedJobs.isEmpty) {
      AppNotification.showWarning(context, 'Lengkapi data terlebih dahulu.');
      return;
    }

    final load = await _employeeDayLoad(
      _selectedEmployee?['id']?.toString() ?? '',
      excludeDraftItemId: widget.initialDraft?['draftItemId']?.toString(),
    );
    if (!mounted) return;
    if (_minutesOfDay(_startTime) < _minutesOfDay(load.latestFinish)) {
      _startTime = load.latestFinish;
      AppNotification.showWarning(
        context,
        'Jam mulai digeser ke ${CountdownHelper.formatTime(_startTime)} karena operator sudah ada jadwal.',
      );
    }
    var hrs = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (hrs == null || hrs <= 0) {
      AppNotification.showWarning(context, 'Target jam tidak valid.');
      return;
    }

    final allowed = JobPlanAllocationHelper.allowedDayHours(
      usedNormal: load.usedNormal,
      usedOt: load.usedOt,
      isOvertime: _isOvertime,
      isSunday: _selectedDate.weekday == DateTime.sunday,
    );
    if (hrs > allowed) {
      final before = hrs;
      hrs = allowed.clamp(0.0, 9999.0).toDouble();
      _hoursCtrl.text = TimeParser.formatDecimalToHHmm(hrs, isTriple: false);
      AppNotification.showWarning(
        context,
        'Target jam dikurangi dari ${_formatHoursClock(before, zeroAsClock: true)} menjadi ${_formatHoursClock(hrs, zeroAsClock: true)} karena batas jam kerja.',
      );
    }
    if (hrs <= 0) {
      AppNotification.showWarning(context, 'Jam kerja operator sudah penuh.');
      return;
    }

    final totalRemaining = _selectedJobs.fold<double>(
      0.0,
      (sum, j) => sum + _availablePlanHours(j),
    );
    if (hrs > totalRemaining) {
      AppNotification.showWarning(
        context,
        'Target jam melebihi sisa jam countdown (maks ${_formatHoursClock(totalRemaining, zeroAsClock: true)}).',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> draftItems = [];

      final totalSessionHours = hrs;
      final allocations = JobPlanAllocationHelper.allocateSequential(
        taskDate: _selectedDate,
        sessionStartTime: _startTime,
        totalSessionHours: totalSessionHours,
        jobs: _selectedJobs
            .map(
              (job) => JobPlanAllocationTarget(
                jobId: job.id,
                availablePlanHours: _availablePlanHours(job),
              ),
            )
            .toList(),
      );

      for (final allocation in allocations) {
        final job = _selectedJobs.firstWhere(
          (item) => item.id == allocation.jobId,
        );

        final draftItem = {
          'draftItemId':
              'draft_${DateTime.now().microsecondsSinceEpoch}_${draftItems.length}',
          'sourceType': 'COUNTDOWN',
          'coreId': job.id,
          'carId': _selectedUnit!.carId,
          'divisionId': job.divisionId,
          'unitName': _selectedUnit!.unitName,
          'panelName': job.panelName,
          'assignedUserId': _selectedEmployee?['id']?.toString() ?? '',
          'assignedTo':
              (_selectedEmployee?['name'] ??
                      _selectedEmployee?['full_name'] ??
                      '-')
                  .toString(),
          'jobDescription': job.jobdesc,
          'targetHours': allocation.allocatedHours,
          'taskDate': _selectedDate.toIso8601String().split('T').first,
          'startTime': CountdownHelper.formatTime(allocation.startTime),
          'finishTime': CountdownHelper.formatTime(allocation.finishTime),
          'isOvertime': allocation.isOvertime,
          'note': _instructionCtrl.text.trim(),
        };

        draftItems.addAll(TaskExecutionHelper.splitJobPlanItem(draftItem));
      }

      final isKd = _session.isKdAccess;

      if (isKd) {
        final uid = _session.employeeId ?? '';
        if (widget.editIndex != null || widget.initialDraft != null) {
          final existingDraft = await _repository.getDraft(userId: uid);
          final existingItems =
              (existingDraft?['items'] as List<dynamic>? ?? <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .map(Map<String, dynamic>.from)
                  .toList();
          final editIndex =
              widget.editIndex ??
              existingItems.indexWhere(
                (t) =>
                    t['draftItemId']?.toString() ==
                    widget.initialDraft?['draftItemId']?.toString(),
              );
          if (editIndex >= 0 && editIndex < existingItems.length) {
            existingItems.removeAt(editIndex);
            existingItems.insertAll(editIndex, draftItems);
          } else {
            existingItems.addAll(draftItems);
          }
          await _repository.saveDraft(
            userId: uid,
            items: existingItems,
            sourceType: 'COUNTDOWN',
            replaceItems: true,
          );
        } else {
          await _repository.saveDraft(
            userId: uid,
            items: draftItems,
            sourceType: 'COUNTDOWN',
            replaceItems: false,
          );
        }
      } else {
        for (final item in draftItems) {
          await _repository.createPlan(
            coreId: item['coreId']?.toString() ?? '',
            carId: item['carId']?.toString() ?? '',
            sourceType: 'COUNTDOWN',
            sourceRefId: item['sourceRefId']?.toString() ?? '',
            unitName: item['unitName']?.toString() ?? '',
            panelName: item['panelName']?.toString() ?? '',
            assignedDivision: item['divisionId']?.toString() ?? '',
            assignedUserId: item['assignedUserId']?.toString() ?? '',
            assignedTo: item['assignedTo']?.toString() ?? '',
            description: item['jobDescription']?.toString() ?? '',
            targetHours: (item['targetHours'] as num?)?.toDouble() ?? 0.0,
            totalProjectHours: (item['totalProjectHours'] as num?)?.toDouble(),
            startDate: item['startDate']?.toString(),
            deadlineDate: item['deadlineDate']?.toString(),
            workDate: item['taskDate']?.toString() ?? '',
            startTime: item['startTime']?.toString() ?? '',
            finishTime: item['finishTime']?.toString() ?? '',
            isOvertime: item['isOvertime'] == true,
            note: item['note']?.toString() ?? '',
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      AppNotification.showSuccess(
        context,
        '${_selectedJobs.length} rencana kerja berhasil dikirim.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal mengirim rencana kerja'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Job Plan dari Countdown'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      // --- UNIT SELECTION ---
                      _SearchFieldTile(
                        label: 'Unit Kendaraan',
                        value: _selectedUnit?.unitName,
                        hint: 'Cari Unit Countdown',
                        onTap: () async {
                          final res = await jobPlanMasterSearchPicker(
                            context,
                            title: 'Pilih Unit',
                            items: _units
                                .map(
                                  (u) => {
                                    'id': u.carId,
                                    'name': u.unitName,
                                    'progress': u.progress,
                                    'owner': u.owner,
                                    'raw': u,
                                  },
                                )
                                .toList(),
                            labelBuilder: (m) => m['name'].toString(),
                            subtitleBuilder: (m) =>
                                '${m['progress']}% • ${m['owner']}',
                          );
                          if (res != null) {
                            _onUnitSelected(res['raw'] as CountdownUnit);
                          }
                        },
                      ),
                      SizedBox(height: 12),

                      // --- PANEL SELECTION ---
                      if (_selectedUnit != null) ...[
                        _SearchFieldTile(
                          label: 'Panel / Section',
                          value: _selectedPanel == null
                              ? null
                              : _panelSectionLabel(_selectedPanel!),
                          hint: 'Pilih Panel di Unit ini',
                          onTap: () async {
                            final res = await jobPlanMasterSearchPicker(
                              context,
                              title: 'Pilih Panel',
                              items: _panels
                                  .where((p) => p.totalRemainingHours > 0)
                                  .map(
                                    (p) => {
                                      'id': p.panelId,
                                      'name': _panelSectionLabel(p),
                                      'section':
                                          '${p.sectionProgress.round()}% • ${p.totalJobdesc} jobdesc • ${_formatHoursClock(p.totalRemainingHours, zeroAsClock: true)} sisa',
                                      'raw': p,
                                    },
                                  )
                                  .toList(),
                              labelBuilder: (m) => m['name'].toString(),
                              subtitleBuilder: (m) => m['section'].toString(),
                            );
                            if (res != null) {
                              _onPanelSelected(res['raw'] as CountdownSection);
                            }
                          },
                        ),
                        SizedBox(height: 12),
                      ],

                      // --- JOB SELECTION ---
                      if (_selectedPanel != null) ...[
                        _SearchFieldTile(
                          label: 'Pekerjaan (Jobdesc)',
                          value: _selectedJobs.isEmpty
                              ? null
                              : _selectedJobs.length == 1
                              ? _selectedJobs.first.jobdesc
                              : '${_selectedJobs.length} job dipilih',
                          hint: 'Pilih Tugas di Panel ini',
                          onTap: () async {
                            final res = await jobPlanMultiMasterSearchPicker(
                              context,
                              title: 'Pilih Jobdesc',
                              items: _jobdescs
                                  .map(
                                    (j) => {
                                      'id': j.id,
                                      'name': j.jobdesc,
                                      'progress': j.progress,
                                      'hours': _availablePlanHoursLabel(j),
                                      'raw': j,
                                    },
                                  )
                                  .toList(),
                              initialSelectionIds: _selectedJobs
                                  .map((j) => j.id)
                                  .toSet(),
                              labelBuilder: (m) => m['name'].toString(),
                              subtitleBuilder: (m) =>
                                  '${m['progress']}% • ${m['hours']}',
                            );
                            if (res != null) {
                              setState(() {
                                _selectedJobs.clear();
                                double totalRemaining = 0.0;
                                for (final item in res) {
                                  final job = item['raw'] as CountdownJobdesc;
                                  _selectedJobs.add(job);
                                  totalRemaining += _availablePlanHours(job);
                                }

                                if (totalRemaining > 0) {
                                  double target = totalRemaining;
                                  if (target > 8.0) target = 8.0;

                                  _hoursCtrl.text =
                                      TimeParser.formatDecimalToHHmm(
                                        target,
                                        isTriple: false,
                                      );
                                  _finishTimeEdited = false;
                                  _syncFinishTime();
                                  if (_instructionCtrl.text.trim().isEmpty) {
                                    _instructionCtrl.text =
                                        _defaultInstruction();
                                  }
                                }
                              });
                            }
                          },
                        ),
                        SizedBox(height: 12),
                      ],

                      // --- PROJECT STATS ---
                      if (_selectedJobs.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              _infoRow(
                                'Total Target (Dipilih)',
                                _formatHoursClock(
                                  _selectedJobs.fold<double>(
                                    0.0,
                                    (sum, j) => sum + j.targetHoursRevised,
                                  ),
                                  zeroAsClock: true,
                                ),
                              ),
                              _infoRow(
                                'Sisa Jam Kerja (Dipilih)',
                                _formatHoursClock(
                                  _selectedJobs.fold<double>(
                                    0.0,
                                    (sum, j) => sum + _availablePlanHours(j),
                                  ),
                                  zeroAsClock: true,
                                ),
                              ),
                              _infoRow(
                                'Pekerjaan Terpilih',
                                '${_selectedJobs.length} item',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // --- INSTRUCTIONS ---
                      _FormSection(
                        title: 'Instruksi / SPOK',
                        child: TextField(
                          controller: _instructionCtrl,
                          maxLines: 3,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tulis instruksi kerja...',
                          ),
                        ),
                      ),
                      SizedBox(height: 12),

                      // --- EXECUTOR ---
                      _FormSection(
                        title: 'Pelaksana',
                        child: _SearchFieldTile(
                          label: 'Operator',
                          value:
                              _selectedEmployee?['full_name'] ??
                              _selectedEmployee?['name'],
                          hint: 'Pilih Anggota',
                          onTap: () async {
                            final res = await jobPlanEmployeePicker(
                              context,
                              _employees,
                            );
                            if (res != null) {
                              setState(() => _selectedEmployee = res);
                              await _applyEmployeeDayCap();
                            }
                          },
                        ),
                      ),
                      SizedBox(height: 12),

                      // --- SHIFT ---
                      _FormSection(
                        title: 'Jadwal & Target Jam',
                        child: Column(
                          children: [
                            DurationInput(
                              labelText: 'Target Jam Hari Ini',
                              initialHours: TimeParser.parseHHmmToDecimal(
                                _hoursCtrl.text,
                              ),
                              isTripleHours:
                                  false, // Always HH:mm for daily countdown target
                              onChanged: (val) {
                                setState(() {
                                  _hoursCtrl.text =
                                      TimeParser.formatDecimalToHHmm(
                                        val,
                                        isTriple: false,
                                      );
                                });
                                _finishTimeEdited = false;
                                _syncFinishTime();
                              },
                            ),
                            SizedBox(height: 12),
                            _dateTile(),
                            SizedBox(height: 8),
                            _timeRow(),
                            SwitchListTile.adaptive(
                              value: _isOvertime,
                              onChanged: (v) async {
                                setState(() => _isOvertime = v);
                                await _applyEmployeeDayCap();
                              },
                              title: Text(
                                'Lembur',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              activeThumbColor: AppColors.gold,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- SAVE BUTTON ---
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                        ),
                        child: Builder(
                          builder: (context) {
                            final isKd = _session.isKdAccess;
                            return Text(
                              _isSaving
                                  ? (isKd ? 'MENYIMPAN...' : 'MENGIRIM...')
                                  : (isKd ? 'SIMPAN KE DRAFT' : 'KIRIM'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.background,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2025),
          lastDate: DateTime(2027),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _syncFinishTime();
          await _applyEmployeeDayCap();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: AppColors.gold),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tanggal Kerja',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  _formatDate(_selectedDate),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRow() {
    return Row(
      children: [
        Expanded(
          child: ClockTimeInput(
            labelText: 'Mulai',
            initialTime: _startTime,
            onChanged: (t) {
              setState(() => _startTime = t);
              _syncFinishTime();
            },
            onTapIcon: () => _pickTime(isStart: true),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ClockTimeInput(
            labelText: 'Selesai',
            initialTime: _finishTime,
            onChanged: (t) {
              setState(() {
                _finishTime = t;
                _finishTimeEdited = true;
                _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
              });
            },
            onTapIcon: () => _pickTime(isStart: false),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _finishTime,
    );
    if (picked != null) {
      if (isStart) {
        setState(() => _startTime = picked);
        _syncFinishTime();
      } else {
        setState(() {
          _finishTime = picked;
          _finishTimeEdited = true;
          _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _AdditionalPlanFormPage extends StatefulWidget {
  const _AdditionalPlanFormPage({
    required this.initialDate,
    // ignore: unused_element_parameter
    this.isUrgent = false,
    // ignore: unused_element_parameter
    this.isCountdown = false,
    // ignore: unused_element_parameter
    this.initialDraft,
    // ignore: unused_element_parameter
    this.editIndex,
  });

  final DateTime initialDate;
  final bool isUrgent;
  final bool isCountdown;
  final Map<String, dynamic>? initialDraft;
  final int? editIndex;

  @override
  State<_AdditionalPlanFormPage> createState() =>
      _AdditionalPlanFormPageState();
}

class _AdditionalPlanFormPageState extends State<_AdditionalPlanFormPage> {
  late final JobPlanRepository _repository;
  late final SessionManager _session;

  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _manualUnitCtrl = TextEditingController();
  final TextEditingController _manualPanelCtrl = TextEditingController();
  final TextEditingController _manualJobCtrl = TextEditingController();

  final TextEditingController _sectionNameCtrl = TextEditingController();
  final TextEditingController _hoursCtrl = TextEditingController();
  final TextEditingController _totalProjectHoursCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final Set<String> _selectedJobs = {};

  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _employees = [];

  Map<String, dynamic>? _selectedUnit;
  String? _selectedPanel;
  String _selectedDivision = '';
  String? _selectedEmployeeId;
  String? _selectedCategory;

  DateTime _selectedDate = DateTime.now();
  DateTime? _startDate;
  DateTime? _deadlineDate;

  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = TimeOfDay(hour: 16, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;
  bool _isRework = false;
  bool _isNonTechnicalJob = false;
  bool _useFreeTextPanel = false;
  bool _useManualInput = false;

  static final _panelCategories = [
    'ENGINE',
    'UNDERCARRIAGE',
    'ELECTRICAL',
    'INTERIOR',
    'EXTERIOR',
    'BODY',
    'CUSTOM',
  ];

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
    _selectedDate = widget.initialDate;
    _hoursCtrl.addListener(_syncFinishTimeFromHours);
    _initData();
  }

  @override
  void dispose() {
    _manualUnitCtrl.dispose();
    _manualPanelCtrl.dispose();
    _manualJobCtrl.dispose();
    _sectionNameCtrl.dispose();
    _hoursCtrl.removeListener(_syncFinishTimeFromHours);
    _hoursCtrl.dispose();
    _totalProjectHoursCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final drop = await _repository.getAdditionalDropdowns();
      if (!mounted) return;
      setState(() {
        _units = List<Map<String, dynamic>>.from(drop['cars'] ?? []);
        _divisions = List<Map<String, dynamic>>.from(drop['divisions'] ?? []);
        _isLoading = false;

        if (widget.initialDraft != null) {
          _hydrateDraft(widget.initialDraft!);
        } else {
          _selectedDivision = _session.divisionName ?? '';
          _applyStandardWorkday();
          _loadDivisionStaff();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _hydrateDraft(Map<String, dynamic> draft) {
    final hydrated = JobPlanAdditionalDraftHelper.hydrate(
      draft: draft,
      units: _units,
      divisions: _divisions,
    );

    _selectedJobs.clear();
    _manualUnitCtrl.text = hydrated.manualUnitName;
    _manualPanelCtrl.text = hydrated.manualPanelName;
    _manualJobCtrl.text = hydrated.manualJobDescription;
    _selectedUnit = hydrated.selectedUnit;
    _selectedPanel = hydrated.selectedPanel;
    _useManualInput = hydrated.useManualInput;
    _useFreeTextPanel = hydrated.useFreeTextPanel;
    _sectionNameCtrl.text = hydrated.freeTextPanelName;
    _selectedJobs.addAll(hydrated.selectedJobs);

    _selectedDivision = hydrated.divisionLabel;
    _selectedEmployeeId = hydrated.selectedEmployeeId;
    _selectedCategory = hydrated.selectedCategory;
    _selectedDate = DateTime.tryParse(draft['taskDate'] ?? '') ?? _selectedDate;
    final targetHours = switch (draft['targetHours']) {
      final num value => value.toDouble(),
      final String value => TimeParser.parseHHmmToDecimal(value),
      _ => null,
    };
    _hoursCtrl.text = TimeParser.formatDecimalToHHmm(targetHours ?? 0.0);
    final totalProjectHours = switch (draft['totalProjectHours']) {
      final num value => value.toDouble(),
      final String value => TimeParser.parseHHmmToDecimal(value),
      _ => null,
    };
    _totalProjectHoursCtrl.text =
        totalProjectHours == null || totalProjectHours <= 0
        ? ''
        : TimeParser.formatDecimalToHHmm(totalProjectHours, isTriple: true);
    _startDate = DateTime.tryParse((draft['startDate'] ?? '').toString());
    _deadlineDate = DateTime.tryParse((draft['deadlineDate'] ?? '').toString());

    final st = TimeParser.parseTimeOfDay(draft['startTime'] ?? '');
    if (st != null) _startTime = st;

    final ft = TimeParser.parseTimeOfDay(draft['finishTime'] ?? '');
    if (ft != null) {
      _finishTime = ft;
      _finishTimeEdited = true;
    }

    _isOvertime = draft['isOvertime'] == true || draft['isOvertime'] == 1;
    _isRework = draft['isRework'] == true || draft['isRework'] == 1;
    _isNonTechnicalJob =
        draft['isNonTechnicalJob'] == true || draft['isNonTechnicalJob'] == 1;
    _noteCtrl.text = draft['note']?.toString() ?? '';

    _loadDivisionStaff();
  }

  Future<void> _loadDivisionStaff() async {
    if (_selectedDivision.isEmpty) return;
    try {
      final staff = await _repository.getDropdownUsers(
        divisionId: _selectedDivision,
      );
      if (!mounted) return;
      setState(() => _employees = staff);
    } catch (_) {}
  }

  void _syncFinishTimeFromHours() {
    if (_finishTimeEdited) return;
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (targetHours != null && targetHours > 0) {
      setState(() {
        _finishTime = _calculateFinishTime(
          startTime: _startTime,
          durationHours: targetHours,
          date: _selectedDate,
        );
        _isOvertime = CountdownHelper.isOvertimeByTime(
          _finishTime,
          date: _selectedDate,
        );
      });
    }
  }

  void _applyStandardWorkday() {
    setState(() {
      _hoursCtrl.text = TimeParser.formatDecimalToHHmm(8.0, isTriple: false);
      _startTime = TimeOfDay(hour: 8, minute: 0);
      _finishTime = TimeOfDay(hour: 16, minute: 0);
      _finishTimeEdited = false;
      _isOvertime = false;
    });
  }

  Future<void> _save(
    Map<String, dynamic>? selectedUnit,
    Map<String, dynamic>? selectedEmployee,
  ) async {
    final manualUnit = _manualUnitCtrl.text.trim();
    final manualPanel = _manualPanelCtrl.text.trim();
    final manualJob = _manualJobCtrl.text.trim();
    final usesManualInput = _isNonTechnicalJob || _useManualInput;
    if (_isNonTechnicalJob) {
      if (manualJob.isEmpty) {
        AppNotification.showWarning(context, 'Nama aktivitas wajib diisi.');
        return;
      }
    } else if (_useManualInput) {
      if (selectedUnit == null || manualPanel.isEmpty || manualJob.isEmpty) {
        AppNotification.showWarning(
          context,
          'Pilih unit dari daftar, lalu lengkapi panel & pekerjaan.',
        );
        return;
      }
    } else if (selectedUnit == null || _selectedJobs.isEmpty) {
      AppNotification.showWarning(context, 'Lengkapi pilihan data.');
      return;
    }

    if (_selectedEmployeeId == null) {
      AppNotification.showWarning(context, 'Harap pilih pelaksana.');
      return;
    }

    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (targetHours == null || targetHours <= 0) {
      AppNotification.showWarning(context, 'Target jam tidak valid.');
      return;
    }

    setState(() => _isSaving = true);

    final effectiveSourceType = widget.isCountdown
        ? 'COUNTDOWN'
        : widget.isUrgent
        ? 'URGENT_ADDITIONAL'
        : 'ADDITIONAL';
    final sourceNote = _noteCtrl.text.trim();

    try {
      final dayLoad = await _employeeDayLoadFor(
        repository: _repository,
        session: sl<SessionManager>(),
        taskDate: _selectedDate,
        employeeId: _selectedEmployeeId!,
        excludeDraftItemId: widget.initialDraft?['draftItemId']?.toString(),
      );
      if (_minutesOfDayTop(_startTime) <
          _minutesOfDayTop(dayLoad.latestFinish)) {
        _startTime = dayLoad.latestFinish;
        if (mounted) {
          AppNotification.showWarning(
            context,
            'Jam mulai digeser ke ${CountdownHelper.formatTime(_startTime)} karena operator sudah ada jadwal.',
          );
        }
      }

      final jobsToCreate = usesManualInput
          ? <String>{manualJob}
          : _selectedJobs;
      final draftSeed = DateTime.now().microsecondsSinceEpoch;
      var draftOffset = 0;
      if (widget.isUrgent) {
        for (final job in jobsToCreate) {
          await _repository.createPlan(
            coreId: '',
            carId: _isNonTechnicalJob
                ? ''
                : (selectedUnit?['id']?.toString() ?? ''),
            sourceType: effectiveSourceType,
            sourceRefId: '',
            initialStatus: widget.isUrgent ? 'APPROVED' : null,
            syncToTasks: widget.isUrgent,
            isUrgent: widget.isUrgent,
            unitName: _isNonTechnicalJob
                ? ''
                : (selectedUnit?['unit_name']?.toString() ?? manualUnit),
            panelName: usesManualInput
                ? manualPanel
                : (_useFreeTextPanel
                      ? _sectionNameCtrl.text.trim()
                      : (_selectedPanel ?? '')),
            assignedDivision: _selectedDivision,
            assignedUserId: _selectedEmployeeId!,
            assignedTo: selectedEmployee?['full_name']?.toString() ?? '-',
            description: job,
            targetHours: targetHours,
            workDate: _formatDate(_selectedDate),
            startTime: CountdownHelper.formatTime(_startTime),
            finishTime: CountdownHelper.formatTime(_finishTime),
            isOvertime: _isOvertime,
            note: sourceNote,
          );
        }
      } else {
        final session = sl<SessionManager>();
        final drop = await _repository.getAdditionalDropdowns(
          divisionId: _selectedDivision,
        );
        final dynDivs = drop['divisions'] as List? ?? [];
        String divId = '';
        for (final d in dynDivs) {
          if (d['name']?.toString().toUpperCase() ==
              _selectedDivision.toUpperCase()) {
            divId = d['id'].toString();
            break;
          }
        }
        final newItems = <Map<String, dynamic>>[];

        // Calculate individual job duration by splitting the total session time
        final totalSessionHours =
            TimeParser.parseHHmmToDecimal(_hoursCtrl.text) ?? 0.0;
        final durationPerJob = totalSessionHours / jobsToCreate.length;

        TimeOfDay currentStartTime = _startTime;

        final uid = session.employeeId ?? '';
        final rejectedPlanId = (widget.initialDraft?['rejectedPlanId'] ?? '')
            .toString();
        final isReplacingDraft =
            rejectedPlanId.isNotEmpty || widget.editIndex != null;

        for (final job in jobsToCreate) {
          final existingDraftItemId =
              widget.initialDraft?['draftItemId']?.toString() ?? '';
          final nextDraftItemId =
              existingDraftItemId.isNotEmpty && draftOffset == 0
              ? existingDraftItemId
              : 'draft_${draftSeed}_$draftOffset';

          final currentFinishTime = CountdownHelper.calculateFinishTime(
            startTime: currentStartTime,
            durationHours: durationPerJob,
            date: _selectedDate,
          );

          final rawItem = {
            'draftItemId': nextDraftItemId,
            if (widget.initialDraft?['fromRejectedPlan'] == true)
              'fromRejectedPlan': true,
            if ((widget.initialDraft?['rejectedPlanId'] ?? '')
                .toString()
                .isNotEmpty)
              'rejectedPlanId': widget.initialDraft!['rejectedPlanId'],
            'carId': _isNonTechnicalJob
                ? ''
                : (selectedUnit?['id']?.toString() ?? ''),
            'divisionId': divId,
            'panelId': null,
            'panelCustomNote': usesManualInput
                ? manualPanel
                : (_useFreeTextPanel ? null : (_selectedPanel ?? '')),
            'sectionName': _useFreeTextPanel
                ? _sectionNameCtrl.text.trim()
                : null,
            'panelCategory': (usesManualInput || _useFreeTextPanel)
                ? _selectedCategory
                : null,
            'addPanelToMaster': true,
            'jobTypeId': null,
            'sourceType': 'ADDITIONAL',
            'isManualInput': usesManualInput,
            'assignedUserId': _selectedEmployeeId!,
            'assignedUserName':
                selectedEmployee?['name']?.toString() ??
                selectedEmployee?['full_name']?.toString() ??
                '',
            'taskDate': _formatDate(_selectedDate),
            'jobDescription': job,
            'targetHours': durationPerJob,
            'totalProjectHours': _isNonTechnicalJob
                ? null
                : () {
                    final raw = _totalProjectHoursCtrl.text.trim();
                    if (raw.isEmpty) return null;
                    if (raw.contains(':')) {
                      final parts = raw.split(':');
                      final h = double.tryParse(parts[0]) ?? 0;
                      final m =
                          double.tryParse(parts.length > 1 ? parts[1] : '0') ??
                          0;
                      return h + m / 60.0;
                    }
                    return double.tryParse(raw);
                  }(),
            'startDate': _startDate != null ? _formatDate(_startDate!) : null,
            'deadlineDate': _deadlineDate != null
                ? _formatDate(_deadlineDate!)
                : null,
            'startTime': CountdownHelper.formatTime(currentStartTime),
            'finishTime': CountdownHelper.formatTime(currentFinishTime),
            'isOvertime': CountdownHelper.isOvertimeByTime(
              currentFinishTime,
              date: _selectedDate,
            ),
            'isRework': _isRework,
            'isNonTechnicalJob': _isNonTechnicalJob,
            'unitName': _isNonTechnicalJob
                ? ''
                : (selectedUnit?['unit_name']?.toString() ?? manualUnit),
            'panelName': usesManualInput
                ? manualPanel
                : (_useFreeTextPanel
                      ? _sectionNameCtrl.text.trim()
                      : (_selectedPanel ?? '')),
          };

          newItems.addAll(TaskExecutionHelper.splitJobPlanItem(rawItem));
          currentStartTime = currentFinishTime;
          draftOffset++;
        }

        final isKd = _session.isKdAccess;

        if (isKd) {
          final existingDraft = await _repository.getDraft(userId: uid);
          final existingItems =
              (existingDraft?['items'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .map(Map<String, dynamic>.from)
                  .toList();
          existingItems.removeWhere(
            (t) =>
                t['isNonTechnicalJob'] != true &&
                t['carId'] == null &&
                t['panelId'] == null,
          );

          if (isReplacingDraft) {
            final rejectedDraftIndex = rejectedPlanId.isEmpty
                ? -1
                : existingItems.indexWhere(
                    (item) =>
                        item['rejectedPlanId']?.toString() == rejectedPlanId,
                  );

            if (rejectedDraftIndex >= 0) {
              existingItems.removeAt(rejectedDraftIndex);
              existingItems.insertAll(rejectedDraftIndex, newItems);
            } else if (rejectedPlanId.isNotEmpty) {
              existingItems.addAll(newItems);
            } else if (widget.editIndex != null &&
                widget.editIndex! >= 0 &&
                widget.editIndex! < existingItems.length) {
              existingItems.removeAt(widget.editIndex!);
              existingItems.insertAll(widget.editIndex!, newItems);
            } else {
              existingItems.addAll(newItems);
            }
            await _repository.saveDraft(
              userId: uid,
              items: existingItems,
              sourceType: 'ADDITIONAL',
              replaceItems: true,
              note: sourceNote,
            );
          } else {
            await _repository.saveDraft(
              userId: uid,
              items: newItems,
              sourceType: 'ADDITIONAL',
              replaceItems: false,
              note: sourceNote,
            );
          }
        } else {
          for (final item in newItems) {
            await _repository.createPlan(
              coreId: item['coreId']?.toString() ?? '',
              carId: item['carId']?.toString() ?? '',
              sourceType: item['sourceType']?.toString() ?? 'ADDITIONAL',
              sourceRefId: item['sourceRefId']?.toString() ?? '',
              unitName: item['unitName']?.toString() ?? '',
              panelName: item['panelName']?.toString() ?? '',
              assignedDivision: item['divisionId']?.toString() ?? '',
              assignedUserId: item['assignedUserId']?.toString() ?? '',
              assignedTo: item['assignedUserName']?.toString() ?? '',
              description: item['jobDescription']?.toString() ?? '',
              targetHours: (item['targetHours'] as num?)?.toDouble() ?? 0.0,
              totalProjectHours: (item['totalProjectHours'] as num?)
                  ?.toDouble(),
              startDate: item['startDate']?.toString(),
              deadlineDate: item['deadlineDate']?.toString(),
              workDate: item['taskDate']?.toString() ?? '',
              startTime: item['startTime']?.toString() ?? '',
              finishTime: item['finishTime']?.toString() ?? '',
              isOvertime: item['isOvertime'] == true,
              isNonTechnicalJob: item['isNonTechnicalJob'] == true,
              note: sourceNote,
            );
          }

          if (isReplacingDraft && rejectedPlanId.isNotEmpty) {
            try {
              await _repository.deleteRejectedPlan(
                planId: rejectedPlanId,
                userId: uid,
              );
            } catch (_) {}
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${newItems.length} rencana kerja berhasil dikirim.',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMessage(e, fallback: 'Gagal menyimpan task')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEmployee = _employees.firstWhere(
      (e) => e['id']?.toString() == _selectedEmployeeId,
      orElse: () => <String, dynamic>{},
    );
    final selectedEmployeeName =
        selectedEmployee['name']?.toString() ??
        selectedEmployee['full_name']?.toString() ??
        '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.initialDraft != null
              ? 'Edit Job Plan'
              : (widget.isUrgent ? 'Urgent Job' : 'Additional Job'),
        ),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _FormSection(
                        title: 'Metode Input',
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              value: _isNonTechnicalJob,
                              onChanged: (v) =>
                                  setState(() => _isNonTechnicalJob = v),
                              title: Text(
                                'Pekerjaan Non Teknis',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Meeting, coaching, atau aktivitas tanpa panel',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              activeThumbColor: AppColors.gold,
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (!_isNonTechnicalJob)
                              SwitchListTile.adaptive(
                                value: _useManualInput,
                                onChanged: (v) =>
                                    setState(() => _useManualInput = v),
                                title: Text(
                                  'Input Nama Unit/Panel Manual',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                activeThumbColor: AppColors.gold,
                                contentPadding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),

                      if (_isNonTechnicalJob) ...[
                        _FormSection(
                          title: 'Aktivitas',
                          child: TextField(
                            controller: _manualJobCtrl,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Nama Aktivitas *',
                              hintText: 'Contoh: Meeting progres',
                            ),
                          ),
                        ),
                      ] else if (_useManualInput) ...[
                        _FormSection(
                          title: 'Detail Unit & Panel',
                          child: Column(
                            children: [
                              _SearchFieldTile(
                                label: 'Unit Kendaraan',
                                value: _selectedUnit?['unit_name'],
                                hint: 'Cari Unit',
                                onTap: () async {
                                  final res = await jobPlanMasterSearchPicker(
                                    context,
                                    title: 'Pilih Unit',
                                    items: _units,
                                    labelBuilder: (m) =>
                                        m['unit_name']?.toString() ?? '',
                                    subtitleBuilder: (m) =>
                                        m['customer_name']?.toString() ?? '',
                                  );
                                  if (res != null) {
                                    setState(() {
                                      _selectedUnit = res;
                                      _manualUnitCtrl.text =
                                          res['unit_name']?.toString() ?? '';
                                    });
                                  }
                                },
                              ),
                              SizedBox(height: 12),
                              TextField(
                                controller: _manualPanelCtrl,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Nama Panel *',
                                  hintText: 'Contoh: Mesin',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _FormSection(
                          title: 'Pilih Kendaraan & Divisi',
                          child: Column(
                            children: [
                              _SearchFieldTile(
                                label: 'Unit Kendaraan',
                                value: _selectedUnit?['unit_name'],
                                hint: 'Cari Unit',
                                onTap: () async {
                                  final res = await jobPlanMasterSearchPicker(
                                    context,
                                    title: 'Pilih Unit',
                                    items: _units,
                                    labelBuilder: (m) =>
                                        m['unit_name']?.toString() ?? '',
                                    subtitleBuilder: (m) =>
                                        m['customer_name']?.toString() ?? '',
                                  );
                                  if (res != null) {
                                    setState(() {
                                      _selectedUnit = res;
                                      _selectedPanel = null;
                                    });
                                  }
                                },
                              ),
                              SizedBox(height: 12),
                              _SearchFieldTile(
                                label: 'Divisi Pelaksana',
                                value: _selectedDivision,
                                hint: 'Pilih Divisi',
                                onTap: () async {
                                  final res = await jobPlanMasterSearchPicker(
                                    context,
                                    title: 'Pilih Divisi',
                                    items: _divisions,
                                    labelBuilder: (m) =>
                                        m['name']?.toString() ?? '',
                                  );
                                  if (res != null) {
                                    setState(() {
                                      _selectedDivision =
                                          res['name']?.toString() ?? '';
                                      _selectedEmployeeId = null;
                                      _selectedJobs.clear();
                                    });
                                    _loadDivisionStaff();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        _FormSection(
                          title: 'Panel & Section',
                          child: Column(
                            children: [
                              if (!_useFreeTextPanel)
                                _SearchFieldTile(
                                  label: 'Panel Master',
                                  value: _selectedPanel,
                                  hint: 'Pilih Panel (Opsional)',
                                  onTap: () async {
                                    final drop = await _repository.getDropdowns(
                                      carId: _selectedUnit?['id']?.toString(),
                                    );
                                    if (!context.mounted) return;
                                    final res = await jobPlanMasterSearchPicker(
                                      context,
                                      title: 'Pilih Panel',
                                      items: drop['panels'] ?? [],
                                      labelBuilder: (m) =>
                                          m['name']?.toString() ?? '',
                                      subtitleBuilder: (m) =>
                                          m['section']?.toString() ?? '',
                                    );
                                    if (res != null) {
                                      setState(
                                        () => _selectedPanel = res['name']
                                            ?.toString(),
                                      );
                                    }
                                  },
                                ),
                              CheckboxListTile.adaptive(
                                value: _useFreeTextPanel,
                                onChanged: (v) => setState(() {
                                  _useFreeTextPanel = v ?? false;
                                  if (!_useFreeTextPanel) {
                                    _sectionNameCtrl.clear();
                                  }
                                }),
                                title: Text(
                                  'Pakai nama section/panel baru',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                activeColor: AppColors.gold,
                              ),
                              if (_useFreeTextPanel)
                                TextField(
                                  controller: _sectionNameCtrl,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Nama Section/Panel Baru *',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 16),

                      _FormSection(
                        title: 'Detail Pekerjaan',
                        child: Column(
                          children: [
                            if (_useManualInput)
                              TextField(
                                controller: _manualJobCtrl,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Nama Pekerjaan *',
                                  hintText: 'Contoh: Turunkan Mesin',
                                ),
                              )
                            else
                              _SearchFieldTile(
                                label: 'Pekerjaan',
                                value: _selectedJobs.isEmpty
                                    ? null
                                    : _selectedJobs.length == 1
                                    ? _selectedJobs.first
                                    : '${_selectedJobs.length} job dipilih',
                                hint: 'Pilih Pekerjaan',
                                onTap: () async {
                                  if (_selectedDivision.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Pilih divisi dulu sebelum memilih jobdesc.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final names =
                                      await JobPlanJobTypeHelper.loadAdditionalJobTypeNames(
                                        divisionId: _selectedDivision,
                                        loadDropdowns:
                                            _repository.getAdditionalDropdowns,
                                      );
                                  if (!context.mounted) return;
                                  if (names.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Master jobdesc untuk divisi $_selectedDivision belum tersedia.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  final selectedJobs =
                                      await jobPlanMultiJobPicker(
                                        context,
                                        title: 'Pilih Banyak Pekerjaan',
                                        items: names,
                                        initialSelection: _selectedJobs,
                                      );
                                  if (selectedJobs != null) {
                                    setState(() {
                                      _selectedJobs.clear();
                                      _selectedJobs.addAll(selectedJobs);
                                    });
                                  }
                                },
                              ),
                            SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceCard,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Kategori Pekerjaan *',
                              ),
                              items: _panelCategories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedCategory = v),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      _FormSection(
                        title: 'Pelaksana',
                        child: Column(
                          children: [
                            _SearchFieldTile(
                              label: 'Pelaksana',
                              value: selectedEmployeeName == '-'
                                  ? null
                                  : selectedEmployeeName,
                              hint: 'Pilih Pelaksana',
                              onTap: () async {
                                final selected = await jobPlanEmployeePicker(
                                  context,
                                  _employees,
                                );
                                if (selected != null) {
                                  setState(
                                    () => _selectedEmployeeId = selected['id']
                                        ?.toString(),
                                  );
                                }
                              },
                            ),
                            SizedBox(height: 12),
                            DurationInput(
                              labelText: 'Target Jam Pengerjaan',
                              initialHours: TimeParser.parseHHmmToDecimal(
                                _hoursCtrl.text,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _hoursCtrl.text =
                                      TimeParser.formatDecimalToHHmm(
                                        val,
                                        isTriple: false,
                                      );
                                  _finishTimeEdited = false;
                                  _syncFinishTimeFromHours();
                                });
                              },
                            ),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: _applyStandardWorkday,
                                child: Text('Set jam kerja normal 8 jam'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      // ── Total Project Hours + Timeline ──────────────────
                      if (!_isNonTechnicalJob)
                        _FormSection(
                          title: 'Target Proyek',
                          child: Column(
                            children: [
                              TextField(
                                controller: _totalProjectHoursCtrl,
                                keyboardType:
                                    TextInputType.numberWithOptions(
                                      decimal: false,
                                    ),
                                inputFormatters: [TotalProjectHoursFormatter()],
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Total Target Proyek (000:00)',
                                  hintText: 'Contoh: 180:00',
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        'Tanggal Mulai Proyek',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _startDate != null
                                            ? _formatDate(_startDate!)
                                            : 'Sama dg tgl pengerjaan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.play_circle_outline_rounded,
                                        color: AppColors.gold,
                                        size: 18,
                                      ),
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _startDate ?? _selectedDate,
                                          firstDate: DateTime(2024),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) {
                                          setState(() => _startDate = picked);
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        'Deadline Proyek',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _deadlineDate != null
                                            ? _formatDate(_deadlineDate!)
                                            : 'Tidak ditentukan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.flag_rounded,
                                        color: AppColors.gold,
                                        size: 18,
                                      ),
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _deadlineDate ??
                                              _selectedDate.add(
                                                Duration(days: 7),
                                              ),
                                          firstDate: DateTime(2024),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) {
                                          setState(
                                            () => _deadlineDate = picked,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 16),
                      _FormSection(
                        title: 'Jadwal Harian',
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Tanggal Pengerjaan',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              subtitle: Text(
                                _formatDate(_selectedDate),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              trailing: Icon(
                                Icons.calendar_today_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2027),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                    if (!_finishTimeEdited) {
                                      final targetHours =
                                          TimeParser.parseHHmmToDecimal(
                                            _hoursCtrl.text,
                                          );
                                      if (targetHours != null &&
                                          targetHours > 0) {
                                        _finishTime = _calculateFinishTime(
                                          startTime: _startTime,
                                          durationHours: targetHours,
                                          date: _selectedDate,
                                        );
                                      }
                                    }
                                    _isOvertime =
                                        CountdownHelper.isOvertimeByTime(
                                          _finishTime,
                                          date: _selectedDate,
                                        );
                                  });
                                }
                              },
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClockTimeInput(
                                    labelText: 'Jam Mulai',
                                    initialTime: _startTime,
                                    onChanged: (t) {
                                      setState(() {
                                        _startTime = t;
                                        if (!_finishTimeEdited) {
                                          final targetHours =
                                              TimeParser.parseHHmmToDecimal(
                                                _hoursCtrl.text,
                                              );
                                          if (targetHours != null &&
                                              targetHours > 0) {
                                            _finishTime = _calculateFinishTime(
                                              startTime: _startTime,
                                              durationHours: targetHours,
                                              date: _selectedDate,
                                            );
                                          }
                                        }
                                        _isOvertime =
                                            CountdownHelper.isOvertimeByTime(
                                              _finishTime,
                                              date: _selectedDate,
                                            );
                                      });
                                    },
                                    onTapIcon: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _startTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _startTime = picked;
                                          if (!_finishTimeEdited) {
                                            final targetHours =
                                                TimeParser.parseHHmmToDecimal(
                                                  _hoursCtrl.text,
                                                );
                                            if (targetHours != null &&
                                                targetHours > 0) {
                                              _finishTime =
                                                  _calculateFinishTime(
                                                    startTime: _startTime,
                                                    durationHours: targetHours,
                                                    date: _selectedDate,
                                                  );
                                            }
                                          }
                                          _isOvertime =
                                              CountdownHelper.isOvertimeByTime(
                                                _finishTime,
                                                date: _selectedDate,
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ClockTimeInput(
                                    labelText: 'Jam Selesai',
                                    initialTime: _finishTime,
                                    onChanged: (t) {
                                      setState(() {
                                        _finishTime = t;
                                        _finishTimeEdited = true;
                                        _isOvertime =
                                            CountdownHelper.isOvertimeByTime(
                                              _finishTime,
                                              date: _selectedDate,
                                            );
                                      });
                                    },
                                    onTapIcon: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _finishTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _finishTime = picked;
                                          _finishTimeEdited = true;
                                          _isOvertime =
                                              CountdownHelper.isOvertimeByTime(
                                                _finishTime,
                                                date: _selectedDate,
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SwitchListTile.adaptive(
                              value: _isOvertime,
                              onChanged: (value) =>
                                  setState(() => _isOvertime = value),
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: AppColors.gold,
                              title: Text(
                                'Jam lembur',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                            CheckboxListTile.adaptive(
                              value: _isRework,
                              onChanged: (v) =>
                                  setState(() => _isRework = v ?? false),
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Pekerjaan Rework',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              activeColor: AppColors.gold,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      _FormSection(
                        title: 'Catatan Rencana',
                        child: TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tulis catatan khusus (opsional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Submit bar ─────────────────────────────────────
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _isSaving
                            ? null
                            : () => _save(_selectedUnit, selectedEmployee),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                        ),
                        child: Builder(
                          builder: (context) {
                            final session = sl<SessionManager>();
                            final isKd = session.isKdAccess;
                            return Text(
                              _isSaving
                                  ? (isKd ? 'MENYIMPAN...' : 'MENGIRIM...')
                                  : (isKd ? 'SIMPAN KE DRAFT' : 'KIRIM'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.background,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── Work Order / WOV Source Picker ───────────────────────────────────────────

class _WoSourcePicker extends StatelessWidget {
  const _WoSourcePicker({required this.orders, required this.onSelect});

  final List<WorkOrder> orders;
  final ValueChanged<WorkOrder> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Pilih Work Order',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada WO aktif',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) {
                        final wo = orders[i];
                        return ListTile(
                          title: Text(
                            wo.unitName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${wo.jobDetail}\nPanel: ${wo.panelName ?? '-'}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.gold,
                          ),
                          isThreeLine: true,
                          onTap: () => onSelect(wo),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic Source Form (WO/WOV) ─────────────────────────────────────────────

class _PlanSourceSeed {
  _PlanSourceSeed({
    required this.sourceLabel,
    required this.sourceType,
    required this.sourceRefId,
    required this.sourceRoute,
    required this.unitName,
    required this.carId,
    required this.panelName,
    required this.assignedDivision,
    required this.description,
    required this.targetHours,
  });

  final String sourceLabel;
  final String sourceType;
  final String sourceRefId;
  final String sourceRoute;
  final String unitName;
  final String carId;
  final String panelName;
  final String assignedDivision;
  final String description;
  final double targetHours;
}

class _SourcePlanFormPage extends StatefulWidget {
  const _SourcePlanFormPage({required this.seed, required this.initialDate});

  final _PlanSourceSeed seed;
  final DateTime initialDate;

  @override
  State<_SourcePlanFormPage> createState() => _SourcePlanFormPageState();
}

class _SourcePlanFormPageState extends State<_SourcePlanFormPage> {
  late final JobPlanRepository _repository;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _jobdescCtrl = TextEditingController();
  final TextEditingController _panelCtrl = TextEditingController();
  final TextEditingController _hoursCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _employees = [];
  String? _selectedEmployeeId;

  late DateTime _selectedDate;
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = TimeOfDay(hour: 16, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _selectedDate = widget.initialDate;
    _jobdescCtrl.text = widget.seed.description;
    _panelCtrl.text = widget.seed.panelName;
    _hoursCtrl.text = TimeParser.formatDecimalToHHmm(
      widget.seed.targetHours,
      isTriple: false,
    );
    _hoursCtrl.addListener(_syncFinishTimeFromHours);
    _initData();
  }

  @override
  void dispose() {
    _jobdescCtrl.dispose();
    _panelCtrl.dispose();
    _hoursCtrl.removeListener(_syncFinishTimeFromHours);
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final staff = await _repository.getDropdownUsers(
        divisionId: widget.seed.assignedDivision,
      );
      if (!mounted) return;
      setState(() {
        _employees = staff;
        _isLoading = false;
        _syncFinishTimeFromHours();
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncFinishTimeFromHours() {
    if (_finishTimeEdited) return;
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (targetHours != null && targetHours > 0) {
      setState(() {
        _finishTime = _calculateFinishTime(
          startTime: _startTime,
          durationHours: targetHours,
          date: _selectedDate,
        );
        _isOvertime = CountdownHelper.isOvertimeByTime(
          _finishTime,
          date: _selectedDate,
        );
      });
    }
  }

  void _applyStandardWorkday() {
    setState(() {
      _hoursCtrl.text = TimeParser.formatDecimalToHHmm(8.0, isTriple: false);
      _startTime = TimeOfDay(hour: 8, minute: 0);
      _finishTime = TimeOfDay(hour: 17, minute: 0);
      _finishTimeEdited = false;
      _isOvertime = false;
    });
  }

  Future<void> _save(String selectedEmployeeName) async {
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Harap pilih pelaksana.')));
      return;
    }
    if (_jobdescCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jobdesc tidak boleh kosong.')),
      );
      return;
    }
    if (targetHours == null || targetHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target hours harus valid dan lebih dari 0.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final sourceNote = _noteCtrl.text.trim();

    try {
      final session = sl<SessionManager>();
      final drop = await _repository.getAdditionalDropdowns(
        divisionId: widget.seed.assignedDivision,
      );
      final dynDivs = drop['divisions'] as List? ?? [];
      String divId = '';
      for (final d in dynDivs) {
        if (d['name']?.toString().toUpperCase() ==
            widget.seed.assignedDivision.toUpperCase()) {
          divId = d['id'].toString();
          break;
        }
      }

      final newItem = <String, dynamic>{
        'draftItemId': 'draft_${DateTime.now().microsecondsSinceEpoch}',
        'carId': widget.seed.carId,
        'sourceRefId': widget.seed.sourceRefId,
        'divisionId': divId,
        'panelId': null,
        'panelCustomNote': _panelCtrl.text.trim().isNotEmpty
            ? _panelCtrl.text.trim()
            : widget.seed.panelName,
        'jobTypeId': null,
        'assignedUserId': _selectedEmployeeId!,
        'assignedUserName': selectedEmployeeName,
        'unitName': widget.seed.unitName,
        'panelName': _panelCtrl.text.trim().isNotEmpty
            ? _panelCtrl.text.trim()
            : widget.seed.panelName,
        'sourceType': widget.seed.sourceType,
        'taskDate': _formatDate(_selectedDate),
        'jobDescription': _jobdescCtrl.text.trim().isNotEmpty
            ? _jobdescCtrl.text.trim()
            : widget.seed.description,
        'targetHours': targetHours,
        'startTime': CountdownHelper.formatTime(_startTime),
        'finishTime': CountdownHelper.formatTime(_finishTime),
        'isOvertime': _isOvertime,
      };

      final splitItems = TaskExecutionHelper.splitJobPlanItem(newItem);
      final uid = session.employeeId ?? '';

      final isKd = session.isKdAccess;

      if (isKd) {
        final existingDraft = await _repository.getDraft(userId: uid);
        final existingItems = (existingDraft?['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
        existingItems.removeWhere(
          (t) => t['carId'] == null && t['panelId'] == null,
        );

        existingItems.addAll(splitItems);

        await _repository.saveDraft(
          userId: uid,
          items: existingItems,
          sourceType: widget.seed.sourceType,
          replaceItems: true,
          note: sourceNote,
        );
      } else {
        for (final item in splitItems) {
          await _repository.createPlan(
            coreId: item['coreId']?.toString() ?? '',
            carId: item['carId']?.toString() ?? '',
            sourceType:
                item['sourceType']?.toString() ?? widget.seed.sourceType,
            sourceRefId: item['sourceRefId']?.toString() ?? '',
            unitName: item['unitName']?.toString() ?? '',
            panelName: item['panelName']?.toString() ?? '',
            assignedDivision: item['divisionId']?.toString() ?? '',
            assignedUserId: item['assignedUserId']?.toString() ?? '',
            assignedTo: item['assignedUserName']?.toString() ?? '',
            description: item['jobDescription']?.toString() ?? '',
            targetHours: (item['targetHours'] as num?)?.toDouble() ?? 0.0,
            totalProjectHours: (item['totalProjectHours'] as num?)?.toDouble(),
            startDate: item['startDate']?.toString(),
            deadlineDate: item['deadlineDate']?.toString(),
            workDate: item['taskDate']?.toString() ?? '',
            startTime: item['startTime']?.toString() ?? '',
            finishTime: item['finishTime']?.toString() ?? '',
            isOvertime: item['isOvertime'] == true,
            note: sourceNote,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      AppNotification.showSuccess(context, 'Rencana kerja berhasil dikirim.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMessage(e, fallback: 'Gagal menyimpan task')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEmployee = _employees.firstWhere(
      (e) => e['id']?.toString() == _selectedEmployeeId,
      orElse: () => <String, dynamic>{},
    );
    final selectedEmployeeName =
        selectedEmployee['name']?.toString() ??
        selectedEmployee['full_name']?.toString() ??
        '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Job Plan dari ${widget.seed.sourceLabel}'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _FormSection(
                        title: 'Info Sumber',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.seed.sourceLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Unit: ${widget.seed.unitName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      _FormSection(
                        title: 'Panel & Jobdesc',
                        child: Column(
                          children: [
                            TextField(
                              controller: _panelCtrl,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Panel / Section *',
                                hintText: 'Nama panel atau section',
                                prefixIcon: Icon(
                                  Icons.layers_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _jobdescCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Jobdesc / Deskripsi Pekerjaan *',
                                hintText: 'Deskripsi pekerjaan',
                                prefixIcon: Icon(
                                  Icons.work_outline_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      _FormSection(
                        title: 'Pelaksana',
                        child: Column(
                          children: [
                            _SearchFieldTile(
                              label: 'Pelaksana',
                              value: selectedEmployeeName == '-'
                                  ? null
                                  : selectedEmployeeName,
                              hint: 'Pilih Pelaksana',
                              onTap: () async {
                                final selected = await jobPlanEmployeePicker(
                                  context,
                                  _employees,
                                );
                                if (selected != null) {
                                  setState(
                                    () => _selectedEmployeeId = selected['id']
                                        ?.toString(),
                                  );
                                }
                              },
                            ),
                            SizedBox(height: 12),
                            DurationInput(
                              labelText: 'Target Jam Pengerjaan',
                              initialHours: TimeParser.parseHHmmToDecimal(
                                _hoursCtrl.text,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _hoursCtrl.text =
                                      TimeParser.formatDecimalToHHmm(
                                        val,
                                        isTriple: false,
                                      );
                                  _finishTimeEdited = false;
                                  _syncFinishTimeFromHours();
                                });
                              },
                            ),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: _applyStandardWorkday,
                                child: Text('Set jam kerja normal 8 jam'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      _FormSection(
                        title: 'Jadwal',
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Tanggal Pengerjaan',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              subtitle: Text(
                                _formatDate(_selectedDate),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              trailing: Icon(
                                Icons.calendar_today_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2027),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                    _syncFinishTimeFromHours();
                                  });
                                }
                              },
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClockTimeInput(
                                    labelText: 'Mulai',
                                    initialTime: _startTime,
                                    onChanged: (t) {
                                      setState(() {
                                        _startTime = t;
                                        _syncFinishTimeFromHours();
                                      });
                                    },
                                    onTapIcon: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _startTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _startTime = picked;
                                          _syncFinishTimeFromHours();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ClockTimeInput(
                                    labelText: 'Selesai',
                                    initialTime: _finishTime,
                                    onChanged: (t) {
                                      setState(() {
                                        _finishTime = t;
                                        _finishTimeEdited = true;
                                        _isOvertime =
                                            CountdownHelper.isOvertimeByTime(
                                              _finishTime,
                                              date: _selectedDate,
                                            );
                                      });
                                    },
                                    onTapIcon: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _finishTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _finishTime = picked;
                                          _finishTimeEdited = true;
                                          _isOvertime =
                                              CountdownHelper.isOvertimeByTime(
                                                _finishTime,
                                                date: _selectedDate,
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SwitchListTile.adaptive(
                              value: _isOvertime,
                              onChanged: (value) =>
                                  setState(() => _isOvertime = value),
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: AppColors.gold,
                              title: Text(
                                'Jam lembur',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      _FormSection(
                        title: 'Catatan Rencana',
                        child: TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tulis catatan khusus (SPOK)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _isSaving
                            ? null
                            : () => _save(selectedEmployeeName),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                        ),
                        child: Text(
                          _isSaving ? 'MENYIMPAN...' : 'SIMPAN KE DRAFT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── Reusable Form Widgets ──────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.gold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SearchFieldTile extends StatelessWidget {
  const _SearchFieldTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });
  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value ?? hint,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab Approval: Date → Divisi → Unit → Plans (dengan bulk approve)
class _ApprovalTab extends StatefulWidget {
  const _ApprovalTab({
    required this.onPlanTap,
    required this.refreshNotifier,
    required this.onRefresh,
    this.initialDate,
  });
  final Future<void> Function(JobPlan) onPlanTap;
  final ValueNotifier<int> refreshNotifier;
  final VoidCallback onRefresh;
  final DateTime? initialDate;

  @override
  State<_ApprovalTab> createState() => _ApprovalTabState();
}

class _ApprovalTabState extends State<_ApprovalTab> {
  late final JobPlanRepository _repo;
  late final SessionManager _session;

  bool _isLoading = false;
  late DateTime _date;

  // Navigasi drill-down
  Map<String, dynamic>? _selDivision;
  Map<String, dynamic>? _selUnit;

  // Data per level
  List<Map<String, dynamic>> _divisionItems = [];
  List<Map<String, dynamic>> _unitItems = [];
  List<JobPlan> _planItems = [];

  // Bulk select
  final Set<String> _selectedIds = {};
  bool _isBulkApproving = false;

  int get _level {
    if (_selUnit == null) return 0; // no unit selected → show units
    if (_selDivision == null) {
      return 1; // unit selected, no division → show divisions
    }
    return 2; // both selected → show plans
  }

  String get _dateStr {
    final d = _date;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _repo = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
    _date = widget.initialDate ?? DateTime.now();
    widget.refreshNotifier.addListener(_fetchCurrentLevel);
    _fetchCurrentLevel();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_fetchCurrentLevel);
    super.dispose();
  }

  Future<void> _fetchCurrentLevel() async {
    setState(() => _isLoading = true);
    if (_level < 2) {
      // Level 0: no unitId → units; Level 1: unitId set, no divisionId → divisions
      final res = await _repo.getApprovalRaw(
        unitId: _selUnit?['id']?.toString() ?? _selUnit?['unitId']?.toString(),
        taskDate: _dateStr,
      );
      res.fold(
        (failure) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          AppNotification.showError(
            context,
            friendlyMessage(failure, fallback: 'Gagal memuat data'),
          );
        },
        (raw) {
          final items = (raw['items'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          if (mounted) {
            setState(() {
              _isLoading = false;
              if (_level == 0) _unitItems = items;
              if (_level == 1) _divisionItems = items;
            });
          }
        },
      );
    } else {
      // Level 2: both unitId + divisionId → plans
      _repo
          .getApprovalQueue(
            unitId:
                _selUnit?['id']?.toString() ?? _selUnit?['unitId']?.toString(),
            divisionId:
                _selDivision?['id']?.toString() ??
                _selDivision?['divisionId']?.toString(),
            taskDate: _dateStr,
          )
          .then((result) {
            result.fold(
              (failure) {
                if (!mounted) return;
                setState(() => _isLoading = false);
                AppNotification.showError(
                  context,
                  friendlyMessage(failure, fallback: 'Gagal memuat data'),
                );
              },
              (plans) {
                if (mounted) {
                  setState(() {
                    _planItems = plans;
                    _isLoading = false;
                  });
                }
              },
            );
          });
    }
  }

  void _goBack() {
    setState(() {
      _selectedIds.clear();
      if (_level == 2) {
        _selDivision = null;
        _divisionItems = [];
        _planItems = [];
      } else if (_level == 1) {
        _selUnit = null;
        _unitItems = [];
      }
    });
    _fetchCurrentLevel();
  }

  void _selectUnit(Map<String, dynamic> unit) {
    setState(() {
      _selUnit = unit;
      _unitItems = [];
      _selectedIds.clear();
    });
    _fetchCurrentLevel();
  }

  void _selectDivision(Map<String, dynamic> div) {
    setState(() {
      _selDivision = div;
      _divisionItems = [];
      _selectedIds.clear();
    });
    _fetchCurrentLevel();
  }

  bool _canReview(String status) => _canReviewApprovalStatus(_session, status);

  Future<void> _processBulkApproval() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isBulkApproving = true);
    int ok = 0;
    final failed = <String>[];
    for (final id in _selectedIds) {
      final res = await _repo.approvePlan(
        planId: id,
        userId: _session.employeeId ?? '',
      );
      res.isRight() ? ok++ : failed.add(id);
    }
    if (!mounted) return;
    final msg = failed.isEmpty
        ? '$ok plan berhasil disetujui.'
        : '$ok plan disetujui, ${failed.length} gagal.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: failed.isEmpty
            ? Color(0xFF2E7D32)
            : Color(0xFFFFA000),
      ),
    );
    if (mounted) {
      setState(() {
        _isBulkApproving = false;
        _selectedIds.clear();
      });
    }
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header: Date + Breadcrumb
        Container(
          color: AppColors.surfaceCard,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: DateFilterBar(
                  selectedDate: _date,
                  onDateChanged: (d) {
                    setState(() {
                      _date = d;
                      _selUnit = null;
                      _selDivision = null;
                      _unitItems = [];
                      _divisionItems = [];
                      _planItems = [];
                      _selectedIds.clear();
                    });
                    _fetchCurrentLevel();
                  },
                ),
              ),
              if (_level > 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 16,
                          color: AppColors.gold,
                        ),
                        onPressed: _goBack,
                      ),
                      Expanded(
                        child: Text(
                          _level == 1
                              ? (_selUnit?['name'] ??
                                    _selUnit?['unitName'] ??
                                    '')
                              : '${_selUnit?['name'] ?? _selUnit?['unitName'] ?? ''} › ${_selDivision?['name'] ?? _selDivision?['divisionName'] ?? ''}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : _level == 0
              ? _buildUnitList()
              : _level == 1
              ? _buildDivisionList()
              : _buildPlanList(),
        ),
        // Bulk action bar
        if (_level == 2 && _selectedIds.isNotEmpty)
          _BulkApproveBar(
            selectedCount: _selectedIds.length,
            isLoading: _isBulkApproving,
            onApprove: _processBulkApproval,
          ),
      ],
    );
  }

  Widget _buildDivisionList() {
    if (_divisionItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchCurrentLevel,
        child: ListView(
          children: [
            SizedBox(height: 100),
            Center(child: Text('Tidak ada antrian approval.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchCurrentLevel,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _divisionItems.length,
        itemBuilder: (ctx, i) {
          final div = _divisionItems[i];
          final name = (div['name'] ?? div['divisionName'] ?? '-').toString();
          return _NavDrillCard(
            title: name,
            subtitle: 'Ketuk untuk lihat unit',
            icon: Icons.business_rounded,
            onTap: () => _selectDivision(div),
          );
        },
      ),
    );
  }

  Widget _buildUnitList() {
    if (_unitItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchCurrentLevel,
        child: ListView(
          children: [
            SizedBox(height: 100),
            Center(child: Text('Tidak ada unit dengan antrian.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchCurrentLevel,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _unitItems.length,
        itemBuilder: (ctx, i) {
          final unit = _unitItems[i];
          final name =
              (unit['name'] ?? unit['unitName'] ?? unit['unit_name'] ?? '-')
                  .toString();
          return _NavDrillCard(
            title: name,
            subtitle: 'Ketuk untuk lihat rencana',
            icon: Icons.directions_car_rounded,
            onTap: () => _selectUnit(unit),
          );
        },
      ),
    );
  }

  Widget _buildPlanList() {
    if (_planItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchCurrentLevel,
        child: ListView(
          children: [
            SizedBox(height: 100),
            Center(child: Text('Tidak ada rencana.')),
          ],
        ),
      );
    }
    final reviewablePlans = _planItems
        .where((p) => _canReview(p.status))
        .toList();
    final allSelected =
        reviewablePlans.isNotEmpty &&
        reviewablePlans.every((p) => _selectedIds.contains(p.planId));
    return Column(
      children: [
        if (reviewablePlans.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_planItems.length} rencana',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(reviewablePlans.map((p) => p.planId));
                    }
                  }),
                  child: Text(
                    allSelected ? 'Batal Semua' : 'Pilih Semua',
                    style: TextStyle(color: AppColors.gold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchCurrentLevel,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 80),
              itemCount: _planItems.length,
              itemBuilder: (ctx, i) {
                final plan = _planItems[i];
                final isSelected = _selectedIds.contains(plan.planId);
                return _ApprovalPlanCard(
                  key: ValueKey('appr_${plan.planId}'),
                  plan: plan,
                  onTap: () async {
                    await widget.onPlanTap(plan);
                    _fetchCurrentLevel();
                  },
                  isSelected: isSelected,
                  onSelectionChanged: _canReview(plan.status)
                      ? (val) => setState(
                          () => val == true
                              ? _selectedIds.add(plan.planId)
                              : _selectedIds.remove(plan.planId),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Card navigasi untuk drill-down Divisi/Unit
class _NavDrillCard extends StatelessWidget {
  const _NavDrillCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar untuk bulk approve
class _BulkApproveBar extends StatelessWidget {
  const _BulkApproveBar({
    required this.selectedCount,
    required this.isLoading,
    required this.onApprove,
  });
  final int selectedCount;
  final bool isLoading;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: isLoading ? null : onApprove,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            icon: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.background,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.check_circle_rounded),
            label: Text(
              isLoading ? 'Menyetujui...' : 'Setujui $selectedCount Rencana',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalPlanCard extends StatelessWidget {
  const _ApprovalPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  final JobPlan plan;
  final VoidCallback onTap;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final canSelect = onSelectionChanged != null;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              if (canSelect)
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.gold,
                  onChanged: onSelectionChanged,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.unitName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      plan.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            plan.assignedTo,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.targetHoursAlias ?? _formatHours(plan.targetHours),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (plan.remainingHoursAlias != null &&
                      plan.remainingHoursAlias!.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      'Sisa: ${plan.remainingHoursAlias}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (plan.status != 'DRAFT' &&
                      (plan.totalActualHours > 0 || plan.progress > 0)) ...[
                    SizedBox(height: 2),
                    Text(
                      'Riwayat: ${_formatHoursClock(plan.totalActualHours, zeroAsClock: true)} (${plan.progress}%)',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
                  _StatusChip(status: plan.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(status);
    final label = _resolveLabel(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _resolveColor(String s) {
    return switch (s.toUpperCase()) {
      'PENDING_ADV' => AppColors.gold,
      'PENDING_KP' => Colors.indigo,
      'PENDING_MP' => Colors.blue,
      'PENDING_PM' => Colors.blue,
      'PLAN' || 'APPROVED' => AppColors.statusDone,
      'ONPROGRESS' || 'ON_PROGRESS' => AppColors.gold,
      'PENDING' => Colors.orange,
      'READY_QC' => Colors.teal,
      'DONE' => AppColors.statusDone,
      'REJECTED' => AppColors.statusLocked,
      _ => AppColors.textMuted,
    };
  }

  String _resolveLabel(String s) {
    return switch (s.toUpperCase()) {
      'PENDING_ADV' => 'QA',
      'PENDING_KP' => 'KP',
      'PENDING_MP' => 'MP',
      'PENDING_PM' => 'PM',
      'PLAN' || 'APPROVED' => 'ACC',
      'ONPROGRESS' || 'ON_PROGRESS' => 'PROSES',
      'PENDING' => 'HOLD',
      'READY_QC' => 'QC',
      'DONE' => 'DONE',
      'REJECTED' => 'REJ',
      _ => s,
    };
  }
}

class _ApprovalMetaChip extends StatelessWidget {
  const _ApprovalMetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalDetailField extends StatelessWidget {
  const _ApprovalDetailField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseTab extends StatefulWidget {
  const _BrowseTab({
    required this.initialDate,
    required this.onParamsChanged,
    required this.refreshNotifier,
    required this.onRefresh,
  });
  final DateTime initialDate;
  final void Function(DateTime, String?, String?) onParamsChanged;
  final ValueNotifier<int> refreshNotifier;
  final VoidCallback onRefresh;

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  late final JobPlanRepository _repository;
  late final SessionManager _session;

  bool _isLoading = true;
  bool _isSubmittingDrafts = false;
  List<JobPlan> _plans = [];
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedDraftIds = {};

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
    _selectedDate = widget.initialDate;
    widget.refreshNotifier.addListener(_fetch);
    _fetch();
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_fetch);
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    List<JobPlan> fetchedPlans = [];

    // 2. Fetch Drafts from Redis
    try {
      final uid = _session.employeeId ?? '';
      final existingDraft = await _repository.getDraft(userId: uid);
      if (existingDraft != null && existingDraft.containsKey('items')) {
        final items = existingDraft['items'] as List<dynamic>;
        for (int i = 0; i < items.length; i++) {
          final map = items[i] as Map<String, dynamic>;
          // Filter draft by taskDate
          if (map['taskDate'] == dateStr) {
            fetchedPlans.add(
              JobPlan(
                planId: map['draftItemId']?.toString() ?? 'idx_$i',
                coreId: map['coreId']?.toString() ?? '',
                carId: map['carId']?.toString() ?? '',
                sourceType: map['sourceType']?.toString() ?? '',
                sourceRefId: '',
                unitName: map['unitName']?.toString() ?? '',
                panelName: map['panelName']?.toString() ?? '',
                assignedDivision:
                    map['divisionName']?.toString() ??
                    map['assignedDivision']?.toString() ??
                    map['divisionId']?.toString() ??
                    '',
                assignedUserId: map['assignedUserId']?.toString() ?? '',
                assignedTo:
                    map['assignedUserName']?.toString() ??
                    map['assignedTo']?.toString() ??
                    '',
                description: map['jobDescription']?.toString() ?? '',
                targetHours: (map['targetHours'] as num?)?.toDouble() ?? 0.0,
                workDate: map['taskDate']?.toString() ?? '',
                startTime: map['startTime']?.toString() ?? '',
                finishTime: map['finishTime']?.toString() ?? '',
                isOvertime: map['isOvertime'] == true,
                deadline: '',
                status: 'DRAFT',
                note: map['note']?.toString() ?? '',
                remainingHoursAlias: map['remainingHours'] != null
                    ? _formatHoursClock(
                        (map['remainingHours'] as num?)?.toDouble() ?? 0.0,
                        zeroAsClock: true,
                      )
                    : null,
                progress: 0,
                totalActualHours: 0.0,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Ignore draft fetch errors
    }

    if (mounted) {
      setState(() {
        _plans = fetchedPlans;
        _isLoading = false;
      });
    }
  }

  /// Deletes a REJECTED plan from DB (not Redis draft).
  Future<void> _deleteRejectedItem(JobPlan plan) async {
    setState(() {
      _plans.removeWhere((p) => p.planId == plan.planId);
      _isLoading = true;
    });
    try {
      final uid = _session.employeeId ?? '';
      await _repository.deleteRejectedPlan(planId: plan.planId, userId: uid);
      if (mounted) {
        AppNotification.showSuccess(
          context,
          'Rencana ditolak berhasil dihapus.',
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal menghapus rencana'),
        );
        _fetch(); // Re-fetch to restore list on error
      }
    }
  }

  Future<void> _deleteDraftItem(JobPlan plan) async {
    setState(() {
      _plans.removeWhere((p) => p.planId == plan.planId);
      _isLoading = true;
    });
    try {
      final uid = _session.employeeId ?? '';
      final existingDraft = await _repository.getDraft(userId: uid);
      if (existingDraft != null && existingDraft.containsKey('items')) {
        final originalItems = existingDraft['items'] as List<dynamic>;
        final items = originalItems
            .asMap()
            .entries
            .where((entry) {
              final item = entry.value as Map<String, dynamic>;
              final draftId =
                  item['draftItemId']?.toString() ?? 'idx_${entry.key}';
              return draftId != plan.planId;
            })
            .map((e) => e.value as Map<String, dynamic>)
            .toList();

        if (items.length < originalItems.length) {
          if (items.isEmpty) {
            await _repository.deleteDraft(userId: uid);
          } else {
            await _repository.saveDraft(
              userId: uid,
              items: items,
              sourceType:
                  existingDraft['sourceType']?.toString() ?? 'ADDITIONAL',
              replaceItems: true,
              note: existingDraft['note']?.toString(),
            );
          }
          if (mounted) {
            AppNotification.showSuccess(context, 'Draf berhasil dihapus.');
            widget.onRefresh();
          }
        } else {
          // No item matched the plan.planId
          if (mounted) {
            setState(() => _isLoading = false);
            _fetch(); // Re-fetch to sync UI
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _fetch();
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal menghapus draf'),
        );
        _fetch(); // Re-fetch on error
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editDraftItem(JobPlan plan) async {
    final uid = _session.employeeId ?? '';
    final existingDraft = await _repository.getDraft(userId: uid);
    final items =
        (existingDraft?['items'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final index = items.indexWhere(
      (t) => t['draftItemId']?.toString() == plan.planId,
    );
    if (index < 0) {
      if (mounted) {
        AppNotification.showWarning(context, 'Draft tidak ditemukan.');
      }
      return;
    }

    if (!mounted) return;
    final item = Map<String, dynamic>.from(items[index]);
    final sourceType = (item['sourceType'] ?? plan.sourceType ?? '')
        .toString()
        .toUpperCase();
    final date =
        DateTime.tryParse('${item['taskDate'] ?? plan.workDate ?? ''}') ??
        _selectedDate;
    final bool? res;
    if (sourceType == 'COUNTDOWN') {
      res = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _CountdownPlanFormPage(
            initialDate: date,
            initialDraft: item,
            editIndex: index,
          ),
        ),
      );
    } else {
      res = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _AdditionalPlanFormPage(
            initialDate: date,
            initialDraft: item,
            editIndex: index,
          ),
        ),
      );
    }
    if (res == true) _fetch();
  }

  Future<void> _submitDrafts() async {
    if (_selectedDraftIds.isEmpty) {
      if (mounted) {
        AppNotification.showWarning(
          context,
          'Pilih minimal satu draf untuk dikirim.',
        );
      }
      return;
    }
    setState(() => _isSubmittingDrafts = true);
    try {
      final uid = _session.employeeId ?? '';
      final existingDraft = await _repository.getDraft(userId: uid);
      if (existingDraft != null && existingDraft.containsKey('items')) {
        final itemsList = existingDraft['items'] as List<dynamic>;
        final allItems = normalizeSequentialDraftItems(
          itemsList.map((e) => e as Map<String, dynamic>).toList(),
        );

        final itemsToSubmit = allItems
            .asMap()
            .entries
            .where((entry) {
              final id =
                  entry.value['draftItemId']?.toString() ?? 'idx_${entry.key}';
              return _selectedDraftIds.contains(id);
            })
            .map((e) => e.value)
            .toList();

        final remainingItems = allItems
            .asMap()
            .entries
            .where((entry) {
              final id =
                  entry.value['draftItemId']?.toString() ?? 'idx_${entry.key}';
              return !_selectedDraftIds.contains(id);
            })
            .map((e) => e.value)
            .toList();

        await _repository.submitDraft(
          userId: uid,
          items: itemsToSubmit,
          sourceType: existingDraft['sourceType']?.toString() ?? 'ADDITIONAL',
        );

        // Remove submitted drafts from Redis
        if (remainingItems.isEmpty) {
          await _repository.deleteDraft(userId: uid);
        } else {
          await _repository.saveDraft(
            userId: uid,
            items: remainingItems,
            sourceType: existingDraft['sourceType']?.toString() ?? 'ADDITIONAL',
            replaceItems: true,
          );
        }

        _selectedDraftIds.clear();

        if (mounted) {
          AppNotification.showSuccess(
            context,
            'Draft berhasil dikirim ke antrean.',
          );
          widget.onRefresh();
        }
      } else {
        if (mounted) {
          AppNotification.showWarning(
            context,
            'Tidak ada draft untuk dikirim.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal mengirim draft'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingDrafts = false);
    }
  }

  /// Shows a detail bottom-sheet for a DRAFT plan item.
  Future<void> _showDraftDetail(JobPlan plan) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detail Draft Rencana',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Divider(color: AppColors.borderSubtle),
                SizedBox(height: 8),
                _DetailRow(
                  label: 'Unit',
                  value: plan.unitName.isNotEmpty ? plan.unitName : '-',
                ),
                _DetailRow(
                  label: 'Panel',
                  value: plan.panelName.isNotEmpty ? plan.panelName : '-',
                ),
                _DetailRow(
                  label: 'Divisi',
                  value: plan.assignedDivision.isNotEmpty
                      ? plan.assignedDivision
                      : '-',
                ),
                _DetailRow(
                  label: 'Pelaksana',
                  value: plan.assignedTo.isNotEmpty ? plan.assignedTo : '-',
                ),
                _DetailRow(label: 'Tanggal Kerja', value: plan.workDate),
                _DetailRow(
                  label: 'Jam Kerja',
                  value: '${plan.startTime} - ${plan.finishTime}',
                ),
                _DetailRow(
                  label: 'Target Harian',
                  value:
                      plan.targetHoursAlias ?? _formatHours(plan.targetHours),
                ),
                _DetailRow(
                  label: 'Lembur',
                  value: plan.isOvertime ? 'Ya' : 'Tidak',
                ),
                Divider(color: AppColors.borderSubtle),
                SizedBox(height: 4),
                _DetailRow(
                  label: 'Jobdesc',
                  value: plan.description.isNotEmpty ? plan.description : '-',
                ),
                if (plan.note.isNotEmpty)
                  _DetailRow(label: 'Catatan', value: plan.note),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(Icons.edit_outlined, size: 16),
                        label: Text('Edit'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editDraftItem(plan);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: Icon(Icons.delete_outline, size: 16),
                        label: Text('Hapus'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteDraftItem(plan);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusLocked,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftPlans = _plans.where((p) => p.status == 'DRAFT').toList();
    final hasDrafts = draftPlans.isNotEmpty;
    final allDraftsSelected =
        draftPlans.isNotEmpty &&
        draftPlans.every((p) => _selectedDraftIds.contains(p.planId));
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DateFilterBar(
            selectedDate: _selectedDate,
            onDateChanged: (dt) {
              setState(() => _selectedDate = dt);
              widget.onParamsChanged(_selectedDate, null, null);
              _fetch();
            },
          ),
        ),
        if (draftPlans.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${draftPlans.length} draft',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (allDraftsSelected) {
                      _selectedDraftIds.clear();
                    } else {
                      _selectedDraftIds.addAll(draftPlans.map((p) => p.planId));
                    }
                  }),
                  child: Text(
                    allDraftsSelected ? 'Batal Semua' : 'Pilih Semua',
                    style: TextStyle(color: AppColors.gold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : _plans.isEmpty
              ? Center(child: Text('Tidak ada rencana kerja.'))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _plans.length,
                  itemBuilder: (ctx, i) {
                    final plan = _plans[i];
                    final isDraft = plan.status == 'DRAFT';
                    final isRejected = plan.status == 'REJECTED';
                    final isEditable = isDraft || isRejected;
                    return _SubmittedPlanCard(
                      key: ValueKey('browse_${plan.planId}'),
                      plan: plan,
                      onDelete: isDraft
                          ? () => _deleteDraftItem(plan)
                          : isRejected
                          ? () => _deleteRejectedItem(plan)
                          : null,
                      onTap: isEditable ? () => _showDraftDetail(plan) : null,
                      onEdit: isDraft ? () => _editDraftItem(plan) : null,
                      isSelected:
                          isDraft && _selectedDraftIds.contains(plan.planId),
                      onSelectionChanged: isDraft
                          ? (val) => setState(
                              () => val == true
                                  ? _selectedDraftIds.add(plan.planId)
                                  : _selectedDraftIds.remove(plan.planId),
                            )
                          : null,
                    );
                  },
                ),
        ),
        if (hasDrafts)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmittingDrafts ? null : _submitDrafts,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                  ),
                  child: Text(
                    _isSubmittingDrafts
                        ? 'MENGIRIM...'
                        : 'KIRIM ${_selectedDraftIds.length} DRAFT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.background,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubmittedPlanCard extends StatelessWidget {
  const _SubmittedPlanCard({
    super.key,
    required this.plan,
    this.onDelete,
    this.onTap,
    this.onEdit,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  final JobPlan plan;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final isDraft = plan.status == 'DRAFT';
    final isOt = plan.isOvertime;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.borderSubtle,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: checkbox / status / actions ──────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (onSelectionChanged != null)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: onSelectionChanged,
                        activeColor: AppColors.gold,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (onSelectionChanged != null) SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.unitName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOt) ...[
                          SizedBox(width: 4),
                          Icon(
                            Icons.nights_stay_rounded,
                            size: 14,
                            color: AppColors.gold,
                          ),
                        ],
                        SizedBox(width: 8),
                        _StatusChip(status: plan.status),
                      ],
                    ),
                  ),
                  // Edit & Delete — only for drafts
                  if (isDraft && onDelete != null) ...[
                    SizedBox(width: 4),
                    if (onEdit != null)
                      GestureDetector(
                        onTap: onEdit,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: onDelete,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.statusLocked,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 6),
              // ── Job description ──────────────────────────────────
              Text(
                plan.description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              // ── Panel name ───────────────────────────────────────
              if (plan.panelName.isNotEmpty)
                Text(
                  plan.panelName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              SizedBox(height: 10),
              // ── Bottom row: assignee + hours + history ───────────
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        plan.assignedTo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: AppColors.gold,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${plan.startTime} - ${plan.finishTime}  |  ${plan.targetHoursAlias ?? _formatHours(plan.targetHours)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  if (plan.remainingHoursAlias != null &&
                      plan.remainingHoursAlias!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_bottom,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Sisa: ${plan.remainingHoursAlias}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  if (!isDraft && plan.totalActualHours > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${plan.totalActualHours.toStringAsFixed(1)}j (${plan.progress}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple two-column label/value row used in detail sheets.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
