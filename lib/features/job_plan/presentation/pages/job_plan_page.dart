import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/dummy_data.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';
import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';

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

class _JobPlanPageState extends State<JobPlanPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _showPlanTab;
  late bool _canCreate;
  late final JobPlanRepository _repository;
  late DateTime _selectedDate;
  List<JobPlan> _plans = [];
  bool _isLoading = true;
  bool _didHandleInitialSource = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadPlans();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialCreateFlow();
    });
  }

  String get _selectedDateStr =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  List<JobPlan> get _visiblePlans =>
      _plans.where((plan) {
        if (plan.deadline != _selectedDateStr) return false;
        final sourceType = widget.initialSourceType?.toUpperCase();
        if (sourceType != null && sourceType.isNotEmpty && plan.sourceType != sourceType) {
          return false;
        }
        final sourceRefId = widget.initialSourceRefId;
        if (sourceRefId != null && sourceRefId.isNotEmpty && plan.sourceRefId != sourceRefId) {
          return false;
        }
        return true;
      }).toList();

  Future<void> _loadPlans() async {
    final plans = await _repository.getPlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _isLoading = false;
    });
  }

  Future<void> _handleInitialCreateFlow() async {
    if (_didHandleInitialSource || !widget.autoOpenCreate || !mounted) return;
    _didHandleInitialSource = true;
    final canCreate = hasPermission(sl<SessionManager>().role, Permission.jobPlanCreate);
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
      context.go('/countdown');
      return;
    }
    await _showCreateSourceSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final role = sl<SessionManager>().role;
    final canCreate = hasPermission(role, Permission.jobPlanCreate);
    final canReview = hasPermission(role, Permission.jobPlanReview);
    final canUpdate = hasPermission(role, Permission.jobPlanUpdate);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DateFilterBar(
                selectedDate: _selectedDate,
                onDateChanged: (date) => setState(() => _selectedDate = date),
                label: 'Plan',
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Create/review hint intentionally hidden from UI.
                        if (_visiblePlans.isEmpty)
                          _buildEmptyState()
                        else
                          ..._visiblePlans.map(
                            (plan) => _PlanCard(
                              plan: plan,
                              role: role,
                              canReview: canReview,
                              canUpdate: canUpdate,
                              onApprove: () => _reviewPlan(plan.planId, approved: true),
                              onReject: () => _reviewPlan(plan.planId, approved: false),
                              onUpdate: () => _showUpdateDialog(context, plan),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        if (canCreate)
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
    );
  }

  Future<void> _reviewPlan(String planId, {required bool approved}) async {
    await _repository.reviewPlan(planId: planId, approved: approved);
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
          Icon(Icons.event_busy_outlined,
              size: 48, color: AppColors.textDisabled),
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
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.directions_car_outlined,
                title: 'Dari Countdown',
                subtitle: '',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/countdown');
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
                subtitle: 'Input job baru dengan dropdown unit, panel, dan job sesuai master DB.',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAdditionalTaskDialog(context);
                },
              ),
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
    final currentDivision = session.divisionName ?? '';
    final items = DummyWorkOrders.seedRecords()
        .where((wo) => wo['woType'] == 'WO')
        .where((wo) => wo['status'] != 'DONE' && wo['status'] != 'REJECTED')
        .where((wo) => wo['toDivision'] == currentDivision)
        .map(
          (wo) => _PlanSourceSeed(
            sourceLabel: wo['woType'] as String,
            sourceType: 'WO',
            sourceRefId: wo['id'] as String,
            sourceRoute: '/work-orders?woId=${wo['id']}',
            carId: wo['carId'] as String,
            coreId: wo['coreId'] as String,
            unitName: wo['unitName'] as String,
            panelName: wo['panelName'] as String,
            assignedDivision: wo['toDivision'] as String,
            description: wo['description'] as String,
            targetHours: (wo['estimatedHours'] as num).toDouble(),
          ),
        )
        .toList();
    final filteredItems = sourceRefId == null || sourceRefId.isEmpty
        ? items
        : items.where((item) => item.sourceRefId == sourceRefId).toList();
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
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
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
                  separatorBuilder: (_, __) => const Divider(color: AppColors.border),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Future<void> _showAdditionalTaskDialog(BuildContext context) async {
    final created = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdditionalPlanFormPage(
          initialDate: _selectedDate,
        ),
      ),
    );
    if (created == true) {
      setState(() => _isLoading = true);
      await _loadPlans();
    }
  }

  Future<void> _showPlanFormDialog(BuildContext context, {required _PlanSourceSeed seed}) async {
    final created = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SourcePlanFormPage(
          seed: seed,
          initialDate: _selectedDate,
        ),
      ),
    );
    if (created == true && context.mounted) {
      setState(() => _isLoading = true);
      await _loadPlans();
      if (!context.mounted) return;
      context.go(seed.sourceRoute);
    }
  }

  void _showUpdateDialog(BuildContext context, JobPlan plan) {
    final hoursCtrl = TextEditingController(text: '${plan.targetHours}');
    final deadlineCtrl = TextEditingController(text: plan.deadline);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Update Plan', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(controller: hoursCtrl, label: 'New Target Hours'),
            const SizedBox(height: 10),
            _input(controller: deadlineCtrl, label: 'New Deadline'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              await _repository.updatePlan(
                planId: plan.planId,
                targetHours:
                    double.tryParse(hoursCtrl.text.trim()) ?? plan.targetHours,
                deadline: deadlineCtrl.text.trim(),
              );
              if (!context.mounted) return;
              setState(() => _isLoading = true);
              await _loadPlans();
              if (!context.mounted) return;
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.background),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _input({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }

}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.role,
    required this.canReview,
    required this.canUpdate,
    required this.onApprove,
    required this.onReject,
    required this.onUpdate,
  });

  final JobPlan plan;
  final String? role;
  final bool canReview;
  final bool canUpdate;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final status = plan.status;
    final canReviewThis = canReview && _canReviewStatus(role, status);
    final canUpdateThis =
        canUpdate && status != 'DONE' && status != 'APPROVED';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  '${plan.unitName} • ${plan.panelName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            'Assigned: ${plan.assignedTo} • ${plan.assignedDivision} • ${plan.targetHours} jam',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Tanggal ${plan.workDate} • ${plan.startTime}-${plan.finishTime}${plan.isOvertime ? ' • Lembur' : ''} • Sumber ${plan.sourceType}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (plan.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Catatan: ${plan.note}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
          if (canReviewThis || canUpdateThis) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canUpdateThis)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                if (canUpdateThis && canReviewThis) const SizedBox(width: 8),
                if (canReviewThis)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusLocked,
                        side: const BorderSide(color: AppColors.statusLocked),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                if (canReviewThis) const SizedBox(width: 8),
                if (canReviewThis)
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusDone,
                        foregroundColor: AppColors.background,
                      ),
                      child: Text(status == 'PENDING_ADV' ? 'Acc Adv' : 'Acc PM'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _canReviewStatus(String? role, String status) {
    return switch (role) {
      'adv' => status == 'PENDING_ADV',
      'pm' => status == 'PENDING_PM',
      _ => false,
    };
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
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
}

class _AdditionalPlanFormPage extends StatefulWidget {
  const _AdditionalPlanFormPage({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_AdditionalPlanFormPage> createState() => _AdditionalPlanFormPageState();
}

class _AdditionalPlanFormPageState extends State<_AdditionalPlanFormPage> {
  late final JobPlanRepository _repository;
  late final String _currentDivision;
  late final List<Map<String, dynamic>> _cars;
  late final List<Map<String, dynamic>> _panels;
  late final List<Map<String, dynamic>> _jobTypes;
  late final List<Map<String, dynamic>> _employees;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _noteCtrl;

  String? _selectedUnitId;
  String? _selectedPanel;
  String? _selectedJob;
  String? _selectedEmployeeId;
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 12, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    final session = sl<SessionManager>();
    _currentDivision = session.divisionName ?? 'MECHANIC';
    _cars = DummyCars.all.map((item) => Map<String, dynamic>.from(item)).toList();
    _panels = DummyPanels.all
        .where((item) => item['division'] == _currentDivision)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _jobTypes = DummyJobTypes.all
        .where((item) => item['division'] == _currentDivision)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _employees = DummyEmployees.all
        .where((item) => item['role'] == 'op' && item['division'] == _currentDivision)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _selectedUnitId = _cars.isNotEmpty ? _cars.first['id'] as String : null;
    _selectedPanel = _panels.isNotEmpty ? _panels.first['name'] as String : null;
    _selectedJob = _jobTypes.isNotEmpty ? _jobTypes.first['job_name'] as String : null;
    _selectedEmployeeId = _employees.isNotEmpty ? _employees.first['id'] as String : null;
    _selectedDate = widget.initialDate;
    _hoursCtrl = TextEditingController(text: '4.0');
    _hoursCtrl.addListener(_syncFinishTimeFromHours);
    _noteCtrl = TextEditingController();
    _finishTime = _calculateFinishTime(
      startTime: _startTime,
      durationHours: 4.0,
    );
  }

  @override
  void dispose() {
    _hoursCtrl.removeListener(_syncFinishTimeFromHours);
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _syncFinishTimeFromHours() {
    if (!mounted || _finishTimeEdited) return;
    final targetHours = double.tryParse(_hoursCtrl.text.trim());
    if (targetHours == null || targetHours <= 0) return;
    final nextFinishTime = _calculateFinishTime(
      startTime: _startTime,
      durationHours: targetHours,
    );
    if (nextFinishTime.hour == _finishTime.hour &&
        nextFinishTime.minute == _finishTime.minute) {
      return;
    }
    setState(() => _finishTime = nextFinishTime);
  }

  @override
  Widget build(BuildContext context) {
    final selectedUnit = _cars.where((item) => item['id'] == _selectedUnitId).firstOrNull;
    final selectedEmployee = _employees.where((item) => item['id'] == _selectedEmployeeId).firstOrNull;
    final selectedEmployeeName = _selectedEmployeeId == null || selectedEmployee == null
        ? '-'
        : selectedEmployee['full_name'] as String;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Create Task Tambahan'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Tambahan hanya boleh memilih master data yang sudah ada. Unit kendaraan, panel, dan job tidak bisa diketik bebas.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormSection(
                    title: 'Data Pekerjaan',
                    child: Column(
                      children: [
                        _SearchFieldTile(
                          label: 'Unit Kendaraan',
                          value: selectedUnit?['unit_name'] as String?,
                          hint: 'Pilih unit dari master data',
                          onTap: () async {
                            final selected = await _showMasterSearchPicker(
                              context,
                              title: 'Pilih Unit Kendaraan',
                              items: _cars,
                              labelBuilder: (item) => item['unit_name'] as String,
                              subtitleBuilder: (item) => item['owner_name'] as String? ?? '',
                            );
                            if (selected != null) {
                              setState(() => _selectedUnitId = selected['id'] as String);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _SearchFieldTile(
                          label: 'Panel',
                          value: _selectedPanel,
                          hint: 'Pilih panel dari master data',
                          onTap: () async {
                            final selected = await _showMasterSearchPicker(
                              context,
                              title: 'Pilih Panel',
                              items: _panels,
                              labelBuilder: (item) => item['name'] as String,
                              subtitleBuilder: (item) => item['division'] as String? ?? '',
                            );
                            if (selected != null) {
                              setState(() => _selectedPanel = selected['name'] as String);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _SearchFieldTile(
                          label: 'Job / Deskripsi',
                          value: _selectedJob,
                          hint: 'Pilih job dari master data',
                          onTap: () async {
                            final selected = await _showMasterSearchPicker(
                              context,
                              title: 'Pilih Job',
                              items: _jobTypes,
                              labelBuilder: (item) => item['job_name'] as String,
                              subtitleBuilder: (item) => item['division'] as String? ?? '',
                            );
                            if (selected != null) {
                              setState(() => _selectedJob = selected['job_name'] as String);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _SearchFieldTile(
                          label: 'Orang Yang Mengerjakan',
                          value: selectedEmployee?['full_name'] as String?,
                          hint: 'Pilih anggota pelaksana',
                          onTap: () async {
                            final selected = await _showMasterSearchPicker(
                              context,
                              title: 'Pilih Pelaksana',
                              items: _employees,
                              labelBuilder: (item) => item['full_name'] as String,
                              subtitleBuilder: (item) => item['grade'] as String? ?? '',
                            );
                            if (selected != null) {
                              setState(() => _selectedEmployeeId = selected['id'] as String);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _hoursCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Target Hours'),
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
                          title: const Text('Tanggal Pengerjaan', style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(_formatDate(_selectedDate), style: const TextStyle(color: AppColors.textMuted)),
                          trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2027),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Jam Mulai', style: TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text(_formatTime(_startTime), style: const TextStyle(color: AppColors.textMuted)),
                                trailing: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: _startTime);
                                  if (picked != null) {
                                    setState(() {
                                      _startTime = picked;
                                      if (!_finishTimeEdited) {
                                        final targetHours = double.tryParse(_hoursCtrl.text.trim());
                                        if (targetHours != null && targetHours > 0) {
                                          _finishTime = _calculateFinishTime(
                                            startTime: _startTime,
                                            durationHours: targetHours,
                                          );
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Jam Selesai', style: TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text(_formatTime(_finishTime), style: const TextStyle(color: AppColors.textMuted)),
                                trailing: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: _finishTime);
                                  if (picked != null) {
                                    setState(() {
                                      _finishTime = picked;
                                      _finishTimeEdited = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile.adaptive(
                          value: _isOvertime,
                          onChanged: (value) => setState(() => _isOvertime = value),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.gold,
                          title: const Text('Jam lembur', style: TextStyle(color: AppColors.textPrimary)),
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
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Description / POK'),
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
                            'Unit: ${selectedUnit?['unit_name'] ?? '-'}\nPanel: ${_selectedPanel ?? '-'}\nJob: ${_selectedJob ?? '-'}\nOperator: $selectedEmployeeName\nDivisi Pelaksana: $_currentDivision',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                      onPressed: _isSaving ? null : () => _save(selectedUnit, selectedEmployee),
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

  Future<Map<String, dynamic>?> _showMasterSearchPicker(
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
            return label.contains(normalizedQuery) || subtitle.contains(normalizedQuery);
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
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                              separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                              itemBuilder: (_, index) {
                                final item = filteredItems[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(labelBuilder(item), style: const TextStyle(color: AppColors.textPrimary)),
                                  subtitle: Text(subtitleBuilder(item), style: const TextStyle(color: AppColors.textMuted)),
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

  Future<void> _save(
    Map<String, dynamic>? selectedUnit,
    Map<String, dynamic>? selectedEmployee,
  ) async {
    final targetHours = double.tryParse(_hoursCtrl.text.trim());
    if (selectedUnit == null || _selectedPanel == null || _selectedJob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit, panel, dan job wajib dipilih dari master data.')),
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
        const SnackBar(content: Text('Target hours harus lebih dari 0.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final sourceNote = <String>[
      'Sumber: ADDITIONAL',
      _isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak',
      if (_noteCtrl.text.trim().isNotEmpty) 'POK: ${_noteCtrl.text.trim()}',
    ].join(' | ');
    await _repository.createPlan(
      coreId: '',
      carId: selectedUnit['id'] as String,
      sourceType: 'ADDITIONAL',
      sourceRefId: '',
      unitName: selectedUnit['unit_name'] as String,
      panelName: _selectedPanel!,
      assignedDivision: _currentDivision,
      assignedUserId: _selectedEmployeeId!,
      assignedTo: selectedEmployee['full_name'] as String,
      description: _selectedJob!,
      targetHours: targetHours,
      workDate: _formatDate(_selectedDate),
      startTime: _formatTime(_startTime),
      finishTime: _formatTime(_finishTime),
      isOvertime: _isOvertime,
      note: sourceNote,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
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
  });

  final _PlanSourceSeed seed;
  final DateTime initialDate;

  @override
  State<_SourcePlanFormPage> createState() => _SourcePlanFormPageState();
}

class _SourcePlanFormPageState extends State<_SourcePlanFormPage> {
  late final JobPlanRepository _repository;
  late final List<Map<String, dynamic>> _employees;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _noteCtrl;
  String? _selectedEmployeeId;
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _finishTime = const TimeOfDay(hour: 12, minute: 0);
  bool _finishTimeEdited = false;
  bool _isOvertime = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<JobPlanRepository>();
    _employees = DummyEmployees.all
        .where((item) => item['role'] == 'op' && item['division'] == widget.seed.assignedDivision)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _selectedEmployeeId = _employees.isNotEmpty ? _employees.first['id'] as String : null;
    _selectedDate = widget.initialDate;
    _hoursCtrl = TextEditingController(text: widget.seed.targetHours.toStringAsFixed(1));
    _hoursCtrl.addListener(_syncFinishTimeFromHours);
    _noteCtrl = TextEditingController();
    _finishTime = _calculateFinishTime(
      startTime: _startTime,
      durationHours: widget.seed.targetHours,
    );
  }

  @override
  void dispose() {
    _hoursCtrl.removeListener(_syncFinishTimeFromHours);
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _syncFinishTimeFromHours() {
    if (!mounted || _finishTimeEdited) return;
    final targetHours = double.tryParse(_hoursCtrl.text.trim());
    if (targetHours == null || targetHours <= 0) return;
    final nextFinishTime = _calculateFinishTime(
      startTime: _startTime,
      durationHours: targetHours,
    );
    if (nextFinishTime.hour == _finishTime.hour &&
        nextFinishTime.minute == _finishTime.minute) {
      return;
    }
    setState(() => _finishTime = nextFinishTime);
  }

  @override
  Widget build(BuildContext context) {
    final selectedEmployee = _employees.where((item) => item['id'] == _selectedEmployeeId).firstOrNull;
    final selectedEmployeeName = _selectedEmployeeId == null || selectedEmployee == null
        ? '-'
        : selectedEmployee['full_name'] as String;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        title: Text('Create Task dari ${widget.seed.sourceLabel}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Sumber task: ${widget.seed.sourceLabel}. Unit, panel, dan jobdesc mengikuti sumber kerja dan tidak bisa diubah.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormSection(
                    title: 'Sumber Pekerjaan',
                    child: Column(
                      children: [
                        _SearchFieldTile(
                          label: 'Unit Kendaraan',
                          value: widget.seed.unitName,
                          hint: '-',
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _SearchFieldTile(
                          label: 'Panel',
                          value: widget.seed.panelName,
                          hint: '-',
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _SearchFieldTile(
                          label: 'Job / Deskripsi',
                          value: widget.seed.description,
                          hint: '-',
                          onTap: () {},
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
                          label: 'Orang Yang Mengerjakan',
                          value: selectedEmployeeName == '-' ? null : selectedEmployeeName,
                          hint: 'Pilih anggota pelaksana',
                          onTap: () async {
                            final selected = await _showEmployeePicker(context);
                            if (selected != null) {
                              setState(() => _selectedEmployeeId = selected['id'] as String);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _hoursCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Target Hours'),
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
                          title: const Text('Tanggal Pengerjaan', style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(_formatDate(_selectedDate), style: const TextStyle(color: AppColors.textMuted)),
                          trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2027),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Jam Mulai', style: TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text(_formatTime(_startTime), style: const TextStyle(color: AppColors.textMuted)),
                                trailing: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: _startTime);
                                  if (picked != null) {
                                    setState(() {
                                      _startTime = picked;
                                      if (!_finishTimeEdited) {
                                        final targetHours = double.tryParse(_hoursCtrl.text.trim());
                                        if (targetHours != null && targetHours > 0) {
                                          _finishTime = _calculateFinishTime(
                                            startTime: _startTime,
                                            durationHours: targetHours,
                                          );
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Jam Selesai', style: TextStyle(color: AppColors.textPrimary)),
                                subtitle: Text(_formatTime(_finishTime), style: const TextStyle(color: AppColors.textMuted)),
                                trailing: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
                                onTap: () async {
                                  final picked = await showTimePicker(context: context, initialTime: _finishTime);
                                  if (picked != null) {
                                    setState(() {
                                      _finishTime = picked;
                                      _finishTimeEdited = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile.adaptive(
                          value: _isOvertime,
                          onChanged: (value) => setState(() => _isOvertime = value),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.gold,
                          title: const Text('Jam lembur', style: TextStyle(color: AppColors.textPrimary)),
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
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Description / POK'),
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
                            'Unit: ${widget.seed.unitName}\nPanel: ${widget.seed.panelName}\nJob: ${widget.seed.description}\nOperator: $selectedEmployeeName\nDivisi Pelaksana: ${widget.seed.assignedDivision}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                      onPressed: _isSaving ? null : () => _save(selectedEmployeeName),
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

  Future<Map<String, dynamic>?> _showEmployeePicker(BuildContext context) async {
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
          final filteredItems = _employees.where((item) {
            final name = (item['full_name'] as String).toLowerCase();
            final grade = ((item['grade'] as String?) ?? '').toLowerCase();
            final normalizedQuery = query.toLowerCase();
            return name.contains(normalizedQuery) || grade.contains(normalizedQuery);
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                              separatorBuilder: (_, __) => const Divider(color: AppColors.border),
                              itemBuilder: (_, index) {
                                final item = filteredItems[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item['full_name'] as String, style: const TextStyle(color: AppColors.textPrimary)),
                                  subtitle: Text(item['grade'] as String? ?? '', style: const TextStyle(color: AppColors.textMuted)),
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

  Future<void> _save(String selectedEmployeeName) async {
    final targetHours = double.tryParse(_hoursCtrl.text.trim());
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelaksana terlebih dahulu.')),
      );
      return;
    }
    if (targetHours == null || targetHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target hours harus lebih dari 0.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final sourceNote = <String>[
      'Sumber: ${widget.seed.sourceLabel}',
      _isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak',
      if (_noteCtrl.text.trim().isNotEmpty) 'POK: ${_noteCtrl.text.trim()}',
    ].join(' | ');
    await _repository.createPlan(
      coreId: widget.seed.coreId,
      carId: widget.seed.carId,
      sourceType: widget.seed.sourceType,
      sourceRefId: widget.seed.sourceRefId,
      unitName: widget.seed.unitName,
      panelName: widget.seed.panelName,
      assignedDivision: widget.seed.assignedDivision,
      assignedUserId: _selectedEmployeeId!,
      assignedTo: selectedEmployeeName,
      description: widget.seed.description,
      targetHours: targetHours,
      workDate: _formatDate(_selectedDate),
      startTime: _formatTime(_startTime),
      finishTime: _formatTime(_finishTime),
      isOvertime: _isOvertime,
      note: sourceNote,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

TimeOfDay _calculateFinishTime({
  required TimeOfDay startTime,
  required double durationHours,
}) {
  final totalMinutes = (durationHours * 60).round();
  final startMinutes = (startTime.hour * 60) + startTime.minute;
  final finishMinutes = (startMinutes + totalMinutes) % (24 * 60);
  return TimeOfDay(
    hour: finishMinutes ~/ 60,
    minute: finishMinutes % 60,
  );
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
            color: value?.isNotEmpty == true ? AppColors.textPrimary : AppColors.textMuted,
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
