/*
Tujuan: Halaman job plan untuk approval queue dan rencana/draft creator.
Caller: Route /plans, dashboard management, dan task section plan.
Dependensi: RBAC, SessionManager, JobPlanRepository, WorkOrderRepository, DateFilterBar.
Main Functions: _loadPlans, _showCreateSourceSheet, _showAdditionalTaskDialog, BrowseTab.
Side Effects: HTTP GET/POST/PUT job plan, navigasi ke source route, refresh approval dan browse state.
*/
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:sm_system/core/auth/rbac.dart';
import 'package:sm_system/core/constants/app_colors.dart';
import 'package:sm_system/core/di/injection.dart';
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
import 'package:sm_system/features/task_execution/presentation/utils/task_execution_helper.dart';
import 'package:sm_system/core/utils/snackbar_helper.dart';
import 'package:sm_system/core/errors/failures.dart';

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

bool _canReviewApprovalStatus(String? role, String status) {
  final r = role?.toLowerCase();
  return switch (r) {
    'pm' => true,
    'adv' => status == 'PENDING_ADV',
    _ => false,
  };
}

bool _canEditPlan(String? role, String status) {
  final r = role?.toLowerCase();
  return switch (r) {
    'kd' => status == 'REJECTED' || status.startsWith('PENDING'),
    _ => false,
  };
}

bool _truthy(dynamic value) => value == true || value == 1 || value == '1';

