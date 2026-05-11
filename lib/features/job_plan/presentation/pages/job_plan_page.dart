/*
Tujuan: Halaman job plan untuk approval queue dan rencana/draft creator.
Caller: Route /plans, dashboard management, dan task section plan.
Dependensi: RBAC, SessionManager, JobPlanRepository, WorkOrderRepository, DateFilterBar.
Main Functions: _loadPlans, _showCreateSourceSheet, _showAdditionalTaskDialog, BrowseTab.
Side Effects: HTTP GET/POST/PUT job plan, navigasi ke source route, refresh approval dan browse state.
*/
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';
import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';

import '../../../work_order/domain/repositories/work_order_repository.dart';
import '../../../work_order/domain/entities/work_order.dart';

import '../../../../core/widgets/clock_time_input.dart';
import '../../../../core/widgets/duration_input.dart';
import '../../../../core/utils/time_parser.dart';
import '../../../countdown/domain/entities/countdown_entities.dart';
import '../../../countdown/domain/repositories/countdown_repository.dart';
import '../../../countdown/presentation/utils/countdown_helper.dart';
import '../../../task_execution/presentation/utils/task_execution_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';

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
    'adv' => status == 'PENDING_ADV',
    'advisor' => status == 'PENDING_ADV',
    'kp' ||
    'kepala_project' ||
    'kepala project' ||
    'kepala_produksi' => status == 'PENDING_KP',
    'mp' => status == 'PENDING_MP',
    'manager_project' => status == 'PENDING_MP',
    'manager project' => status == 'PENDING_MP',
    'manager_produksi' => status == 'PENDING_MP',
    'pm' => status == 'PENDING_MP' || status == 'PENDING_KP',
    _ => false,
  };
}

Future<Map<String, dynamic>?> jobPlanMasterSearchPicker(
  BuildContext context, {
  required String title,
  required List<Map<String, dynamic>> items,
  required String Function(Map<String, dynamic> item) labelBuilder,
  required String Function(Map<String, dynamic> item) subtitleBuilder,
}) async {
  var query = '';
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final filteredItems = items.where((item) {
          final label = labelBuilder(item).toLowerCase();
          final subtitle = subtitleBuilder(item).toLowerCase();
          final normalizedQuery = query.toLowerCase();
          return label.contains(normalizedQuery) ||
              subtitle.contains(normalizedQuery);
        }).toList();
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
                      labelText: 'Cari',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data yang cocok.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: AppColors.border),
                            itemBuilder: (_, index) {
                              final item = filteredItems[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  labelBuilder(item),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitleBuilder(item),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
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
                              setSheetState(() {
                                selected.add(query.trim());
                              });
                              // Keep sheet open so they can add more, or clear query
                              query = '';
                            },
                          );
                        }

                        if (index >= filteredItems.length) {
                          return const SizedBox();
                        }

                        final job = filteredItems[index];
                        final isChecked = selected.contains(job);
                        return CheckboxListTile(
                          value: isChecked,
                          activeColor: AppColors.gold,
                          checkColor: AppColors.background,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            job,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                selected.add(job);
                              } else {
                                selected.remove(job);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, selected),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.background,
                          ),
                          child: Text('Pilih (${selected.length})'),
                        ),
                      ),
                    ],
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

Future<String?> jobPlanSimpleValuePicker(
  BuildContext context, {
  required String title,
  required List<String> items,
}) async {
  var query = '';
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final filteredItems = items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.8,
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
                      labelText: 'Cari',
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
                            onTap: () => Navigator.pop(ctx, query.trim()),
                          );
                        }

                        if (index >= filteredItems.length) {
                          return const SizedBox();
                        }

                        final item = filteredItems[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onTap: () => Navigator.pop(ctx, item),
                        );
                      },
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