String _formatHours(double hours) {
  if (hours <= 0) return '-';
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (h > 0 && m > 0) return '${h}j ${m}m';
  if (h > 0) return '${h}j';
  return '${m}m';
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
    shape: const RoundedRectangleBorder(
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
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => ss(() => query = v),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Cari...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada hasil',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                labelBuilder(item),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: subtitleBuilder != null
                                  ? Text(
                                      subtitleBuilder(item),
                                      style: const TextStyle(
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
    shape: const RoundedRectangleBorder(
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
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (selected.isNotEmpty)
                        Text(
                          '${selected.length} dipilih',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => ss(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Cari pengerjaan...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle:
                            subtitleBuilder != null
                                ? Text(
                                  subtitleBuilder(item),
                                  style: const TextStyle(fontSize: 12),
                                )
                                : null,
                        onChanged: (val) {
                          ss(() {
                            if (val == true) {
                              selected.add(item);
                            } else {
                              selected.removeWhere(
                                (s) =>
                                    s['id'].toString() ==
                                    item['id'].toString(),
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected.toSet()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                      child: const Text(
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
    subtitleBuilder: (m) =>
        [
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
    shape: const RoundedRectangleBorder(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Cari job',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          const Divider(color: AppColors.border),
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
                            leading: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.gold,
                            ),
                            title: Text(
                              'Gunakan "${query.trim()}"',
                              style: const TextStyle(
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
                            style: const TextStyle(color: AppColors.textPrimary),
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                      child: const Text(
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

  bool _isLoading = true;
  List<JobPlan> _plans = [];
  final Set<String> _selectedApprovalPlanIds = {};
  bool _isBulkApproving = false;

  // Browse state
  DateTime _browseDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
    if (widget.initialDate != null) {
      _browseDate = widget.initialDate!;
    }
    _loadPlans();

    if (widget.autoOpenCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateSourceSheet();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final result = await _repository.getApprovalQueue();
    result.fold<void>(
      (failure) {
        if (mounted) setState(() => _isLoading = false);
      },
      (data) {
        if (mounted) {
          setState(() {
            _plans = data;
            _isLoading = false;
          });
        }
      },
    );
  }

  bool _isReviewablePlan(JobPlan plan) {
    return _canReviewApprovalStatus(_session.role, plan.status);
  }

  Future<void> _processBulkApproval() async {
    if (_selectedApprovalPlanIds.isEmpty) return;
    setState(() => _isBulkApproving = true);

    int approvedCount = 0;
    final failedPlanIds = <String>[];

    for (final id in _selectedApprovalPlanIds) {
      final res = await _repository.approvePlan(
        planId: id,
        userId: _session.employeeId ?? '',
      );
      if (res.isRight()) {
        approvedCount++;
      } else {
        failedPlanIds.add(id);
      }
    }
    if (!mounted) return;
    setState(() {
      _isBulkApproving = false;
      _isLoading = true;
      _selectedApprovalPlanIds
        ..clear()
        ..addAll(failedPlanIds);
    });
    await _loadPlans();
    if (!mounted) return;
    final message = failedPlanIds.isEmpty
        ? '$approvedCount plan berhasil disetujui.'
        : '$approvedCount plan disetujui, ${failedPlanIds.length} gagal diproses.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failedPlanIds.isEmpty
            ? const Color(0xFF2E7D32)
            : const Color(0xFFFFA000),
      ),
    );
  }

  Future<void> _showApprovalPlanDetail(JobPlan plan) async {
    final raw = _findApprovalPlanRaw(plan.planId) ?? const <String, dynamic>{};
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
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
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                      label: plan.sourceType,
                    ),
                    _ApprovalMetaChip(
                      icon: plan.isOvertime
                          ? Icons.nights_stay_rounded
                          : Icons.sunny,
                      label: plan.isOvertime ? 'LEMBUR' : 'NORMAL',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ApprovalDetailField(
                  label: 'Pelaksana',
                  value: _pickJobPlanText([plan.assignedTo], '-'),
                ),
                _ApprovalDetailField(label: 'Unit', value: detailUnit),
                _ApprovalDetailField(label: 'Panel', value: detailPanel),
                if (panelSection != null)
                  _ApprovalDetailField(label: 'Section', value: panelSection),
                _ApprovalDetailField(label: 'Divisi', value: detailDivision),
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
                  _ApprovalDetailField(label: 'Source Ref', value: sourceRefId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalBulkActionBar() {
    final reviewablePlanIds = _plans
        .where(_isReviewablePlan)
        .map((plan) => plan.planId)
        .toList();
    if (reviewablePlanIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedCount = reviewablePlanIds
        .where(_selectedApprovalPlanIds.contains)
        .length;
    final areAllSelected =
        selectedCount == reviewablePlanIds.length &&
        reviewablePlanIds.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selectedCount > 0
            ? AppColors.gold.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selectedCount > 0
              ? AppColors.gold.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: areAllSelected,
            activeColor: AppColors.gold,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedApprovalPlanIds.addAll(reviewablePlanIds);
                } else {
                  _selectedApprovalPlanIds.clear();
                }
              });
            },
          ),
          const Text(
            'Pilih Semua',
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          const Spacer(),
          if (selectedCount > 0)
            FilledButton(
              onPressed: _isBulkApproving ? null : _processBulkApproval,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                _isBulkApproving ? '...' : 'Setujui $selectedCount',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.background,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findApprovalPlanRaw(String planId) {
    // Find in repository cache or fresh? For mock:
    return null;
  }

  String _statusLabel(String status) {
    return switch (status.toUpperCase()) {
      'PENDING_ADV' => 'Menunggu Advisor',
      'PENDING_PM' => 'Menunggu MP',
      'APPROVED' => 'Disetujui',
      'REJECTED' => 'Ditolak',
      _ => status,
    };
  }

  void _showCreateSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
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
              leading: const Icon(Icons.timer_outlined, color: AppColors.gold),
              title: const Text('Countdown List'),
              subtitle: const Text('Gunakan sisa jam dari project car aktif'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _CountdownPlanFormPage(
                      initialDate: _browseDate,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.gold,
              ),
              title: const Text('Work Order / WOV'),
              subtitle: const Text('Tarik dari WO internal atau vendor'),
              onTap: () {
                Navigator.pop(ctx);
                _showWoSourcePicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task_rounded, color: AppColors.gold),
              title: const Text('Additional Task'),
              subtitle: const Text('Input pekerjaan manual atau urgent'),
              onTap: () {
                Navigator.pop(ctx);
                _showAdditionalTaskDialog();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showWoSourcePicker() async {
    final woRepo = sl<WorkOrderRepository>();
    final result = await woRepo.getWorkOrders(view: 'ACTIVE');

    result.fold<void>(
      (failure) => AppNotification.showError(context, failure.message ?? 'Error unknown'),
      (orders) {
        // Filter those already hasCountdownLink?
        // Actually, JobPlan BE will handle duplication.
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surfaceCard,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => _WoSourcePicker(
            orders: orders,
            onSelect: (wo) {
              Navigator.pop(ctx);
              Navigator.of(context).push(
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
            },
          ),
        );
      },
    );
  }

  void _showAdditionalTaskDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdditionalPlanFormPage(initialDate: _browseDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
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
          tabs: const [Tab(text: 'Approval Plan'), Tab(text: 'Rencana')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _showCreateSourceSheet,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ApprovalTab(
            isLoading: _isLoading,
            plans: _plans,
            onRefresh: _loadPlans,
            onShowDetail: _showApprovalPlanDetail,
            selectedIds: _selectedApprovalPlanIds,
            onSelectionChanged: (id, selected) {
              setState(() {
                if (selected) {
                  _selectedApprovalPlanIds.add(id);
                } else {
                  _selectedApprovalPlanIds.remove(id);
                }
              });
            },
            bulkActionBar: _buildApprovalBulkActionBar(),
          ),
          _BrowseTab(
            initialDate: _browseDate,
            onParamsChanged: (date, divId, carId) {
              setState(() {
                _browseDate = date;
              });
            },
          ),
        ],
      ),
    );
  }
}

// ── Countdown Form ────────────────────────────────────────────────────────────

class _CountdownPlanFormPage extends StatefulWidget {
  const _CountdownPlanFormPage({required this.initialDate});

  final DateTime initialDate;

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
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 16, minute: 0);
  final TextEditingController _hoursCtrl = TextEditingController(text: '08:00');
  final TextEditingController _instructionCtrl = TextEditingController();
  bool _finishTimeEdited = false;
  bool _isOvertime = false;

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
        role: _session.role,
        division: _session.divisionName,
      );
      if (!mounted) return;
      setState(() {
        _units = units;
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
      );
      final employees = await _repository.getDropdownUsers(
        divisionId: matchingDiv.divisionId.toString(),
      );

      if (!mounted) return;
      setState(() {
        _panels = panels;
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
      );
      if (!mounted) return;
      setState(() {
        _jobdescs = jobdescs;
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

  Future<void> _save() async {
    if (_selectedEmployee == null || _selectedJobs.isEmpty) {
      AppNotification.showWarning(context, 'Lengkapi data terlebih dahulu.');
      return;
    }

    final hrs = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (hrs == null || hrs <= 0) {
      AppNotification.showWarning(context, 'Target jam tidak valid.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> draftItems = [];
      
      // Calculate individual job duration by splitting the total session time
      final totalSessionHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text) ?? 0.0;
      final durationPerJob = totalSessionHours / _selectedJobs.length;
      
      TimeOfDay currentStartTime = _startTime;

      for (final job in _selectedJobs) {
        // Each job gets a proportional slice of the total session duration
        final currentFinishTime = CountdownHelper.calculateFinishTime(
          startTime: currentStartTime,
          durationHours: durationPerJob,
          date: _selectedDate,
        );

        final draftItem = {
          'draftItemId': 'draft_${DateTime.now().microsecondsSinceEpoch}_${draftItems.length}',
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
          'targetHours': durationPerJob,
          'taskDate': _selectedDate.toIso8601String().split('T').first,
          'startTime': CountdownHelper.formatTime(currentStartTime),
          'finishTime': CountdownHelper.formatTime(currentFinishTime),
          'isOvertime': CountdownHelper.isOvertimeByTime(currentFinishTime, date: _selectedDate),
          'note': [
            'Sumber: Countdown ${job.id}',
            if (_instructionCtrl.text.trim().isNotEmpty)
              'SPOK: ${_instructionCtrl.text.trim()}',
          ].join(' | '),
        };

        // Important: Still check for 8h auto-split per individual job if needed
        draftItems.addAll(TaskExecutionHelper.splitJobPlanItem(draftItem));
        
        // Next job starts exactly when this one finishes
        currentStartTime = currentFinishTime;
      }

      await _repository.saveDraft(
        userId: _session.employeeId ?? '',
        items: draftItems,
        sourceType: 'COUNTDOWN',
        replaceItems: false,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      AppNotification.showSuccess(
        context,
        '${_selectedJobs.length} rencana berhasil disusun berurutan ke Draft.',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppNotification.showError(context, 'Gagal menyimpan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Job Plan dari Countdown'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
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
                                    'owner': u.owner,
                                    'raw': u,
                                  },
                                )
                                .toList(),
                            labelBuilder: (m) => m['name'].toString(),
                            subtitleBuilder: (m) => m['owner'].toString(),
                          );
                          if (res != null) {
                            _onUnitSelected(res['raw'] as CountdownUnit);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // --- PANEL SELECTION ---
                      if (_selectedUnit != null) ...[
                        _SearchFieldTile(
                          label: 'Panel / Section',
                          value: _selectedPanel?.sectionName,
                          hint: 'Pilih Panel di Unit ini',
                          onTap: () async {
                            final res = await jobPlanMasterSearchPicker(
                              context,
                              title: 'Pilih Panel',
                              items: _panels
                                  .map(
                                    (p) => {
                                      'id': p.panelId,
                                      'name': p.sectionName,
                                      'section': p.section,
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
                        const SizedBox(height: 12),
                      ],

                      // --- JOB SELECTION ---
                      if (_selectedPanel != null) ...[
                        _SearchFieldTile(
                          label: 'Pekerjaan (Jobdesc)',
                          value:
                              _selectedJobs.isEmpty
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
                                      'hours':
                                          '${j.remainingHours.toStringAsFixed(1)} jam sisa',
                                      'raw': j,
                                    },
                                  )
                                  .toList(),
                              initialSelectionIds:
                                  _selectedJobs.map((j) => j.id).toSet(),
                              labelBuilder: (m) => m['name'].toString(),
                              subtitleBuilder: (m) => m['hours'].toString(),
                            );
                            if (res != null) {
                              setState(() {
                                _selectedJobs.clear();
                                for (final item in res) {
                                  _selectedJobs.add(
                                    item['raw'] as CountdownJobdesc,
                                  );
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // --- PROJECT STATS ---
                      if (_selectedJobs.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
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
                                CountdownHelper.formatWorkHours(
                                  _selectedJobs.fold(
                                    0,
                                    (sum, j) => sum + j.targetHoursRevised,
                                  ),
                                ),
                              ),
                              _infoRow(
                                'Pekerjaan Terpilih',
                                '${_selectedJobs.length} item',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // --- INSTRUCTIONS ---
                      _FormSection(
                        title: 'Instruksi / SPOK',
                        child: TextField(
                          controller: _instructionCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Tulis instruksi kerja...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

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
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- SHIFT ---
                      _FormSection(
                        title: 'Jadwal & Target Jam',
                        child: Column(
                          children: [
                            DurationInput(
                              labelText: 'Target Jam Hari Ini',
                              initialHours: TimeParser.parseHHmmToDecimal(_hoursCtrl.text),
                              isTripleHours: false, // Always HH:mm for daily countdown target
                              onChanged: (val) {
                                setState(() {
                                  _hoursCtrl.text = TimeParser.formatDecimalToHHmm(
                                    val,
                                    isTriple: false,
                                  );
                                });
                                _finishTimeEdited = false;
                                _syncFinishTime();
                              },
                            ),
                            const SizedBox(height: 12),
                            _dateTile(),
                            const SizedBox(height: 8),
                            _timeRow(),
                            SwitchListTile.adaptive(
                              value: _isOvertime,
                              onChanged: (v) => setState(() => _isOvertime = v),
                              title: const Text(
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
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
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
                        child: Text(
                          _isSaving ? 'MENYIMPAN...' : 'SIMPAN KE DRAFT',
                          style: const TextStyle(
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
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
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: AppColors.gold),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tanggal Kerja',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
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
        const SizedBox(width: 12),
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
    this.isUrgent = false,
    this.isCountdown = false,
    this.initialDraft,
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

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 16, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;
  bool _isRework = false;
  bool _useFreeTextPanel = false;
  bool _useManualInput = false;

  static const _panelCategories = [
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
    _manualUnitCtrl.text = draft['unitName']?.toString() ?? '';
    _manualPanelCtrl.text = draft['panelName']?.toString() ?? '';
    final jobDesc = draft['jobDescription']?.toString() ?? '';
    if (jobDesc.isNotEmpty) _selectedJobs.add(jobDesc);

    _selectedDivision = draft['divisionName']?.toString() ?? '';
    _selectedEmployeeId = draft['assignedUserId']?.toString();
    _selectedDate = DateTime.tryParse(draft['taskDate'] ?? '') ?? _selectedDate;
    _hoursCtrl.text = TimeParser.formatDecimalToHHmm(
      (draft['targetHours'] as num?)?.toDouble() ?? 0.0,
    );

    final st = TimeParser.parseTimeOfDay(draft['startTime'] ?? '');
    if (st != null) _startTime = st;

    final ft = TimeParser.parseTimeOfDay(draft['finishTime'] ?? '');
    if (ft != null) {
      _finishTime = ft;
      _finishTimeEdited = true;
    }

    _isOvertime = draft['isOvertime'] == true;
    _isRework = draft['isRework'] == true;
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
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _finishTime = const TimeOfDay(hour: 16, minute: 0);
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
    final selectedEmployeeName =
        selectedEmployee?['name']?.toString() ??
        selectedEmployee?['full_name']?.toString() ??
        '-';

    if (_useManualInput) {
      if (manualUnit.isEmpty || manualPanel.isEmpty || manualJob.isEmpty) {
        AppNotification.showWarning(context, 'Lengkapi input manual.');
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

    final _effectiveSourceType = widget.isCountdown
        ? 'COUNTDOWN'
        : widget.isUrgent
        ? 'URGENT_ADDITIONAL'
        : 'ADDITIONAL';
    final sourceNote = <String>[
      'Sumber: $_effectiveSourceType',
      if (widget.isUrgent) 'Urgent: Ya',
      if (widget.isCountdown) 'Dari Countdown: Ya',
      _isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak',
      if (_noteCtrl.text.trim().isNotEmpty) 'SPOK: ${_noteCtrl.text.trim()}',
    ].join(' | ');

    try {
      final jobsToCreate = _useManualInput
          ? <String>{manualJob}
          : _selectedJobs;
      final draftSeed = DateTime.now().microsecondsSinceEpoch;
      var draftOffset = 0;
      if (widget.isUrgent) {
        for (final job in jobsToCreate) {
          await _repository.createPlan(
            coreId: '',
            carId: _useManualInput ? '' : selectedUnit!['id'].toString(),
            sourceType: _effectiveSourceType,
            sourceRefId: '',
            initialStatus: widget.isUrgent ? 'APPROVED' : null,
            syncToTasks: widget.isUrgent,
            isUrgent: widget.isUrgent,
            unitName: _useManualInput
                ? manualUnit
                : (selectedUnit?['unit_name']?.toString() ?? ''),
            panelName: _useManualInput
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
        final totalSessionHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text) ?? 0.0;
        final durationPerJob = totalSessionHours / jobsToCreate.length;
        
        TimeOfDay currentStartTime = _startTime;

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
            'carId': _useManualInput
                ? ''
                : (selectedUnit?['id']?.toString() ?? ''),
            'divisionId': divId,
            'panelId': null,
            'panelCustomNote': _useManualInput
                ? manualPanel
                : (_useFreeTextPanel ? null : (_selectedPanel ?? '')),
            'sectionName': _useFreeTextPanel
                ? _sectionNameCtrl.text.trim()
                : null,
            'panelCategory': (_useManualInput || _useFreeTextPanel)
                ? _selectedCategory
                : null,
            'addPanelToMaster': true,
            'jobTypeId': null,
            'sourceType': 'ADDITIONAL',
            'assignedUserId': _selectedEmployeeId!,
            'assignedUserName':
                selectedEmployee?['name']?.toString() ??
                selectedEmployee?['full_name']?.toString() ??
                '',
            'taskDate': _formatDate(_selectedDate),
            'jobDescription': job,
            'targetHours': durationPerJob,
            'totalProjectHours': () {
              final raw = _totalProjectHoursCtrl.text.trim();
              if (raw.isEmpty) return null;
              if (raw.contains(':')) {
                final parts = raw.split(':');
                final h = double.tryParse(parts[0]) ?? 0;
                final m =
                    double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
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
            'isOvertime': CountdownHelper.isOvertimeByTime(currentFinishTime, date: _selectedDate),
            'isRework': _isRework,
            'unitName': _useManualInput
                ? manualUnit
                : (selectedUnit?['unit_name']?.toString() ?? ''),
            'panelName': _useManualInput
                ? manualPanel
                : (_useFreeTextPanel
                      ? _sectionNameCtrl.text.trim()
                      : (_selectedPanel ?? '')),
          };

          newItems.addAll(TaskExecutionHelper.splitJobPlanItem(rawItem));
          currentStartTime = currentFinishTime;
          draftOffset++;
        }
        final uid = session.employeeId ?? '';
        final rejectedPlanId = (widget.initialDraft?['rejectedPlanId'] ?? '')
            .toString();
        final isReplacingDraft =
            rejectedPlanId.isNotEmpty || widget.editIndex != null;

        if (isReplacingDraft) {
          final existingDraft = await _repository.getDraft(userId: uid);
          final existingItems =
              (existingDraft?['items'] as List<dynamic>? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .map(Map<String, dynamic>.from)
                  .toList();
          existingItems.removeWhere(
            (t) => t['carId'] == null && t['panelId'] == null,
          );
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${newItems.length} pengerjaan disusun berurutan di Draft.')),
          );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan task: $e')));
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
        title: Text(widget.isUrgent ? 'Urgent Job' : 'Additional Job'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _FormSection(
                        title: 'Metode Input',
                        child: SwitchListTile.adaptive(
                          value: _useManualInput,
                          onChanged: (v) => setState(() => _useManualInput = v),
                          title: const Text(
                            'Input Nama Unit/Panel Manual',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          activeColor: AppColors.gold,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_useManualInput) ...[
                        _FormSection(
                          title: 'Detail Unit & Panel',
                          child: Column(
                            children: [
                              TextField(
                                controller: _manualUnitCtrl,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Nama Unit *',
                                  hintText: 'Contoh: MB 190 SL',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _manualPanelCtrl,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
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
                              const SizedBox(height: 12),
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
                                    });
                                    _loadDivisionStaff();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                    final drop =
                                        await _repository.getDropdowns(
                                          carId:
                                              _selectedUnit?['id']?.toString(),
                                        );
                                    if (!mounted) return;
                                    final res =
                                        await jobPlanMasterSearchPicker(
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
                                        () => _selectedPanel =
                                            res['name']?.toString(),
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
                                title: const Text(
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
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Section/Panel Baru *',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      _FormSection(
                        title: 'Detail Pekerjaan',
                        child: Column(
                          children: [
                            if (_useManualInput)
                              TextField(
                                controller: _manualJobCtrl,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Nama Pekerjaan *',
                                  hintText: 'Contoh: Turunkan Mesin',
                                ),
                              )
                            else
                              _SearchFieldTile(
                                label: 'Pekerjaan',
                                value:
                                    _selectedJobs.isEmpty
                                        ? null
                                        : _selectedJobs.length == 1
                                        ? _selectedJobs.first
                                        : '${_selectedJobs.length} job dipilih',
                                hint: 'Pilih Pekerjaan',
                                onTap: () async {
                                  final drop =
                                      await _repository.getDropdowns();
                                  final names = (drop['jobTypes'] as List)
                                      .map((e) => e['name'].toString())
                                      .toList();
                                  if (!mounted) return;
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
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceCard,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
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

                      const SizedBox(height: 16),

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
                            const SizedBox(height: 12),
                            DurationInput(
                              labelText: 'Target Jam Pengerjaan',
                              initialHours: TimeParser.parseHHmmToDecimal(_hoursCtrl.text),
                              onChanged: (val) {
                                setState(() {
                                  _hoursCtrl.text = TimeParser.formatDecimalToHHmm(val, isTriple: false);
                                  _finishTimeEdited = false;
                                  _syncFinishTimeFromHours();
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: _applyStandardWorkday,
                                child: const Text(
                                  'Set jam kerja normal 8 jam',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Total Project Hours + Timeline ──────────────────
                      _FormSection(
                        title: 'Target Proyek',
                        child: Column(
                          children: [
                            TextField(
                              controller: _totalProjectHoursCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [HHHMMFormatter()],
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Total Target Proyek (000:00)',
                                hintText:
                                    'Contoh: 180:00 (kosongkan = sama dgn target harian)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
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
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    trailing: const Icon(
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
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
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    trailing: const Icon(
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
                                              const Duration(days: 7),
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
                      const SizedBox(height: 16),
                      _FormSection(
                        title: 'Jadwal Harian',
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Tanggal Pengerjaan',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              trailing: const Icon(
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
                              const SizedBox(height: 4),
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
                                            final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
                                            if (targetHours != null && targetHours > 0) {
                                              _finishTime = _calculateFinishTime(
                                                startTime: _startTime,
                                                durationHours: targetHours,
                                                date: _selectedDate,
                                              );
                                            }
                                          }
                                          _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime, date: _selectedDate);
                                        });
                                      },
                                      onTapIcon: () async {
                                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                                        if (picked != null) {
                                          setState(() {
                                            _startTime = picked;
                                            if (!_finishTimeEdited) {
                                              final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
                                              if (targetHours != null && targetHours > 0) {
                                                _finishTime = _calculateFinishTime(
                                                  startTime: _startTime,
                                                  durationHours: targetHours,
                                                  date: _selectedDate,
                                                );
                                              }
                                            }
                                            _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime, date: _selectedDate);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ClockTimeInput(
                                      labelText: 'Jam Selesai',
                                      initialTime: _finishTime,
                                      onChanged: (t) {
                                        setState(() {
                                          _finishTime = t;
                                          _finishTimeEdited = true;
                                          _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime, date: _selectedDate);
                                        });
                                      },
                                      onTapIcon: () async {
                                        final picked = await showTimePicker(context: context, initialTime: _finishTime);
                                        if (picked != null) {
                                          setState(() {
                                            _finishTime = picked;
                                            _finishTimeEdited = true;
                                            _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime, date: _selectedDate);
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
                                activeColor: AppColors.gold,
                                title: const Text(
                                  'Jam lembur',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              CheckboxListTile.adaptive(
                                value: _isRework,
                                onChanged: (v) =>
                                    setState(() => _isRework = v ?? false),
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
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

                        const SizedBox(height: 16),

                        _FormSection(
                          title: 'Catatan Rencana',
                          child: TextField(
                            controller: _noteCtrl,
                            maxLines: 2,
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Tulis catatan khusus (opsional)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Submit bar ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceCard,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed:
                              _isSaving
                                  ? null
                                  : () => _save(_selectedUnit, selectedEmployee),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                          ),
                          child: Text(
                            _isSaving ? 'MENYIMPAN...' : 'SIMPAN KE DRAFT',
                            style: const TextStyle(
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
            const Padding(
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
                  ? const Center(
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${wo.jobDetail}\nPanel: ${wo.panelName ?? '-'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
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
  const _PlanSourceSeed({
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
  late final SessionManager _session;

  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _jobdescCtrl = TextEditingController();
  final TextEditingController _panelCtrl = TextEditingController();
  final TextEditingController _hoursCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _employees = [];
  String? _selectedEmployeeId;

  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 16, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
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
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _finishTime = const TimeOfDay(hour: 17, minute: 0);
      _finishTimeEdited = false;
      _isOvertime = false;
    });
  }

  Future<void> _save(String selectedEmployeeName) async {
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap pilih pelaksana.')),
      );
      return;
    }
    if (_jobdescCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jobdesc tidak boleh kosong.')),
      );
      return;
    }
    if (targetHours == null || targetHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target hours harus valid dan lebih dari 0.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final sourceNote = <String>[
      'Sumber: ${widget.seed.sourceLabel}',
      _isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak',
      if (_noteCtrl.text.trim().isNotEmpty) 'SPOK: ${_noteCtrl.text.trim()}',
    ].join(' | ');

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
        'draftItemId':
            'draft_${DateTime.now().microsecondsSinceEpoch}',
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

      if (!mounted) return;
      Navigator.pop(context, true);
      AppNotification.showSuccess(context, 'Tersimpan di Draft.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan task: $e')));
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
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _FormSection(
                        title: 'Info Sumber',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
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
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Unit: ${widget.seed.unitName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FormSection(
                        title: 'Panel & Jobdesc',
                        child: Column(
                          children: [
                            TextField(
                              controller: _panelCtrl,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Panel / Section *',
                                hintText: 'Nama panel atau section',
                                prefixIcon: Icon(
                                  Icons.layers_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _jobdescCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
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
                      const SizedBox(height: 12),
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
                            const SizedBox(height: 12),
                            DurationInput(
                              labelText: 'Target Jam Pengerjaan',
                              initialHours: TimeParser.parseHHmmToDecimal(_hoursCtrl.text),
                              onChanged: (val) {
                                setState(() {
                                  _hoursCtrl.text = TimeParser.formatDecimalToHHmm(val, isTriple: false);
                                  _finishTimeEdited = false;
                                  _syncFinishTimeFromHours();
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                onPressed: _applyStandardWorkday,
                                child: const Text(
                                  'Set jam kerja normal 8 jam',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FormSection(
                        title: 'Jadwal',
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Tanggal Pengerjaan',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              trailing: const Icon(
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
                            const SizedBox(height: 4),
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
                                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                                      if (picked != null) {
                                        setState(() {
                                          _startTime = picked;
                                          _syncFinishTimeFromHours();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ClockTimeInput(
                                    labelText: 'Selesai',
                                    initialTime: _finishTime,
                                    onChanged: (t) {
                                      setState(() {
                                        _finishTime = t;
                                        _finishTimeEdited = true;
                                        _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime, date: _selectedDate);
                                      });
                                    },
                                    onTapIcon: () async {
                                      final picked = await showTimePicker(context: context, initialTime: _finishTime);
                                      if (picked != null) {
                                        setState(() {
                                          _finishTime = picked;
                                          _finishTimeEdited = true;
                                          _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime, date: _selectedDate);
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
                              activeColor: AppColors.gold,
                              title: const Text(
                                'Jam lembur',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FormSection(
                        title: 'Catatan Rencana',
                        child: TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Tulis catatan khusus (SPOK)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed:
                            _isSaving ? null : () => _save(selectedEmployeeName),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                        ),
                        child: Text(
                          _isSaving ? 'MENYIMPAN...' : 'SIMPAN KE DRAFT',
                          style: const TextStyle(
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.gold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
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
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalTab extends StatelessWidget {
  const _ApprovalTab({
    required this.isLoading,
    required this.plans,
    required this.onRefresh,
    required this.onShowDetail,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.bulkActionBar,
  });

  final bool isLoading;
  final List<JobPlan> plans;
  final Future<void> Function() onRefresh;
  final void Function(JobPlan) onShowDetail;
  final Set<String> selectedIds;
  final void Function(String, bool) onSelectionChanged;
  final Widget bulkActionBar;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (plans.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('Tidak ada antrian approval.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: plans.length,
              itemBuilder: (ctx, i) {
                final plan = plans[i];
                final isSelected = selectedIds.contains(plan.planId);
                return _ApprovalPlanCard(
                  plan: plan,
                  onTap: () => onShowDetail(plan),
                  isSelected: isSelected,
                  onSelectionChanged: (val) =>
                      onSelectionChanged(plan.planId, val ?? false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalPlanCard extends StatelessWidget {
  const _ApprovalPlanCard({
    required this.plan,
    required this.onTap,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  final JobPlan plan;
  final VoidCallback onTap;
  final bool isSelected;
  final ValueChanged<bool?> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final role = sl<SessionManager>().role;
    final canSelect = _canReviewApprovalStatus(role, plan.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.all(12),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            plan.assignedTo,
                            style: const TextStyle(
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      'PENDING_PM' => Colors.blue,
      'APPROVED' => AppColors.statusDone,
      'REJECTED' => AppColors.statusLocked,
      _ => AppColors.textMuted,
    };
  }

  String _resolveLabel(String s) {
    return switch (s.toUpperCase()) {
      'PENDING_ADV' => 'ADV',
      'PENDING_PM' => 'PM',
      'APPROVED' => 'ACC',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
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
  const _BrowseTab({required this.initialDate, required this.onParamsChanged});
  final DateTime initialDate;
  final void Function(DateTime, String?, String?) onParamsChanged;

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  late final JobPlanRepository _repository;
  late final SessionManager _session;

  bool _isLoading = true;
  List<JobPlan> _plans = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _session = sl<SessionManager>();
    _selectedDate = widget.initialDate;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final res = await _repository.browsePlans(taskDate: dateStr);
    res.fold<void>(
      (failure) {
        if (mounted) setState(() => _isLoading = false);
      },
      (data) {
        if (mounted) {
          setState(() {
            _plans = data;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DateFilterBar(
            selectedDate: _selectedDate,
            onDateChanged: (dt) {
              setState(() => _selectedDate = dt);
              widget.onParamsChanged(_selectedDate, null, null);
              _fetch();
            },
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                  : _plans.isEmpty
                  ? const Center(child: Text('Tidak ada rencana kerja.'))
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _plans.length,
                    itemBuilder: (ctx, i) => _SubmittedPlanCard(plan: _plans[i]),
                  ),
        ),
      ],
    );
  }
}

class _SubmittedPlanCard extends StatelessWidget {
  const _SubmittedPlanCard({required this.plan});
  final JobPlan plan;

  @override
  Widget build(BuildContext context) {
    final isOt = plan.isOvertime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.unitName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isOt)
                  const Icon(
                    Icons.nights_stay_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                const SizedBox(width: 8),
                _StatusChip(status: plan.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  plan.assignedTo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  plan.targetHoursAlias ?? _formatHours(plan.targetHours),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