Future<Map<String, dynamic>?> jobPlanEmployeePicker(
  BuildContext context,
  List<Map<String, dynamic>> employees,
) async {
  var query = '';
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final filteredItems = employees.where((item) {
          final name = ((item['name'] ?? item['full_name'] ?? '') as String)
              .toLowerCase();
          final grade = (item['grade']?.toString() ?? '').toLowerCase();
          final normalizedQuery = query.toLowerCase();
          return name.contains(normalizedQuery) ||
              grade.contains(normalizedQuery);
        }).toList();
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
                  const Text(
                    'Pilih Pelaksana',
                    style: TextStyle(
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
                      labelText: 'Cari',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data yang cocok.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: AppColors.border),
                            itemBuilder: (_, index) {
                              final item = filteredItems[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  (item['name'] ?? item['full_name'] ?? '')
                                      .toString(),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  item['grade']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
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

class JobPlanPage extends StatefulWidget {
  const JobPlanPage({
    super.key,
    this.initialDate,
    this.initialSourceType,
    this.initialSourceRefId,
    this.autoOpenCreate = false,
  });

  final DateTime? initialDate;
  final String? initialSourceType;
  final String? initialSourceRefId;
  final bool autoOpenCreate;

  @override
  State<JobPlanPage> createState() => _JobPlanPageState();
}

class _JobPlanPageState extends State<JobPlanPage>
    with SingleTickerProviderStateMixin {
  late final JobPlanRepository _repository;
  late final TabController _tabController;
  late final bool _showPlanTab;
  late final bool _canCreateFromPage;
  late DateTime _selectedDate;
  List<JobPlan> _plans = [];
  List<Map<String, dynamic>> _approvalItems = [];
  bool _isLoading = true;
  bool _isBulkApproving = false;
  bool _didHandleInitialSource = false;
  final _browseKey = GlobalKey<_BrowseTabState>();
  final Set<String> _selectedApprovalPlanIds = <String>{};
  String? _selectedApprovalDivisionId;
  String? _selectedApprovalDivisionName;
  String? _selectedApprovalUnitId;
  String? _selectedApprovalUnitName;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    final session = sl<SessionManager>();
    final isKpApprovalOnly = _isKpRole(session);
    final isMpApprovalOnly = _isMpRole(session);
    _showPlanTab = !isKpApprovalOnly && !isMpApprovalOnly;
    _canCreateFromPage = hasPermission(session.role, Permission.jobPlanCreate);
    _tabController = TabController(
      length: _showPlanTab ? 2 : 1,
      vsync: this,
      initialIndex: _showPlanTab && _canCreateFromPage ? 1 : 0,
    );
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadPlans();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialCreateFlow();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _selectedDateStr =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  SessionManager get _session => sl<SessionManager>();

  String? get _currentRole => _session.role;

  bool get _canCurrentUserReviewPlans =>
      hasPermission(_session.role, Permission.jobPlanReview) ||
      _isKpRole(_session) ||
      _isMpRole(_session);

  Future<void> _loadPlans() async {
    try {
      final items = await _repository.getApprovalQueue(
        divisionId: _selectedApprovalDivisionId,
        unitId: _selectedApprovalUnitId,
        taskDate: _selectedDateStr,
        limit: 200,
      );
      final plans = items
          .where((item) => (item['planId'] ?? '').toString().isNotEmpty)
          .map(_jobPlanFromMap)
          .toList();
      if (!mounted) return;
      final visiblePlanIds = plans.map((plan) => plan.planId).toSet();
      setState(() {
        _approvalItems = items;
        _plans = plans;
        _selectedApprovalPlanIds.removeWhere(
          (planId) => !visiblePlanIds.contains(planId),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _approvalItems = [];
        _plans = [];
        _selectedApprovalPlanIds.clear();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat approval plan: $e'),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
    }
  }

  bool _isReviewablePlan(JobPlan plan) {
    return _canCurrentUserReviewPlans &&
        _canReviewApprovalStatus(_currentRole, plan.status);
  }

  Map<String, dynamic>? _findApprovalPlanRaw(String planId) {
    for (final item in _approvalItems) {
      if ((item['planId'] ?? '').toString() == planId) {
        return item;
      }
    }
    return null;
  }

  void _toggleApprovalPlanSelection(String planId, bool selected) {
    setState(() {
      if (selected) {
        _selectedApprovalPlanIds.add(planId);
      } else {
        _selectedApprovalPlanIds.remove(planId);
      }
    });
  }

  void _toggleSelectAllApprovalPlans() {
    final reviewablePlanIds = _plans
        .where(_isReviewablePlan)
        .map((plan) => plan.planId)
        .toList();
    if (reviewablePlanIds.isEmpty) return;
    final areAllSelected = reviewablePlanIds.every(
      _selectedApprovalPlanIds.contains,
    );
    setState(() {
      if (areAllSelected) {
        _selectedApprovalPlanIds.removeAll(reviewablePlanIds);
      } else {
        _selectedApprovalPlanIds.addAll(reviewablePlanIds);
      }
    });
  }

  Future<void> _approveSelectedPlans() async {
    if (_isBulkApproving) return;
    final selectedPlans = _plans
        .where(
          (plan) =>
              _selectedApprovalPlanIds.contains(plan.planId) &&
              _isReviewablePlan(plan),
        )
        .toList();
    if (selectedPlans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu plan untuk disetujui.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Setujui Beberapa Plan',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Setujui ${selectedPlans.length} plan yang sedang dipilih?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBulkApproving = true);
    final failedPlanIds = <String>[];
    var approvedCount = 0;
    for (final plan in selectedPlans) {
      try {
        await _repository.approvePlan(
          planId: plan.planId,
          userId: _session.employeeId ?? '',
        );
        approvedCount += 1;
      } catch (_) {
        failedPlanIds.add(plan.planId);
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
                    label: 'Instruksi / POK',
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
            onChanged: _isBulkApproving
                ? null
                : (_) => _toggleSelectAllApprovalPlans(),
            activeColor: AppColors.gold,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            selectedCount == 0 ? 'Pilih Semua' : '$selectedCount terpilih',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selectedCount > 0 ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          const Spacer(),
          if (selectedCount > 0)
            TextButton.icon(
              onPressed: _isBulkApproving ? null : _approveSelectedPlans,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              icon: _isBulkApproving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all_rounded, size: 16),
              label: const Text(
                'ACC SELESAI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleInitialCreateFlow() async {
    if (_didHandleInitialSource || !widget.autoOpenCreate || !mounted) return;
    _didHandleInitialSource = true;
    final canCreate = hasPermission(
      sl<SessionManager>().role,
      Permission.jobPlanCreate,
    );
    if (!canCreate) return;

    final sourceType = widget.initialSourceType?.toUpperCase();
    if (sourceType == 'WO') {
      await _showWorkOrderSourceDialog(
        context,
        sourceRefId: widget.initialSourceRefId,
        openDirectIfSingle: true,
      );
      return;
    }
    if (sourceType == 'COUNTDOWN') {
      await _showCountdownTaskDialog(context);
      return;
    }
    await _showCreateSourceSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final role = session.role;
    final isKpApprovalOnly = _isKpRole(session);
    final isMpApprovalOnly = _isMpRole(session);
    final canCreate = hasPermission(role, Permission.jobPlanCreate);
    final canReview =
        hasPermission(role, Permission.jobPlanReview) ||
        isKpApprovalOnly ||
        isMpApprovalOnly;
    final showPlanTab = !isKpApprovalOnly && !isMpApprovalOnly;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TabBar(
        controller: _tabController,
        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.gold,
        tabs: [
          const Tab(text: "Approval Plan"),
          if (showPlanTab) const Tab(text: "Rencana"),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Main Queue
              _buildApprovalPlanTab(role: role, canReview: canReview),

              // TAB 2: Draft Cart + Browse
              if (showPlanTab)
                BrowseTab(
                  key: _browseKey,
                  selectedDate: _selectedDate,
                  onDateChanged: (date) {
                    setState(() => _selectedDate = date);
                  },
                  onSubmitted: () {
                    setState(() => _isLoading = true);
                    _loadPlans();
                  },
                ),
            ],
          ),
          if (canCreate && showPlanTab)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _showCreateSourceSheet(context),
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Create Task'),
              ),
            ),
        ],
      ),
    );
  }

  void _openPlanTabIfAvailable() {
    if (!_showPlanTab) return;
    _tabController.animateTo(1);
  }

  bool _isKpRole(SessionManager session) {
    final role = (session.role ?? '').trim().toLowerCase();
    final jabatan = (session.jabatan ?? '').trim().toLowerCase();
    return role == 'kp' ||
        role == 'kepala_project' ||
        role == 'kepala project' ||
        role == 'kepala_produksi' ||
        (role == 'pm' && jabatan.contains('kepala project'));
  }

  bool _isMpRole(SessionManager session) {
    final role = (session.role ?? '').trim().toLowerCase();
    final jabatan = (session.jabatan ?? '').trim().toLowerCase();
    return role == 'mp' ||
        role == 'manager_project' ||
        role == 'manager project' ||
        role == 'manager_produksi' ||
        (role == 'pm' && !jabatan.contains('kepala project'));
  }

  Widget _buildApprovalPlanTab({
    required String? role,
    required bool canReview,
  }) {
    final isPlanLevel =
        _selectedApprovalDivisionId != null && _selectedApprovalUnitId != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DateFilterBar(
            selectedDate: _selectedDate,
            onDateChanged: (date) async {
              setState(() {
                _selectedDate = date;
                _isLoading = true;
              });
              await _loadPlans();
            },
            label: 'Approval',
          ),
        ),
        if (_selectedApprovalDivisionId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedApprovalDivisionId = null;
                      _selectedApprovalDivisionName = null;
                      _selectedApprovalUnitId = null;
                      _selectedApprovalUnitName = null;
                      _isLoading = true;
                    });
                    _loadPlans();
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(_selectedApprovalDivisionName ?? 'Divisi'),
                ),
                if (_selectedApprovalUnitId != null) ...[
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedApprovalUnitId = null;
                        _selectedApprovalUnitName = null;
                        _isLoading = true;
                      });
                      _loadPlans();
                    },
                    child: Text(_selectedApprovalUnitName ?? 'Unit'),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadPlans,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_approvalItems.isEmpty)
                        _buildEmptyState()
                      else if (!isPlanLevel)
                        ..._approvalItems.map(_buildApprovalLevelTile)
                      else ...[
                        if (canReview) _buildApprovalBulkActionBar(),
                        ..._plans.map(
                          (plan) => _ApprovalPlanCard(
                            plan: plan,
                            role: role,
                            canReview: canReview,
                            selected: _selectedApprovalPlanIds.contains(
                              plan.planId,
                            ),
                            showSelection: _isReviewablePlan(plan),
                            isBusy: _isBulkApproving,
                            onSelectedChanged: (selected) =>
                                _toggleApprovalPlanSelection(
                                  plan.planId,
                                  selected ?? false,
                                ),
                            onOpenDetail: () => _showApprovalPlanDetail(plan),
                            onApprove: () => _approvePlan(plan.planId),
                            onReject: () => _showRejectDialog(plan),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildApprovalLevelTile(Map<String, dynamic> item) {
    final isDivisionLevel = _selectedApprovalDivisionId == null;
    final id =
        (item['id'] ??
                item['divisionId'] ??
                item['division_id'] ??
                item['unitId'] ??
                item['unit_id'] ??
                '')
            .toString();
    final name =
        (item['name'] ??
                item['divisionName'] ??
                item['division_name'] ??
                item['unitName'] ??
                item['unit_name'] ??
                '-')
            .toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          isDivisionLevel ? 'Divisi' : 'Unit',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        onTap: () {
          setState(() {
            if (isDivisionLevel) {
              _selectedApprovalDivisionId = id;
              _selectedApprovalDivisionName = name;
              _selectedApprovalUnitId = null;
              _selectedApprovalUnitName = null;
            } else {
              _selectedApprovalUnitId = id;
              _selectedApprovalUnitName = name;
            }
            _isLoading = true;
          });
          _loadPlans();
        },
      ),
    );
  }

  JobPlan _jobPlanFromMap(Map<String, dynamic> item) {
    return JobPlan(
      planId: _pickJobPlanText([item['planId']]),
      coreId: _pickJobPlanText([item['coreId']]),
      carId: _pickJobPlanText([item['carId']]),
      sourceType: _pickJobPlanText([item['sourceType']], 'ADDITIONAL'),
      sourceRefId: _pickJobPlanText([item['sourceRefId']]),
      unitName: _pickJobPlanText([item['unitName'], item['unit_name']], '-'),
      panelName: _pickJobPlanText([
        item['panelName'],
        item['panel_name'],
        item['panelSectionName'],
        item['panelSection'],
      ], '-'),
      assignedDivision: _pickJobPlanText([
        item['assignedDivision'],
        item['divisionName'],
        item['division_name'],
      ]),
      assignedUserId: _pickJobPlanText([item['assignedUserId']]),
      assignedTo: _pickJobPlanText([
        item['assignedTo'],
        item['assignedUserName'],
        item['assigned_user_name'],
      ], '-'),
      description: _pickJobPlanText([
        item['description'],
        item['jobdescription'],
        item['jobDescription'],
      ]),
      targetHours:
          double.tryParse(_pickJobPlanText([item['targetHours']], '0')) ?? 0,
      workDate: _pickJobPlanText([item['workDate'], item['taskDate']]),
      startTime: _pickJobPlanText([item['startTime']], '08:00'),
      finishTime: _pickJobPlanText([item['finishTime']], '16:00'),
      isOvertime: _truthy(item['isOvertime']),
      deadline: _pickJobPlanText([
        item['deadline'],
        item['taskDate'],
        item['workDate'],
      ]),
      status: _pickJobPlanText([item['status']]),
      note: _pickJobPlanText([item['note'], item['catatan'], item['pok']]),
      panelCustomNote: _pickNullableJobPlanText([
        item['panelCustomNote'],
        item['panelSectionName'],
        item['panelSection'],
      ]),
      rejectNote: _pickNullableJobPlanText([
        item['rejectNote'],
        item['reject_note'],
      ]),
      targetHoursAlias: _pickNullableJobPlanText([
        item['targetHours_alias'],
        item['targetHoursAlias'],
      ]),
      remainingHoursAlias: _pickNullableJobPlanText([
        item['remainingHours_alias'],
        item['remainingHoursAlias'],
      ]),
    );
  }

  Future<void> _approvePlan(String planId) async {
    await _repository.approvePlan(
      planId: planId,
      userId: sl<SessionManager>().employeeId ?? '',
    );
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadPlans();
  }

  Future<void> _showRejectDialog(JobPlan plan) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Tolak Plan',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: noteCtrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Catatan penolakan',
            labelStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = noteCtrl.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx, value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusLocked,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (note == null || note.trim().isEmpty) return;
    await _repository.rejectPlan(
      planId: plan.planId,
      userId: sl<SessionManager>().employeeId ?? '',
      rejectNote: note.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadPlans();
  }

  // Create/review hint builder removed from UI on purpose to keep the page cleaner.

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 48,
            color: AppColors.textDisabled,
          ),
          SizedBox(height: 12),
          Text(
            'Tidak ada plan pada tanggal ini',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          // Empty-state helper text intentionally hidden from UI.
        ],
      ),
    );
  }

  Future<void> _showCreateSourceSheet(BuildContext context) async {
    final sourceType = widget.initialSourceType?.toUpperCase();
    if (sourceType == 'WO') {
      await _showWorkOrderSourceDialog(
        context,
        sourceRefId: widget.initialSourceRefId,
      );
      return;
    }
    if (sourceType == 'COUNTDOWN') {
      context.go('/countdown');
      return;
    }

    // 'Tambahan Urgent' hanya untuk KP/MP/ADV/Admin — bukan KD
    final rawRole = sl<SessionManager>().role?.trim().toLowerCase() ?? '';
    final isKd =
        rawRole == 'kd' ||
        rawRole == 'ketua_divisi' ||
        rawRole == 'kepala_divisi';
    final canUrgent = !isKd;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Sumber Task',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Task baru bisa dari countdown, work order aktif, atau tambahan (regular/urgent).',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.directions_car_outlined,
                title: 'Dari Countdown',
                subtitle: 'Isi form berdasarkan countdown unit.',
                onTap: () {
                  Navigator.pop(ctx);
                  _showCountdownTaskDialog(context);
                },
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.assignment_outlined,
                title: 'Dari Work Order',
                subtitle: 'WO/WOV yang belum selesai atau masih berjalan.',
                onTap: () {
                  Navigator.pop(ctx);
                  _showWorkOrderSourceDialog(context);
                },
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.playlist_add_circle_outlined,
                title: 'Tambahan',
                subtitle:
                    'Input job baru dengan dropdown unit, panel, dan job sesuai master DB.',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdditionalTaskDialog(context);
                },
              ),
              if (canUrgent) ...[
                const SizedBox(height: 10),
                _SourceTile(
                  icon: Icons.priority_high_rounded,
                  title: 'Tambahan Urgent',
                  subtitle:
                      'Langsung masuk ke task pelaksana tanpa menunggu review plan.',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAdditionalTaskDialog(context, isUrgent: true);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkOrderSourceDialog(
    BuildContext context, {
    String? sourceRefId,
    bool openDirectIfSingle = false,
  }) async {
    final session = sl<SessionManager>();
    final currentDivision = (session.divisionName ?? '').trim().toUpperCase();
    final currentDivisionId = session.divisionId?.toString() ?? '';

    final workOrderRepo = sl<WorkOrderRepository>();
    final allWoEither = await workOrderRepo.getWorkOrders(view: 'ACTIVE');
    final allWo = allWoEither.fold((_) => <WorkOrder>[], (r) => r);

    final items = allWo
        .where((wo) => wo.isReadyForJobdesc)
        .where((wo) {
          final divNameMatch =
              wo.toDivName.trim().toUpperCase() == currentDivision;
          final divIdMatch =
              currentDivisionId.isNotEmpty &&
              wo.toDivId.trim() == currentDivisionId;
          return divNameMatch || divIdMatch;
        })
        .map(
          (wo) => _PlanSourceSeed(
            sourceLabel: 'WO',
            sourceType: 'WO',
            sourceRefId: wo.id,
            sourceRoute: '/work-orders?woId=${wo.id}',
            carId: wo.carId,
            coreId: wo.coreId ?? '',
            unitName: wo.unitName,
            panelName: wo.panelName ?? '-',
            assignedDivision: wo.toDivName,
            description: wo.jobDetail,
            targetHours: wo.estimatedHours ?? 0.0,
            picId: wo.picId,
          ),
        )
        .toList();
    final filteredItems = sourceRefId == null || sourceRefId.isEmpty
        ? items
        : items.where((item) => item.sourceRefId == sourceRefId).toList();

    if (!context.mounted) return;
    await _showSourceSelectionDialog(
      context,
      title: 'Pilih Work Order Aktif',
      items: filteredItems,
      openDirectIfSingle: openDirectIfSingle,
    );
  }

  Future<void> _showSourceSelectionDialog(
    BuildContext context, {
    required String title,
    required List<_PlanSourceSeed> items,
    bool openDirectIfSingle = false,
  }) async {
    if (openDirectIfSingle && items.length == 1) {
      await _showPlanFormDialog(context, seed: items.first);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 520,
          child: items.isEmpty
              ? const Text(
                  'Tidak ada sumber task yang tersedia.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.border),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.unitName} • ${item.panelName}',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        '${item.sourceLabel} • ${item.description}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      trailing: Text(
                        '${item.targetHours.toStringAsFixed(1)}h',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showPlanFormDialog(context, seed: item);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdditionalTaskDialog(
    BuildContext context, {
    bool isUrgent = false,
  }) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: _AdditionalPlanFormPage(
          initialDate: _selectedDate,
          isUrgent: isUrgent,
        ),
      ),
    );
    if (created == true) {
      _openPlanTabIfAvailable();
      setState(() => _isLoading = true);
      await _loadPlans();
      await _browseKey.currentState?.refresh();
    }
  }

  Future<void> _showCountdownTaskDialog(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: _CountdownPlanFormPage(initialDate: _selectedDate),
      ),
    );
    if (created == true) {
      _openPlanTabIfAvailable();
      setState(() => _isLoading = true);
      await _loadPlans();
      await _browseKey.currentState?.refresh();
    }
  }

  Future<void> _showPlanFormDialog(
    BuildContext context, {
    required _PlanSourceSeed seed,
  }) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: _SourcePlanFormPage(seed: seed, initialDate: _selectedDate),
      ),
    );
    if (created == true && context.mounted) {
      _openPlanTabIfAvailable();
      setState(() => _isLoading = true);
      await _loadPlans();
      await _browseKey.currentState?.refresh();
      if (!context.mounted) return;
      context.go(seed.sourceRoute);
    }
  }
}

class _ApprovalPlanCard extends StatelessWidget {
  const _ApprovalPlanCard({
    required this.plan,
    required this.role,
    required this.canReview,
    required this.selected,
    required this.showSelection,
    required this.isBusy,
    required this.onSelectedChanged,
    required this.onOpenDetail,
    required this.onApprove,
    required this.onReject,
  });

  final JobPlan plan;
  final String? role;
  final bool canReview;
  final bool selected;
  final bool showSelection;
  final bool isBusy;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onOpenDetail;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = plan.status;
    final canReviewThis = canReview && _canReviewApprovalStatus(role, status);
    final isOt = plan.isOvertime;
    final accentColor = isOt ? AppColors.orange : AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenDetail,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header: Checkbox + Status + Date ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      if (showSelection)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: selected,
                            onChanged: isBusy ? null : onSelectedChanged,
                            activeColor: AppColors.gold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(plan.status).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        plan.workDate,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),

                // --- Main Info ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_pin_rounded,
                            size: 16,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.assignedTo.isNotEmpty
                                  ? plan.assignedTo
                                  : 'Belum Assigned',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.panelName.isNotEmpty ? plan.panelName : '-',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.description.isNotEmpty ? plan.description : '-',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // --- Meta Row: Time & Duration ---
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: AppColors.background.withValues(alpha: 0.4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${plan.startTime} – ${plan.finishTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        plan.targetHoursAlias ?? _formatHours(plan.targetHours),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isOt)
                        const Text(
                          'LEMBUR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.orange,
                          ),
                        ),
                    ],
                  ),
                ),

                // --- Action Buttons ---
                if (canReviewThis) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isBusy ? null : onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.statusLocked,
                              side: const BorderSide(
                                color: AppColors.statusLocked,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'TOLAK',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isBusy ? null : onApprove,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'SETUJUI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PlanSourceSeed {
  const _PlanSourceSeed({
    required this.sourceLabel,
    required this.sourceType,
    required this.sourceRefId,
    required this.sourceRoute,
    required this.carId,
    required this.coreId,
    required this.unitName,
    required this.panelName,
    required this.assignedDivision,
    required this.description,
    required this.targetHours,
    this.picId,
  });

  final String sourceLabel;
  final String sourceType;
  final String sourceRefId;
  final String sourceRoute;
  final String carId;
  final String coreId;
  final String unitName;
  final String panelName;
  final String assignedDivision;
  final String description;
  final double targetHours;
  final String? picId;
}

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
  CountdownJobdesc? _selectedJob;
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
      _selectedJob = null;
      _panels = [];
      _jobdescs = [];
      _isLoading = true;
    });

    try {
      // Need division ID. Usually we take current user's division for job plan context.
      // But Countdown search usually respects division.
      // We'll search across all divisions of the unit if KD sees them?
      // Actually, KD usually manages one division.
      final divisions = await _countdownRepo.getDivisions(unit.carId);
      final currentDivName = _session.divisionName?.toUpperCase() ?? '';

      // Filter to current user's division to find panels
      final div = divisions.firstWhere(
        (d) => d.divisionName.toUpperCase() == currentDivName,
        orElse: () => divisions.first,
      );

      final panels = await _countdownRepo.getSections(
        carId: unit.carId,
        divisionId: div.divisionId,
      );

      // Also load employees for this division if not already loaded or different
      final dropdowns = await _repository.getDropdowns(
        divisionId: div.divisionName,
      );

      if (!mounted) return;
      setState(() {
        _panels = panels;
        _employees = dropdowns['users'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onPanelSelected(CountdownSection panel) async {
    setState(() {
      _selectedPanel = panel;
      _selectedJob = null;
      _jobdescs = [];
      _isLoading = true;
    });

    try {
      // Find the division ID again (could be optimized by storing it)
      final divisions = await _countdownRepo.getDivisions(_selectedUnit!.carId);
      final div = divisions.firstWhere(
        (d) =>
            d.divisionName.toUpperCase() ==
            (_session.divisionName?.toUpperCase() ?? ''),
        orElse: () => divisions.first,
      );

      final jobs = await _countdownRepo.getJobdescs(
        carId: _selectedUnit!.carId,
        divisionId: div.divisionId,
        panelId: panel.panelId,
      );

      if (!mounted) return;
      setState(() {
        _jobdescs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onJobSelected(CountdownJobdesc job) {
    setState(() {
      _selectedJob = job;
      _hoursCtrl.text = TimeParser.formatDecimalToHHmm(
        job.remainingHours > 0 ? job.remainingHours : job.targetHoursRevised,
      );
      _syncFinishTime();
    });
  }

  void _syncFinishTime() {
    if (_finishTimeEdited) return;
    final hrs = TimeParser.parseHHmmToDecimal(_hoursCtrl.text) ?? 0;
    if (hrs <= 0) return;

    final nextFinish = CountdownHelper.calculateFinishTime(
      startTime: _startTime,
      durationHours: hrs,
      date: _selectedDate,
    );

    setState(() {
      _finishTime = nextFinish;
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
  }

  Future<void> _save() async {
    if (_selectedUnit == null ||
        _selectedPanel == null ||
        _selectedJob == null) {
      AppNotification.showWarning(
        context,
        'Harap lengkapi Unit, Panel, dan Pekerjaan.',
      );
      return;
    }
    if (_selectedEmployee == null) {
      AppNotification.showWarning(context, 'Harap pilih pelaksana.');
      return;
    }

    final hrs = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (hrs == null || hrs <= 0) {
      AppNotification.showWarning(context, 'Target jam tidak valid.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final draftItem = {
        'draftItemId': 'draft_${DateTime.now().microsecondsSinceEpoch}',
        'sourceType': 'COUNTDOWN',
        'coreId': _selectedJob!.id,
        'carId': _selectedUnit!.carId,
        'divisionId': _selectedJob!.divisionId,
        'unitName': _selectedUnit!.unitName,
        'panelName': _selectedJob!.panelName,
        'assignedUserId': _selectedEmployee!['id'].toString(),
        'assignedTo':
            (_selectedEmployee!['name'] ??
                    _selectedEmployee!['full_name'] ??
                    '-')
                .toString(),
        'jobDescription': _selectedJob!.jobdesc,
        'targetHours': hrs,
        'taskDate': _selectedDate.toIso8601String().split('T').first,
        'startTime': CountdownHelper.formatTime(_startTime),
        'finishTime': CountdownHelper.formatTime(_finishTime),
        'isOvertime': _isOvertime,
        'note': [
          'Sumber: Countdown ${_selectedJob!.id}',
          _isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak',
          if (_instructionCtrl.text.trim().isNotEmpty)
            'POK: ${_instructionCtrl.text.trim()}',
        ].join(' | '),
      };

      final itemsToSave = TaskExecutionHelper.splitJobPlanItem(draftItem);

      await _repository.saveDraft(
        userId: _session.employeeId ?? '',
        items: itemsToSave,
        sourceType: 'COUNTDOWN',
        replaceItems: false,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      AppNotification.showSuccess(
        context,
        'Rencana berhasil disimpan ke Draft.',
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
                          if (res != null)
                            _onUnitSelected(res['raw'] as CountdownUnit);
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
                            if (res != null)
                              _onPanelSelected(res['raw'] as CountdownSection);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // --- JOB SELECTION ---
                      if (_selectedPanel != null) ...[
                        _SearchFieldTile(
                          label: 'Pekerjaan (Jobdesc)',
                          value: _selectedJob?.jobdesc,
                          hint: 'Pilih Tugas di Panel ini',
                          onTap: () async {
                            final res = await jobPlanMasterSearchPicker(
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
                              labelBuilder: (m) => m['name'].toString(),
                              subtitleBuilder: (m) => m['hours'].toString(),
                            );
                            if (res != null)
                              _onJobSelected(res['raw'] as CountdownJobdesc);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // --- PROJECT STATS ---
                      if (_selectedJob != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              _infoRow(
                                'Total Target',
                                CountdownHelper.formatWorkHours(
                                  _selectedJob!.targetHoursRevised,
                                ),
                              ),
                              _infoRow(
                                'Sisa Proyek',
                                CountdownHelper.formatWorkHours(
                                  _selectedJob!.remainingHours,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // --- INSTRUCTIONS ---
                      _FormSection(
                        title: 'Instruksi / POK',
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
                            if (res != null)
                              setState(() => _selectedEmployee = res);
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
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: AppColors.gold,
            ),
            const SizedBox(width: 12),
            Text(
              CountdownHelper.formatDate(_selectedDate),
              style: const TextStyle(color: AppColors.textPrimary),
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

  /// When true, sourceType will be 'COUNTDOWN' and a banner with 'Lihat Countdown' is shown.
  final bool isCountdown;
  final Map<String, dynamic>? initialDraft;
  final int? editIndex;

  @override
  State<_AdditionalPlanFormPage> createState() =>
      _AdditionalPlanFormPageState();
}

class _AdditionalPlanFormPageState extends State<_AdditionalPlanFormPage> {
  late final JobPlanRepository _repository;
  late final bool _lockDivisionToCurrent;
  late final String _currentDivision;
  late String? _currentDivisionId; // numeric ID dari session
  late final List<String> _divisionOptions;
  late String _selectedDivision;
  late List<Map<String, dynamic>> _cars = [];
  late List<Map<String, dynamic>> _panels = [];
  late List<Map<String, dynamic>> _jobTypes = [];
  late List<Map<String, dynamic>> _employees = [];
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _finishTimeCtrl;

  late String? _selectedUnitId = widget.initialDraft?['carId'];
  late String? _selectedPanel =
      widget.initialDraft?['panelCustomNote'] ??
      widget.initialDraft?['panelName'];
  late String? _selectedEmployeeId = widget.initialDraft?['assignedUserId'];
  final Set<String> _selectedJobs = {};
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 12, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;
  bool _isRework = false;
  bool _isSaving = false;
  bool _isLoadingDropdowns = true;
  bool _syncingTimeInputs = false;
  bool _useManualInput = false;
  late final TextEditingController _manualUnitCtrl;
  late final TextEditingController _manualPanelCtrl;
  late final TextEditingController _manualJobCtrl;
  // New: project-level fields
  late final TextEditingController _totalProjectHoursCtrl;
  late final TextEditingController _sectionNameCtrl; // free-text panel section
  DateTime? _deadlineDate;
  DateTime? _startDate;
  bool _useFreeTextPanel =
      false; // true = panel tidak ada di master, isi section_name manual
  String? _selectedCategory;
  final List<String> _categories = [
    'engine',
    'undercarriage',
    'electrical',
    'interior',
    'exterior',
  ];

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    final session = sl<SessionManager>();
    final role = (session.role ?? '').trim().toLowerCase();
    _lockDivisionToCurrent =
        role == 'kd' || role == 'ketua_divisi' || role == 'kepala_divisi';
    _currentDivisionId = session.divisionId?.toString();

    final draft = widget.initialDraft;
    if (draft != null) {
      _currentDivision = session.divisionName ?? 'MECHANIC';
      _selectedDivision =
          draft['divisionName']?.toString() ??
          draft['divisionId']?.toString() ??
          _currentDivision;
      _divisionOptions = [_selectedDivision];
      _selectedDate =
          DateTime.tryParse(draft['taskDate']?.toString() ?? '') ??
          widget.initialDate;

      final st = draft['startTime']?.toString() ?? '08:00';
      final ft = draft['finishTime']?.toString() ?? '16:00';
      _startTime = TimeOfDay(
        hour: int.tryParse(st.split(':')[0]) ?? 8,
        minute: int.tryParse(st.split(':')[1]) ?? 0,
      );
      _finishTime = TimeOfDay(
        hour: int.tryParse(ft.split(':')[0]) ?? 16,
        minute: int.tryParse(ft.split(':')[1]) ?? 0,
      );

      _hoursCtrl = TextEditingController(
        text: _normalizeDurationInput(draft['targetHours'], fallbackHours: 8.0),
      );
      _totalProjectHoursCtrl = TextEditingController(
        text:
            draft['totalProjectHours']?.toString() ??
            draft['targetHours']?.toString() ??
            '8.0',
      );
      _isOvertime = _truthy(draft['isOvertime']);
      _isRework = _truthy(draft['isRework']);
      _noteCtrl = TextEditingController(text: draft['note']?.toString() ?? '');

      _useManualInput = draft['carId'] == '';
      _useFreeTextPanel =
          draft['sectionName'] != null && (draft['panelId'] == null);
      _manualUnitCtrl = TextEditingController(
        text: _useManualInput ? draft['unitName'] : '',
      );
      _manualPanelCtrl = TextEditingController(
        text: _useManualInput ? draft['panelName'] : '',
      );
      _sectionNameCtrl = TextEditingController(
        text: draft['sectionName']?.toString() ?? '',
      );
      _manualJobCtrl = TextEditingController();
      _deadlineDate = DateTime.tryParse(
        draft['deadlineDate']?.toString() ?? '',
      );
      _startDate = DateTime.tryParse(draft['startDate']?.toString() ?? '');

      final jobDesc =
          draft['jobDescription']?.toString() ??
          draft['jobdescription']?.toString();
      if (jobDesc != null && jobDesc.isNotEmpty) _selectedJobs.add(jobDesc);
    } else {
      _currentDivision = session.divisionName ?? 'MECHANIC';
      _selectedDivision = _currentDivision;
      _divisionOptions = [_currentDivision];
      _selectedDate = widget.initialDate;
      _hoursCtrl = TextEditingController(
        text: TimeParser.formatDecimalToHHmm(8.0),
      );
      _totalProjectHoursCtrl = TextEditingController(text: '');
      _noteCtrl = TextEditingController();
      _manualUnitCtrl = TextEditingController();
      _manualPanelCtrl = TextEditingController();
      _sectionNameCtrl = TextEditingController();
      _manualJobCtrl = TextEditingController();
      _finishTime = _calculateFinishTime(
        startTime: _startTime,
        durationHours: 8.0,
        date: _selectedDate,
      );
    }

    _startTimeCtrl = TextEditingController(text: _formatTime(_startTime));
    _finishTimeCtrl = TextEditingController(text: _formatTime(_finishTime));
    _hoursCtrl.addListener(_syncFinishTimeFromHours);
    _startTimeCtrl.addListener(_handleStartTimeInputChanged);
    _finishTimeCtrl.addListener(_handleFinishTimeInputChanged);
    _loadDropdowns(carId: _useManualInput ? null : _selectedUnitId);
  }

  Future<void> _loadDropdowns({String? carId}) async {
    try {
      // Gunakan divisionId numerik dari session jika ada, fallback ke nama divisi
      final divIdForQuery = _currentDivisionId ?? _selectedDivision;
      final dropdowns = await _repository.getDropdowns(
        divisionId: divIdForQuery,
        carId: carId,
      );
      if (!mounted) return;
      setState(() {
        _cars = dropdowns['cars'] ?? [];
        _panels = dropdowns['panels'] ?? [];
        _jobTypes = dropdowns['jobTypes'] ?? [];
        _employees = dropdowns['users'] ?? [];

        final dynamic rawDivs = dropdowns['divisions'];
        if (rawDivs is List) {
          final divNames =
              rawDivs
                  .map((d) {
                    if (d is String) return d;
                    return d['name']?.toString() ?? '';
                  })
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          if (divNames.isNotEmpty) {
            _divisionOptions.clear();
            _divisionOptions.addAll(divNames);
            if (!_divisionOptions.contains(_selectedDivision)) {
              _selectedDivision = _divisionOptions.first;
            }
          }
        }

        if (_cars.isNotEmpty && _selectedUnitId == null) {
          _selectedUnitId = _cars.first['id']?.toString();
        }
        if (_selectedPanel != null &&
            !_panels.any(
              (panel) => panel['name']?.toString() == _selectedPanel,
            )) {
          _selectedPanel = null;
        }
        if (_panels.isNotEmpty && _selectedPanel == null) {
          _selectedPanel = _panels.first['name']?.toString();
        }
        if (_jobTypes.isNotEmpty && _selectedJobs.isEmpty) {
          final firstJob = _jobTypes.first['job_name']?.toString();
          if (firstJob != null && firstJob.isNotEmpty) {
            _selectedJobs.add(firstJob);
          }
        }
        if (_employees.isNotEmpty && _selectedEmployeeId == null) {
          _selectedEmployeeId = _employees.first['id']?.toString();
        }
        _isLoadingDropdowns = false;
      });
    } catch (e, stack) {
      if (!mounted) return;
      debugPrint('[AdditionalPlanForm] _loadDropdowns error: $e\n$stack');
      setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<void> _onDivisionChanged(String division) async {
    if (!mounted) return;
    setState(() {
      _selectedDivision = division;
      _isLoadingDropdowns = true;
      _selectedUnitId = null;
      _selectedPanel = null;
      _selectedJobs.clear();
      _selectedEmployeeId = null;
    });
    await _loadDropdowns();
  }

  @override
  void dispose() {
    _hoursCtrl.removeListener(_syncFinishTimeFromHours);
    _startTimeCtrl.removeListener(_handleStartTimeInputChanged);
    _finishTimeCtrl.removeListener(_handleFinishTimeInputChanged);
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    _startTimeCtrl.dispose();
    _finishTimeCtrl.dispose();
    _manualUnitCtrl.dispose();
    _manualPanelCtrl.dispose();
    _manualJobCtrl.dispose();
    super.dispose();
  }

  void _syncFinishTimeFromHours() {
    if (!mounted || _finishTimeEdited) return;
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (targetHours == null || targetHours <= 0) return;
    final nextFinishTime = _calculateFinishTime(
      startTime: _startTime,
      durationHours: targetHours,
      date: _selectedDate,
    );
    if (nextFinishTime.hour == _finishTime.hour &&
        nextFinishTime.minute == _finishTime.minute) {
      return;
    }
    setState(() {
      _finishTime = nextFinishTime;
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
    _syncTimeTextControllers(syncStart: false);
  }

  void _handleStartTimeInputChanged() {
    if (_syncingTimeInputs) return;
    final parsed = TimeParser.parseTimeOfDay(_startTimeCtrl.text);
    if (parsed == null || _sameTimeOfDay(parsed, _startTime)) return;
    setState(() {
      _startTime = parsed;
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
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
    _syncTimeTextControllers(syncStart: false);
  }

  void _handleFinishTimeInputChanged() {
    if (_syncingTimeInputs) return;
    final parsed = TimeParser.parseTimeOfDay(_finishTimeCtrl.text);
    if (parsed == null || _sameTimeOfDay(parsed, _finishTime)) return;
    setState(() {
      _finishTime = parsed;
      _finishTimeEdited = true;
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
  }

  void _syncTimeTextControllers({
    bool syncStart = true,
    bool syncFinish = true,
  }) {
    _syncingTimeInputs = true;
    if (syncStart) {
      final formattedStart = _formatTime(_startTime);
      if (_startTimeCtrl.text != formattedStart) {
        _startTimeCtrl.value = TextEditingValue(
          text: formattedStart,
          selection: TextSelection.collapsed(offset: formattedStart.length),
        );
      }
    }
    if (syncFinish) {
      final formattedFinish = _formatTime(_finishTime);
      if (_finishTimeCtrl.text != formattedFinish) {
        _finishTimeCtrl.value = TextEditingValue(
          text: formattedFinish,
          selection: TextSelection.collapsed(offset: formattedFinish.length),
        );
      }
    }
    _syncingTimeInputs = false;
  }

  void _applyStandardWorkday() {
    _finishTimeEdited = false;
    _hoursCtrl.text = TimeParser.formatDecimalToHHmm(8.0);
  }

  @override
  Widget build(BuildContext context) {
    final selectedUnit = _cars
        .where((item) => item['id'] == _selectedUnitId)
        .firstOrNull;
    final selectedEmployee = _employees
        .where((item) => item['id'] == _selectedEmployeeId)
        .firstOrNull;
    final selectedEmployeeName =
        _selectedEmployeeId == null || selectedEmployee == null
        ? '-'
        : selectedEmployee['full_name']?.toString() ??
              selectedEmployee['name']?.toString() ??
              '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          widget.isCountdown
              ? 'Create Task dari Countdown'
              : widget.isUrgent
              ? 'Create Task Tambahan Urgent'
              : 'Create Task Tambahan',
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingDropdowns
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        if (widget.isCountdown) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.directions_car_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Isi data berdasarkan countdown unit. Butuh referensi?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.go('/countdown');
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.gold,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'Lihat\nCountdown',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        _FormSection(
                          title: 'Divisi Pelaksana',
                          child: _SearchFieldTile(
                            label: 'Divisi',
                            value: _selectedDivision,
                            hint: 'Pilih divisi',
                            onTap: () async {
                              if (_lockDivisionToCurrent) return;
                              final selected = await jobPlanSimpleValuePicker(
                                context,
                                title: 'Pilih Divisi Pelaksana',
                                items: _divisionOptions,
                              );
                              if (selected != null &&
                                  selected != _selectedDivision) {
                                await _onDivisionChanged(selected);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Unit & Pelaksana',
                          child: Column(
                            children: [
                              _SearchFieldTile(
                                label: 'Unit Kendaraan',
                                value: _useManualInput
                                    ? (_manualUnitCtrl.text.trim().isEmpty
                                          ? null
                                          : _manualUnitCtrl.text.trim())
                                    : selectedUnit?['unit_name']?.toString(),
                                hint: 'Pilih Unit Kendaraan',
                                onTap: () async {
                                  final selected =
                                      await jobPlanMasterSearchPicker(
                                        context,
                                        title: 'Pilih Unit Kendaraan',
                                        items: _cars,
                                        labelBuilder: (item) =>
                                            item['unit_name']?.toString() ?? '',
                                        subtitleBuilder: (item) =>
                                            item['customer_name']?.toString() ??
                                            '',
                                      );
                                  if (selected != null) {
                                    final nextUnitId = selected['id']
                                        ?.toString();
                                    setState(() {
                                      _selectedUnitId = nextUnitId;
                                      _useManualInput = false;
                                      _isLoadingDropdowns = true;
                                      _selectedPanel = null;
                                    });
                                    await _loadDropdowns(carId: nextUnitId);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              _SearchFieldTile(
                                label: 'Pelaksana',
                                value: selectedEmployee?['full_name']
                                    ?.toString(),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Panel / Section',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_useFreeTextPanel)
                                _SearchFieldTile(
                                  label: 'Panel',
                                  value: _selectedPanel,
                                  hint: 'Pilih Panel dari daftar',
                                  onTap: () async {
                                    final selected =
                                        await jobPlanMasterSearchPicker(
                                          context,
                                          title: 'Pilih Panel',
                                          items: _panels,
                                          labelBuilder: (item) =>
                                              item['name']?.toString() ?? '',
                                          subtitleBuilder: (item) =>
                                              item['section']?.toString() ?? '',
                                        );
                                    if (selected != null) {
                                      setState(
                                        () => _selectedPanel =
                                            selected['name']?.toString() ?? '',
                                      );
                                    }
                                  },
                                ),
                              const SizedBox(height: 8),
                              CheckboxListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _useFreeTextPanel,
                                onChanged: (v) => setState(() {
                                  _useFreeTextPanel = v ?? false;
                                  if (!_useFreeTextPanel) {
                                    _selectedCategory = null;
                                    _sectionNameCtrl.clear();
                                  }
                                }),
                                title: const Text(
                                  'Panel tidak ada di daftar (isi manual)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                activeColor: AppColors.gold,
                              ),
                              if (_useFreeTextPanel) ...[
                                TextField(
                                  controller: _sectionNameCtrl,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Panel / Section *',
                                    hintText: 'Ketik nama panel bebas',
                                    prefixIcon: Icon(
                                      Icons.edit_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Panel manual akan otomatis ditambahkan ke master sesuai unit terpilih.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceCard,
                                  decoration: const InputDecoration(
                                    labelText: 'Kategori Panel *',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('— Tidak dipilih —'),
                                    ),
                                    ..._categories.map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c.toUpperCase()),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedCategory = v),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Job / Deskripsi Pekerjaan',
                          child: _SearchFieldTile(
                            label: 'Job',
                            value: _selectedJobs.isEmpty
                                ? null
                                : _selectedJobs.length == 1
                                ? _selectedJobs.first
                                : '${_selectedJobs.length} job dipilih',
                            hint: 'Pilih Pekerjaan',
                            onTap: () async {
                              final selectedJobs = await jobPlanMultiJobPicker(
                                context,
                                title: 'Pilih Job',
                                items: _jobTypes
                                    .map(
                                      (item) =>
                                          item['job_name']?.toString() ?? '',
                                    )
                                    .where((name) => name.isNotEmpty)
                                    .toList(),
                                initialSelection: _selectedJobs,
                              );
                              if (selectedJobs != null) {
                                setState(() {
                                  _selectedJobs
                                    ..clear()
                                    ..addAll(selectedJobs);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Target Jam Harian',
                          child: Column(
                            children: [
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
                                          );
                                    });
                                    _syncTimeTextControllers(syncStart: false);
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
                                          _syncTimeTextControllers(syncStart: false, syncFinish: true);
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
                                          _syncTimeTextControllers();
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
                                          _syncTimeTextControllers(syncStart: true, syncFinish: false);
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
                                          _syncTimeTextControllers(syncStart: false);
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
                                title: const Text(
                                  'Jam lembur',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              SwitchListTile.adaptive(
                                value: _isRework,
                                onChanged: (value) =>
                                    setState(() => _isRework = value),
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: AppColors.gold,
                                title: const Text(
                                  'Pembebanan/Pengulangan/Garansi',
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
                          title: 'Keterangan',
                          child: Column(
                            children: [
                              TextField(
                                controller: _noteCtrl,
                                minLines: 4,
                                maxLines: 6,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Description / POK',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceInput,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'Unit: ${_useManualInput ? (_manualUnitCtrl.text.trim().isEmpty ? '-' : _manualUnitCtrl.text.trim()) : (selectedUnit?['unit_name'] ?? '-')}\nPanel: ${_useManualInput ? (_manualPanelCtrl.text.trim().isEmpty ? '-' : _manualPanelCtrl.text.trim()) : (_selectedPanel ?? '-')}\nJob: ${_useManualInput ? (_manualJobCtrl.text.trim().isEmpty ? '-' : _manualJobCtrl.text.trim()) : (_selectedJobs.isEmpty ? '-' : _selectedJobs.join(', '))}\nOperator: $selectedEmployeeName\nDivisi Pelaksana: $_selectedDivision',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(selectedUnit, selectedEmployee),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(
    Map<String, dynamic>? selectedUnit,
    Map<String, dynamic>? selectedEmployee,
  ) async {
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    final manualUnit = _manualUnitCtrl.text.trim();
    final manualPanel = _manualPanelCtrl.text.trim();
    final manualJob = _manualJobCtrl.text.trim();
    if (_useManualInput) {
      if (manualUnit.isEmpty ||
          manualPanel.isEmpty ||
          manualJob.isEmpty ||
          _selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unit, panel, job manual, dan kategori wajib diisi.'),
          ),
        );
        return;
      }
    } else if (selectedUnit == null ||
        (_selectedPanel == null && !_useFreeTextPanel) ||
        (_useFreeTextPanel &&
            (_sectionNameCtrl.text.trim().isEmpty ||
                _selectedCategory == null)) ||
        _selectedJobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap lengkapi semua isian: Unit, Panel, Kategori (jika manual), dan Job.',
          ),
        ),
      );
      return;
    }
    if (_selectedEmployeeId == null || selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelaksana terlebih dahulu.')),
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
      if (_noteCtrl.text.trim().isNotEmpty) 'POK: ${_noteCtrl.text.trim()}',
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
                : selectedUnit!['unit_name'].toString(),
            panelName: _useManualInput ? manualPanel : _selectedPanel!,
            assignedDivision: _selectedDivision,
            assignedUserId: _selectedEmployeeId!,
            assignedTo: selectedEmployee['full_name'].toString(),
            description: job,
            targetHours: targetHours,
            workDate: _formatDate(_selectedDate),
            startTime: _formatTime(_startTime),
            finishTime: _formatTime(_finishTime),
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
        for (final job in jobsToCreate) {
          final existingDraftItemId =
              widget.initialDraft?['draftItemId']?.toString() ?? '';
          final nextDraftItemId =
              existingDraftItemId.isNotEmpty && draftOffset == 0
              ? existingDraftItemId
              : 'draft_${draftSeed}_$draftOffset';
          
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
                selectedEmployee['name']?.toString() ??
                selectedEmployee['full_name']?.toString() ??
                '',
            'taskDate': _formatDate(_selectedDate),
            'jobDescription': job,
            'targetHours': targetHours,
            'totalProjectHours': () {
              final raw = _totalProjectHoursCtrl.text.trim();
              if (raw.isEmpty) return null;
              // Support HH:MM format (e.g. "180:00") and decimal (e.g. "180.5")
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
            'startTime': _formatTime(_startTime),
            'finishTime': _formatTime(_finishTime),
            'isOvertime': _isOvertime,
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
            existingItems[rejectedDraftIndex] = newItems.first;
            if (newItems.length > 1) {
              existingItems.addAll(newItems.sublist(1));
            }
          } else if (rejectedPlanId.isNotEmpty) {
            existingItems.addAll(newItems);
          } else if (widget.editIndex != null &&
              widget.editIndex! >= 0 &&
              widget.editIndex! < existingItems.length) {
            existingItems[widget.editIndex!] = newItems.first;
            if (newItems.length > 1) {
              existingItems.addAll(newItems.sublist(1));
            }
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
            const SnackBar(content: Text('Tersimpan di Draft. Cek tab Draft.')),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _SourcePlanFormPage extends StatefulWidget {
  const _SourcePlanFormPage({
    required this.seed,
    required this.initialDate,
    this.initialDraft,
    this.editIndex,
  });

  final _PlanSourceSeed seed;
  final DateTime initialDate;
  final Map<String, dynamic>? initialDraft;
  final int? editIndex;

  @override
  State<_SourcePlanFormPage> createState() => _SourcePlanFormPageState();
}

class _SourcePlanFormPageState extends State<_SourcePlanFormPage> {
  late final JobPlanRepository _repository;
  late List<Map<String, dynamic>> _employees = [];
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _finishTimeCtrl;

  /// Editable override for panel name (pre-filled from seed).
  late final TextEditingController _panelCtrl;

  /// Editable override for jobdesc (pre-filled from seed).
  late final TextEditingController _jobdescCtrl;
  String? _selectedEmployeeId;
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 12, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;
  bool _isSaving = false;
  bool _isLoadingDropdowns = true;
  bool _syncingTimeInputs = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();

    final draft = widget.initialDraft;
    if (draft != null) {
      _selectedDate =
          DateTime.tryParse(draft['taskDate']?.toString() ?? '') ??
          widget.initialDate;
      _selectedEmployeeId = draft['assignedUserId']?.toString();
      _isOvertime = _truthy(draft['isOvertime']);
      _hoursCtrl = TextEditingController(
        text: _normalizeDurationInput(
          draft['targetHours'],
          fallbackHours: widget.seed.targetHours,
        ),
      );

      final st = draft['startTime']?.toString() ?? '08:00';
      final ft = draft['finishTime']?.toString() ?? '16:00';
      _startTime = TimeOfDay(
        hour: int.tryParse(st.split(':')[0]) ?? 8,
        minute: int.tryParse(st.split(':')[1]) ?? 0,
      );
      _finishTime = TimeOfDay(
        hour: int.tryParse(ft.split(':')[0]) ?? 16,
        minute: int.tryParse(ft.split(':')[1]) ?? 0,
      );
      _noteCtrl = TextEditingController(text: draft['note']?.toString() ?? '');
    } else {
      _selectedEmployeeId = widget.seed.picId;
      _selectedDate = widget.initialDate;
      _hoursCtrl = TextEditingController(
        text: TimeParser.formatDecimalToHHmm(widget.seed.targetHours),
      );
      _noteCtrl = TextEditingController();
      _finishTime = _calculateFinishTime(
        startTime: _startTime,
        durationHours: widget.seed.targetHours,
        date: _selectedDate,
      );
    }

    _startTimeCtrl = TextEditingController(text: _formatTime(_startTime));
    _finishTimeCtrl = TextEditingController(text: _formatTime(_finishTime));
    _panelCtrl = TextEditingController(
      text:
          widget.initialDraft?['panelName']?.toString() ??
          widget.initialDraft?['panelCustomNote']?.toString() ??
          widget.seed.panelName,
    );
    _jobdescCtrl = TextEditingController(
      text:
          widget.initialDraft?['jobDescription']?.toString() ??
          widget.seed.description,
    );
    _hoursCtrl.addListener(_syncFinishTimeFromHours);
    _startTimeCtrl.addListener(_handleStartTimeInputChanged);
    _finishTimeCtrl.addListener(_handleFinishTimeInputChanged);
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final dropdowns = await _repository.getDropdowns(
        divisionId: widget.seed.assignedDivision,
      );
      if (!mounted) return;
      setState(() {
        _employees = dropdowns['users'] ?? [];
        if (_employees.isNotEmpty && _selectedEmployeeId == null) {
          if (widget.seed.picId != null &&
              _employees.any((e) => e['id']?.toString() == widget.seed.picId)) {
            _selectedEmployeeId = widget.seed.picId;
          } else {
            _selectedEmployeeId = _employees.first['id']?.toString();
          }
        }
        _isLoadingDropdowns = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDropdowns = false);
    }
  }

  @override
  void dispose() {
    _hoursCtrl.removeListener(_syncFinishTimeFromHours);
    _startTimeCtrl.removeListener(_handleStartTimeInputChanged);
    _finishTimeCtrl.removeListener(_handleFinishTimeInputChanged);
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    _startTimeCtrl.dispose();
    _finishTimeCtrl.dispose();
    _panelCtrl.dispose();
    _jobdescCtrl.dispose();
    super.dispose();
  }

  void _syncFinishTimeFromHours() {
    if (!mounted || _finishTimeEdited) return;
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (targetHours == null || targetHours <= 0) return;
    final nextFinishTime = _calculateFinishTime(
      startTime: _startTime,
      durationHours: targetHours,
      date: _selectedDate,
    );
    if (nextFinishTime.hour == _finishTime.hour &&
        nextFinishTime.minute == _finishTime.minute) {
      return;
    }
    setState(() {
      _finishTime = nextFinishTime;
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
    _syncTimeTextControllers(syncStart: false);
  }

  void _handleStartTimeInputChanged() {
    if (_syncingTimeInputs) return;
    final parsed = TimeParser.parseTimeOfDay(_startTimeCtrl.text);
    if (parsed == null || _sameTimeOfDay(parsed, _startTime)) return;
    setState(() {
      _startTime = parsed;
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
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
    _syncTimeTextControllers(syncStart: false);
  }

  void _handleFinishTimeInputChanged() {
    if (_syncingTimeInputs) return;
    final parsed = TimeParser.parseTimeOfDay(_finishTimeCtrl.text);
    if (parsed == null || _sameTimeOfDay(parsed, _finishTime)) return;
    setState(() {
      _finishTime = parsed;
      _finishTimeEdited = true;
      _isOvertime = CountdownHelper.isOvertimeByTime(_finishTime);
    });
  }

  void _syncTimeTextControllers({
    bool syncStart = true,
    bool syncFinish = true,
  }) {
    _syncingTimeInputs = true;
    if (syncStart) {
      final formattedStart = _formatTime(_startTime);
      if (_startTimeCtrl.text != formattedStart) {
        _startTimeCtrl.value = TextEditingValue(
          text: formattedStart,
          selection: TextSelection.collapsed(offset: formattedStart.length),
        );
      }
    }
    if (syncFinish) {
      final formattedFinish = _formatTime(_finishTime);
      if (_finishTimeCtrl.text != formattedFinish) {
        _finishTimeCtrl.value = TextEditingValue(
          text: formattedFinish,
          selection: TextSelection.collapsed(offset: formattedFinish.length),
        );
      }
    }
    _syncingTimeInputs = false;
  }

  void _applyStandardWorkday() {
    _finishTimeEdited = false;
    _hoursCtrl.text = TimeParser.formatDecimalToHHmm(8.0);
  }

  @override
  Widget build(BuildContext context) {
    final selectedEmployee = _employees
        .where((item) => item['id'] == _selectedEmployeeId)
        .firstOrNull;
    final selectedEmployeeName =
        _selectedEmployeeId == null || selectedEmployee == null
        ? '-'
        : selectedEmployee['full_name']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text('Create Task dari ${widget.seed.sourceLabel}'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingDropdowns
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        // Compact Info Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceInput,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
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
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.seed.sourceLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.seed.unitName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
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
                        // ── Editable Panel & Jobdesc ─────────────────────
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
                                          );
                                    });
                                    _syncTimeTextControllers(syncStart: false);
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
                                          _syncTimeTextControllers(syncStart: false, syncFinish: true);
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
                                          _syncTimeTextControllers();
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
                                          _syncTimeTextControllers(syncStart: true, syncFinish: false);
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
                                          _syncTimeTextControllers(syncStart: false);
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
                          title: 'Keterangan',
                          child: Column(
                            children: [
                              TextField(
                                controller: _noteCtrl,
                                minLines: 3,
                                maxLines: 5,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Description / POK',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(selectedEmployeeName),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String selectedEmployeeName) async {
    final targetHours = TimeParser.parseHHmmToDecimal(_hoursCtrl.text);
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelaksana terlebih dahulu.')),
      );
      return;
    }
    if (_panelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panel tidak boleh kosong.')),
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
      if (_noteCtrl.text.trim().isNotEmpty) 'POK: ${_noteCtrl.text.trim()}',
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
            widget.initialDraft?['draftItemId']?.toString() ??
            'draft_${DateTime.now().microsecondsSinceEpoch}',
        if (widget.initialDraft?['fromRejectedPlan'] == true)
          'fromRejectedPlan': true,
        if ((widget.initialDraft?['rejectedPlanId'] ?? '')
            .toString()
            .isNotEmpty)
          'rejectedPlanId': widget.initialDraft!['rejectedPlanId'],
        'coreId': widget.seed.coreId,
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
        'startTime': _formatTime(_startTime),
        'finishTime': _formatTime(_finishTime),
        'isOvertime': _isOvertime,
      };

      final splitItems = TaskExecutionHelper.splitJobPlanItem(newItem);
      final uid = session.employeeId ?? '';
      final rejectedPlanId = (widget.initialDraft?['rejectedPlanId'] ?? '')
          .toString();
      final isReplacingDraft =
          rejectedPlanId.isNotEmpty || widget.editIndex != null;

      if (isReplacingDraft) {
        final existingDraft = await _repository.getDraft(userId: uid);
        final existingItems = (existingDraft?['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
        existingItems.removeWhere(
          (t) => t['carId'] == null && t['panelId'] == null,
        );
        final rejectedDraftIndex = rejectedPlanId.isEmpty
            ? -1
            : existingItems.indexWhere(
                (item) => item['rejectedPlanId']?.toString() == rejectedPlanId,
              );

        if (rejectedDraftIndex >= 0) {
          existingItems.removeAt(rejectedDraftIndex);
          existingItems.insertAll(rejectedDraftIndex, splitItems);
        } else if (rejectedPlanId.isNotEmpty) {
          existingItems.addAll(splitItems);
        } else if (widget.editIndex != null &&
            widget.editIndex! >= 0 &&
            widget.editIndex! < existingItems.length) {
          existingItems.removeAt(widget.editIndex!);
          existingItems.insertAll(widget.editIndex!, splitItems);
        } else {
          existingItems.addAll(splitItems);
        }
        await _repository.saveDraft(
          userId: uid,
          items: existingItems,
          sourceType: widget.seed.sourceType,
          replaceItems: true,
          note: sourceNote,
        );
      } else {
        await _repository.saveDraft(
          userId: uid,
          items: splitItems,
          sourceType: widget.seed.sourceType,
          replaceItems: false,
          note: sourceNote,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Berhasil disimpan ke draft. Silakan cek tab Drafts.',
            ),
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat draft rencana: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

String _normalizeDurationInput(Object? rawValue, {double fallbackHours = 0}) {
  final raw = rawValue?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return fallbackHours > 0
        ? TimeParser.formatDecimalToHHmm(fallbackHours)
        : '';
  }

  final parsed = TimeParser.parseHHmmToDecimal(raw);
  if (parsed != null && parsed > 0) {
    return TimeParser.formatDecimalToHHmm(parsed);
  }

  final decimal = double.tryParse(raw.replaceAll(',', '.'));
  if (decimal != null && decimal > 0) {
    return TimeParser.formatDecimalToHHmm(decimal);
  }

  return fallbackHours > 0 ? TimeParser.formatDecimalToHHmm(fallbackHours) : '';
}

bool _sameTimeOfDay(TimeOfDay left, TimeOfDay right) {
  return left.hour == right.hour && left.minute == right.minute;
}

TimeOfDay _calculateFinishTime({
  required TimeOfDay startTime,
  required double durationHours,
  required DateTime date,
}) {
  final isFriday = date.weekday == DateTime.friday;
  final breakStartMinutes = isFriday ? (11 * 60 + 30) : (12 * 60);
  const breakEndMinutes = 13 * 60;

  int current = (startTime.hour * 60) + startTime.minute;
  int workMinutes = (durationHours * 60).round();

  if (current >= breakStartMinutes && current < breakEndMinutes) {
    current = breakEndMinutes;
  }

  if (current < breakStartMinutes) {
    int beforeBreak = breakStartMinutes - current;
    if (workMinutes > beforeBreak) {
      current = breakEndMinutes + (workMinutes - beforeBreak);
    } else {
      current += workMinutes;
    }
  } else {
    current += workMinutes;
  }

  current = current % (24 * 60);
  return TimeOfDay(hour: current ~/ 60, minute: current % 60);
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
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.search_rounded),
        ),
        child: Text(
          value?.isNotEmpty == true ? value! : hint,
          style: TextStyle(
            color: value?.isNotEmpty == true
                ? AppColors.textPrimary
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Status helpers ──────────────────────────────────────────────────────────
String _statusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PLAN':
      return '✓ Disetujui';
    case 'PENDING_ADV':
      return 'Menunggu ADV';
    case 'PENDING_KP':
      return 'Menunggu KP';
    case 'PENDING_MP':
      return 'Menunggu MP';
    case 'REJECTED':
      return 'Ditolak';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status.trim().toUpperCase()) {
    case 'PENDING_ADV':
      return const Color(0xFF42A5F5);
    case 'PENDING_KP':
      return const Color(0xFFFFB300);
    case 'PENDING_MP':
      return const Color(0xFFFB8C00);
    case 'REJECTED':
      return const Color(0xFFEF5350);
    case 'PLAN':
    default:
      return const Color(0xFF4CAF50);
  }
}

bool _isBrowseVisibleStatus(String status) {
  switch (status.trim().toUpperCase()) {
    case 'PLAN':
      return true;
    default:
      return false;
  }
}

String _resolvePanelLabelFromItem(Map<String, dynamic> item) {
  return (item['panelName'] ??
          item['panelCustomNote'] ??
          item['panel_custom_note'] ??
          item['sectionName'] ??
          '-')
      .toString()
      .trim();
}

String _resolveInstructionNote({
  String? note,
  String? description,
  String? panelName,
}) {
  final normalizedNote = (note ?? '').trim();
  if (normalizedNote.isEmpty) return '';

  final normalizedDescription = (description ?? '').trim();
  final normalizedPanel = (panelName ?? '').trim();
  final autoFallback = [
    if (normalizedDescription.isNotEmpty) normalizedDescription,
    if (normalizedPanel.isNotEmpty && normalizedPanel != '-') normalizedPanel,
  ].join(' - ');

  if (normalizedNote == normalizedDescription) return '';
  if (autoFallback.isNotEmpty && normalizedNote == autoFallback) return '';
  return normalizedNote;
}

String _formatHours(double h) {
  // Guard: if value looks like raw DB seconds (> 24h), convert it
  if (h > 24) h = h / 3600.0;
  return CountdownHelper.formatWorkHours(h);
}

bool _truthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'y';
}

// ─── Draft Cart Item ─────────────────────────────────────────────────────────
class _DraftCartItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DraftCartItem({
    required this.index,
    required this.item,
    required this.isSelected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _truthy(item['isOvertime'])
                          ? const Color(0xFFFF6F00).withValues(alpha: 0.15)
                          : AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _truthy(item['isOvertime']) ? 'Lembur' : 'Normal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _truthy(item['isOvertime'])
                            ? const Color(0xFFFF6F00)
                            : AppColors.gold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item['taskDate']?.toString() ?? '-',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if ((item['rejectNote'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: Color(0xFFEF5350),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['rejectNote'].toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Pelaksana',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                item['assignedUserName']?.toString() ??
                    item['assignedTo']?.toString() ??
                    '-',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unit & Panel',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${item['unitName'] ?? '-'} • ${_resolvePanelLabelFromItem(item)}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pekerjaan',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                item['jobDescription']?.toString() ??
                    item['jobdescription']?.toString() ??
                    '-',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_resolveInstructionNote(
                note: item['note']?.toString(),
                description:
                    item['jobDescription']?.toString() ??
                    item['jobdescription']?.toString(),
                panelName: _resolvePanelLabelFromItem(item),
              ).isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Instruksi / POK',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                Text(
                  _resolveInstructionNote(
                    note: item['note']?.toString(),
                    description:
                        item['jobDescription']?.toString() ??
                        item['jobdescription']?.toString(),
                    panelName: _resolvePanelLabelFromItem(item),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Jadwal',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                '${item['startTime'] ?? '-'} – ${item['finishTime'] ?? '-'} (${_formatHours(double.tryParse((item['targetHours'] ?? 0).toString()) ?? 0)})',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF5350),
                        side: const BorderSide(color: Color(0xFFEF5350)),
                      ),
                      child: const Text('Hapus'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onEdit();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                      ),
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOt = _truthy(item['isOvertime']);
    final isRejectedDraft = item['fromRejectedPlan'] == true;
    final accentColor = isRejectedDraft
        ? const Color(0xFFEF5350)
        : isOt
        ? const Color(0xFFFF6F00)
        : AppColors.gold;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: accentColor),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showDetail(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onToggle,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: isSelected ? accentColor : AppColors.textMuted,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isRejectedDraft
                                      ? 'Revisi'
                                      : isOt
                                      ? 'Lembur'
                                      : 'Normal',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['assignedUserName']?.toString() ??
                                      item['assignedTo']?.toString() ??
                                      'Belum Assigned',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                item['taskDate']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: IconButton(
                                  onPressed: onEdit,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: IconButton(
                                  onPressed: onDelete,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 15,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                  color: const Color(0xFFEF5350),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if ((item['unitName'] ?? '').toString().isNotEmpty)
                            Text(
                              '${item['unitName'] ?? '-'}  •  ${_resolvePanelLabelFromItem(item)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 3),
                          if ((item['rejectNote'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            Text(
                              'Catatan: ${item['rejectNote']}',
                              style: const TextStyle(
                                color: Color(0xFFEF5350),
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                          ],
                          Text(
                            item['jobDescription']?.toString() ??
                                item['jobdescription']?.toString() ??
                                '-',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_resolveInstructionNote(
                            note: item['note']?.toString(),
                            description:
                                item['jobDescription']?.toString() ??
                                item['jobdescription']?.toString(),
                            panelName: _resolvePanelLabelFromItem(item),
                          ).isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'POK: ${_resolveInstructionNote(note: item['note']?.toString(), description: item['jobDescription']?.toString() ?? item['jobdescription']?.toString(), panelName: _resolvePanelLabelFromItem(item))}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item['startTime'] ?? '-'} – ${item['finishTime'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatHours(
                                  double.tryParse(
                                        (item['targetHours'] ?? 0).toString(),
                                      ) ??
                                      0,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmittedPlanCard extends StatelessWidget {
  const _SubmittedPlanCard({required this.plan});

  final JobPlan plan;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(plan.status);
    final instructionNote = _resolveInstructionNote(
      note: plan.note,
      description: plan.description,
      panelName: plan.panelName,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    _statusLabel(plan.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  plan.workDate.isNotEmpty ? plan.workDate : '-',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    plan.assignedTo.isNotEmpty
                        ? plan.assignedTo
                        : 'Belum Assigned',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              '${plan.unitName.isNotEmpty ? plan.unitName : '-'}  •  ${plan.panelName.isNotEmpty ? plan.panelName : '-'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              plan.description.isNotEmpty ? plan.description : '-',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (instructionNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                'POK: $instructionNote',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${plan.startTime} – ${plan.finishTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatHours(plan.targetHours),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (plan.isOvertime
                                ? const Color(0xFFFF6F00)
                                : AppColors.gold)
                            .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plan.isOvertime ? 'LEMBUR' : 'NORMAL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: plan.isOvertime
                          ? const Color(0xFFFF6F00)
                          : AppColors.gold,
                    ),
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

// ─── Combined Browse + Draft Cart Tab ────────────────────────────────────────
class BrowseTab extends StatefulWidget {
  const BrowseTab({
    super.key,
    this.onSubmitted,
    required this.selectedDate,
    this.onDateChanged,
  });

  final VoidCallback? onSubmitted;
  final DateTime selectedDate;
  final ValueChanged<DateTime>? onDateChanged;

  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  final _repository = sl<JobPlanRepository>();
  final _session = sl<SessionManager>();
  int _loadRequestId = 0;

  /// Called externally (e.g. from FAB in JobPlanPage) to refresh draft + browse.
  Future<void> refresh() => _loadAll();

  List<JobPlan> _submittedPlans = [];
  List<Map<String, dynamic>> _draftItems = [];
  Map<String, dynamic>? _rawDraft;
  final Set<String> _selectedDraftKeys = {};

  String _getDraftItemKey(Map<String, dynamic> item) {
    if (_isRejectedDraftItem(item)) {
      return 'rej_${item['rejectedPlanId']}';
    }
    // Safe pseudo-key for new draft items
    return 'new_${item['carId'] ?? 'c'}_'
        '${item['assignedUserId'] ?? 'u'}_'
        '${item['taskDate'] ?? 'd'}_'
        '${(item['jobDescription'] ?? item['jobdescription'] ?? 'j').toString().hashCode}_'
        '${item['startTime'] ?? 's'}_'
        '${item['targetHours'] ?? 'h'}';
  }

  late DateTime _filterDate;
  bool? _filterOvertime;

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> get _filteredDraftItems {
    return _draftItems.where((item) {
      final taskDateStr = item['taskDate']?.toString();
      final dateStr = _filterDate.toString().substring(0, 10);
      if (taskDateStr == null || !taskDateStr.startsWith(dateStr)) return false;

      if (_filterOvertime != null) {
        final isOt = _truthy(item['isOvertime']);
        if (isOt != _filterOvertime) return false;
      }
      return true;
    }).toList();
  }

  List<JobPlan> get _filteredSubmittedPlans {
    return _submittedPlans.where((plan) {
      if (!plan.workDate.startsWith(_filterDate.toString().substring(0, 10))) {
        return false;
      }
      if (_filterOvertime != null && plan.isOvertime != _filterOvertime) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _filterDate = widget.selectedDate;
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant BrowseTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDate = oldWidget.selectedDate.toString().substring(0, 10);
    final newDate = widget.selectedDate.toString().substring(0, 10);
    if (oldDate != newDate) {
      _filterDate = widget.selectedDate;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    final requestId = ++_loadRequestId;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.browsePlans(
          taskDate: _filterDate.toString().substring(0, 10),
        ),
        _repository.getDraft(userId: _session.employeeId ?? ''),
      ]);
      if (!mounted || requestId != _loadRequestId) return;
      final plans = results[0] as List<JobPlan>;
      final rawDraft = results[1] as Map<String, dynamic>?;
      final itemsRaw = rawDraft?['items'] as List<dynamic>? ?? [];
      final storedDraftItems = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList();
      final rejectedDraftItems = plans
          .where((plan) => plan.status.toUpperCase() == 'REJECTED')
          .map(_draftItemFromRejectedPlan)
          .where(
            (item) => !storedDraftItems.any(
              (draft) => draft['rejectedPlanId'] == item['rejectedPlanId'],
            ),
          )
          .toList();
      setState(() {
        _submittedPlans = plans
            .where((plan) => _isBrowseVisibleStatus(plan.status))
            .toList();
        _rawDraft = rawDraft;
        _draftItems = [...rejectedDraftItems, ...storedDraftItems].map((map) {
          if (map['sourceType'] == null) {
            map['sourceType'] = rawDraft?['sourceType'];
          }
          return map;
        }).toList();
        _selectedDraftKeys.clear();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitSelected() async {
    if (_selectedDraftKeys.isEmpty) return;
    setState(() => _isSubmitting = true);

    final filtered = _filteredDraftItems;
    final selectedItems = filtered.where((item) {
      return _selectedDraftKeys.contains(_getDraftItemKey(item));
    }).toList();

    final rejectedItems = selectedItems.where(_isRejectedDraftItem).toList();
    final newItems = selectedItems
        .where((item) => !_isRejectedDraftItem(item))
        .toList();
    final remaining = _draftItems
        .where((item) => !selectedItems.contains(item))
        .toList();
    final remainingStored = remaining
        .where((item) => !_isRejectedDraftItem(item))
        .toList();

    try {
      if (newItems.isNotEmpty) {
        await _repository.submitDraft(
          userId: _session.employeeId ?? '',
          items: newItems,
          sourceType: _rawDraft?['sourceType']?.toString() ?? 'ADDITIONAL',
        );
      }
      for (final item in rejectedItems) {
        await _repository.resubmitPlan(
          planId: item['rejectedPlanId'].toString(),
          userId: _session.employeeId ?? '',
          items: [item],
        );
      }
      if (remainingStored.isNotEmpty) {
        await _repository.saveDraft(
          userId: _session.employeeId ?? '',
          items: remainingStored,
          sourceType: _rawDraft?['sourceType']?.toString() ?? 'ADDITIONAL',
          replaceItems: true,
        );
      } else {
        await _repository.deleteDraft(userId: _session.employeeId ?? '');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedItems.length} rencana dikirim ke approval. Muncul di daftar ini setelah ACC final.',
            ),
          ),
        );
        widget.onSubmitted?.call();
        await _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: const Color(0xFFEF5350),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isRejectedDraftItem(Map<String, dynamic> item) {
    return item['fromRejectedPlan'] == true &&
        (item['rejectedPlanId'] ?? '').toString().isNotEmpty;
  }

  Map<String, dynamic> _draftItemFromRejectedPlan(JobPlan plan) {
    return {
      'fromRejectedPlan': true,
      'rejectedPlanId': plan.planId,
      'coreId': plan.coreId,
      'carId': plan.carId,
      'divisionName': plan.assignedDivision,
      'panelCustomNote': plan.panelName,
      'sourceType': plan.sourceType,
      'assignedUserId': plan.assignedUserId,
      'assignedUserName': plan.assignedTo,
      'taskDate': plan.workDate,
      'jobDescription': plan.description,
      'targetHours': plan.targetHours,
      'startTime': plan.startTime,
      'finishTime': plan.finishTime,
      'isOvertime': plan.isOvertime,
      'unitName': plan.unitName,
      'panelName': plan.panelName,
      'rejectNote': plan.note,
      'note': plan.note,
    };
  }

  Future<void> _discardSelected() async {
    if (_selectedDraftKeys.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Hapus draft?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Hapus ${_selectedDraftKeys.length} item yang dipilih dari Draft?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Color(0xFFEF5350)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final filtered = _filteredDraftItems;
      final selectedItems = filtered.where((item) {
        return _selectedDraftKeys.contains(_getDraftItemKey(item));
      }).toList();

      // Hapus secara permanen dari server jika plan adalah revisi/rejected
      for (final item in selectedItems) {
        if (item['fromRejectedPlan'] == true) {
          await _repository.deleteRejectedPlan(
            planId: item['rejectedPlanId'].toString(),
            userId: _session.employeeId ?? '',
          );
        }
      }

      final remaining = _draftItems
          .where((item) => !selectedItems.contains(item))
          .toList();
      if (remaining.isNotEmpty) {
        await _repository.saveDraft(
          userId: _session.employeeId ?? '',
          items: remaining,
          sourceType: _rawDraft?['sourceType']?.toString() ?? 'ADDITIONAL',
          replaceItems: true,
        );
      } else {
        await _repository.deleteDraft(userId: _session.employeeId ?? '');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus beberapa plan: $e')),
        );
      }
    } finally {
      if (mounted) _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredDraftItems;
    final filteredSubmitted = _filteredSubmittedPlans;
    final hasDrafts = filtered.isNotEmpty || _draftItems.isNotEmpty;
    final hasSubmitted =
        filteredSubmitted.isNotEmpty || _submittedPlans.isNotEmpty;
    final hasSelected = _selectedDraftKeys.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _loadAll,
                child: CustomScrollView(
                  slivers: [
                    // ─── FILTER SECTION ──────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DateFilterBar(
                              selectedDate: _filterDate,
                              onDateChanged: (date) {
                                setState(() => _filterDate = date);
                                widget.onDateChanged?.call(date);
                                _loadAll();
                              },
                              label: 'Rencana',
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceInput,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildFilterPill(
                                      'Semua',
                                      _filterOvertime == null,
                                      () => setState(
                                        () => _filterOvertime = null,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildFilterPill(
                                      'Normal',
                                      _filterOvertime == false,
                                      () => setState(
                                        () => _filterOvertime = false,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildFilterPill(
                                      'Lembur',
                                      _filterOvertime == true,
                                      () => setState(
                                        () => _filterOvertime = true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── CART SECTION ──────────────────────────────────────────
                    if (hasDrafts) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'Jobplan Draft (${filtered.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    if (_selectedDraftKeys.length ==
                                        filtered.length) {
                                      _selectedDraftKeys.clear();
                                    } else {
                                      _selectedDraftKeys.addAll(
                                        filtered
                                            .map(
                                              (item) => _getDraftItemKey(item),
                                            )
                                            .toList(),
                                      );
                                    }
                                  });
                                },
                                icon: Icon(
                                  _selectedDraftKeys.length == filtered.length
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                                tooltip: 'Pilih Semua',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final item = filtered[i];
                          final key = _getDraftItemKey(item);
                          final isSelected = _selectedDraftKeys.contains(key);
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: _DraftCartItem(
                              index: i,
                              item: item,
                              isSelected: isSelected,
                              onToggle: () => setState(() {
                                if (isSelected) {
                                  _selectedDraftKeys.remove(key);
                                } else {
                                  _selectedDraftKeys.add(key);
                                }
                              }),
                              onEdit: () async {
                                final itemToEdit = filtered[i];
                                // We check if it is an ADDITIONAL task
                                if (itemToEdit['sourceType'] == 'ADDITIONAL' ||
                                    itemToEdit['sourceType'] ==
                                        'URGENT_ADDITIONAL') {
                                  final result = await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _AdditionalPlanFormPage(
                                      initialDate:
                                          DateTime.tryParse(
                                            itemToEdit['taskDate']
                                                    ?.toString() ??
                                                '',
                                          ) ??
                                          DateTime.now(),
                                      isUrgent:
                                          itemToEdit['sourceType'] ==
                                          'URGENT_ADDITIONAL',
                                      initialDraft: itemToEdit,
                                      editIndex:
                                          i, // We pass internal index of the filtered view? No, we need absolute index.
                                      // Wait, filtered is NOT the same length as _draftItems!
                                      // Find absolute index:
                                    ),
                                  );
                                  if (result == true) refresh();
                                } else {
                                  // Edit MAIN / WO / WOV task using _SourcePlanFormPage
                                  final seed = _PlanSourceSeed(
                                    sourceLabel:
                                        itemToEdit['sourceType']?.toString() ??
                                        'MAIN',
                                    sourceType:
                                        itemToEdit['sourceType']?.toString() ??
                                        'MAIN',
                                    sourceRefId:
                                        itemToEdit['sourceRefId']?.toString() ??
                                        '',
                                    sourceRoute: '',
                                    carId:
                                        itemToEdit['carId']?.toString() ?? '',
                                    coreId:
                                        itemToEdit['coreId']?.toString() ?? '',
                                    unitName:
                                        itemToEdit['unitName']?.toString() ??
                                        '',
                                    panelName:
                                        itemToEdit['panelName']?.toString() ??
                                        itemToEdit['panelCustomNote']
                                            ?.toString() ??
                                        '-',
                                    assignedDivision:
                                        itemToEdit['divisionName']
                                            ?.toString() ??
                                        _session.divisionName ??
                                        'MECHANIC',
                                    description:
                                        itemToEdit['jobDescription']
                                            ?.toString() ??
                                        '-',
                                    targetHours:
                                        double.tryParse(
                                          itemToEdit['targetHours']
                                                  ?.toString() ??
                                              '8.0',
                                        ) ??
                                        8.0,
                                  );

                                  final result = await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _SourcePlanFormPage(
                                      seed: seed,
                                      initialDate:
                                          DateTime.tryParse(
                                            itemToEdit['taskDate']
                                                    ?.toString() ??
                                                '',
                                          ) ??
                                          DateTime.now(),
                                      initialDraft: itemToEdit,
                                      editIndex:
                                          i, // We use absolute filtered index which matches when we save locally
                                    ),
                                  );
                                  if (result == true) refresh();
                                }
                              },
                              onDelete: () async {
                                final itemToRemove = filtered[i];
                                if (itemToRemove['fromRejectedPlan'] == true) {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    setState(() => _isLoading = true);
                                    await _repository.deleteRejectedPlan(
                                      planId: itemToRemove['rejectedPlanId']
                                          .toString(),
                                      userId: _session.employeeId ?? '',
                                    );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Plan berhasil dihapus.',
                                          ),
                                        ),
                                      );
                                    }
                                    _loadAll();
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal menghapus plan: $e',
                                          ),
                                        ),
                                      );
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                } else {
                                  setState(() {
                                    _draftItems.remove(itemToRemove);
                                    _selectedDraftKeys.clear();
                                    _repository.saveDraft(
                                      userId: _session.employeeId ?? '',
                                      items: _draftItems,
                                      sourceType:
                                          _rawDraft?['sourceType']
                                              ?.toString() ??
                                          itemToRemove['sourceType']
                                              ?.toString() ??
                                          'ADDITIONAL',
                                      replaceItems: true,
                                    );
                                  });
                                }
                              },
                            ),
                          );
                        }, childCount: filtered.length),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Divider(color: AppColors.border),
                        ),
                      ),
                    ],

                    if (hasSubmitted) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'RENCANA DISETUJUI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              i == filteredSubmitted.length - 1 ? 20 : 8,
                            ),
                            child: _SubmittedPlanCard(
                              plan: filteredSubmitted[i],
                            ),
                          ),
                          childCount: filteredSubmitted.length,
                        ),
                      ),
                    ],

                    if (!hasDrafts && !hasSubmitted)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: AppColors.textDisabled,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Belum ada rencana kerja.',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Buat rencana dari menu "Create Task".',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
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
          ),
        ),

        // ─── STICKY CHECKOUT PANEL ─────────────────────────────────────
        if (hasDrafts)
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              80,
            ), // Padding extra 80px agar tidak tertimpa FAB "Create Task"
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Text(
                    hasSelected
                        ? '${_selectedDraftKeys.length} dari ${filtered.length} draft dipilih'
                        : 'Pilih draft untuk dikirim',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (hasSelected) ...[
                        IconButton(
                          onPressed: _isSubmitting ? null : _discardSelected,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF5350),
                          ),
                          tooltip: 'Hapus yang dipilih',
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSubmitting || !hasSelected
                              ? null
                              : _submitSelected,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.background,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Mengirim...' : 'Kirim ke Approval',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPill(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Alias for backward compat (job_plan_page.dart imports DraftTab).
class DraftTab extends StatelessWidget {
  const DraftTab({super.key});
  @override
  Widget build(BuildContext context) => BrowseTab(selectedDate: DateTime.now());
}
