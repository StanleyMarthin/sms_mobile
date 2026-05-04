import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';

import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../../../job_plan/domain/entities/job_plan.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../../qc/domain/repositories/qc_repository.dart';
import 'grouped_monitoring_pages.dart';
import '../widgets/countdown_dialogs.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key, this.focusCarId});

  final String? focusCarId;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final CountdownRepository _repository;
  late final JobPlanRepository _jobPlanRepository;
  late final QcRepository _qcRepository;
  List<CountdownUnit> _units = [];
  List<JobPlan> _plans = [];
  Map<String, String> _qcIdsByCoreId = {};
  Map<String, String> _unitStatuses = {};
  bool _isLoading = true;
  int _revisionListVersion = 0;

  List<CountdownUnit> _sortedUnits(List<CountdownUnit> items) {
    if (widget.focusCarId == null) return items;
    final ordered = List<CountdownUnit>.from(items);
    ordered.sort((a, b) {
      final aFocus = a.carId == widget.focusCarId ? 1 : 0;
      final bFocus = b.carId == widget.focusCarId ? 1 : 0;
      return bFocus.compareTo(aFocus);
    });
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = sl<CountdownRepository>();
    _jobPlanRepository = sl<JobPlanRepository>();
    _qcRepository = sl<QcRepository>();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final session = sl<SessionManager>();
    final role = session.role?.toLowerCase();
    try {
      final results = await Future.wait<dynamic>([
        _repository.getUnits(
          role: role ?? '',
          division: session.divisionName,
        ),
        _jobPlanRepository.getPlans().catchError((_) => <JobPlan>[]),
      ]);
      final units = results[0] as List<CountdownUnit>;
      final plans = results[1] as List<JobPlan>;
      final unitStatuses = <String, String>{
        for (var index = 0; index < units.length; index++)
          units[index].carId: units[index].status.toUpperCase(),
      };
      if (!mounted) return;
      setState(() {
        _units = _sortedUnits(units);
        _plans = plans;
        _unitStatuses = unitStatuses;
        _isLoading = false;
      });
    } catch (e) {
      // Countdown units are critical; plans are supplemental — fail gracefully
      if (!mounted) return;
      try {
        final units = await _repository.getUnits(
          role: role ?? '',
          division: session.divisionName,
        );
        final unitStatuses = <String, String>{
          for (var u in units) u.carId: u.status.toUpperCase(),
        };
        setState(() {
          _units = _sortedUnits(units);
          _plans = [];
          _unitStatuses = unitStatuses;
          _isLoading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final role = sl<SessionManager>().role?.toLowerCase();
    final isPmOrKp = role == 'pm' ||
        role == 'kp' ||
        role == 'manager_produksi' ||
        role == 'kepala_produksi' ||
        role == 'kepala_project';

    if (!isPmOrKp) {
      return _buildCountdownListView();
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const TabBar(
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.gold,
              tabs: [
                Tab(text: 'Countdown'),
                Tab(text: 'Approval Revisi'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              key: const PageStorageKey("cdTab"),
              children: [
                _buildCountdownListView(),
                _buildRevisionApprovalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownListView() {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: _loadUnits,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Instructional summary card intentionally hidden from UI.
          if (_units.isEmpty)
            _buildEmptyMessage(
                'Belum ada kendaraan countdown untuk ditampilkan.')
          else
            ..._units.map((unit) => _buildVehicleCard(context, unit)),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, CountdownUnit unit) {
    final progress = unit.progress / 100;
    final roleStr = sl<SessionManager>().role?.toLowerCase();
    final isPm = roleStr == 'pm' || roleStr == 'manager_produksi';
    final isFocused = widget.focusCarId == unit.carId;

    return InkWell(
      onTap: () => isPm
          ? _showPmUnitMonitoring(context, unit)
          : _showVehicleCountdown(context, unit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused ? AppColors.gold : AppColors.border,
            width: isFocused ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFocused)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Fokus',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold)),
              ),
            Row(
              children: [
                const Icon(Icons.directions_car_filled_outlined,
                    color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unit.unitName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'DL: ${unit.deliveryDate ?? '-'}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${unit.progress}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

  Widget _buildFilterBar({
    required String selectedSection,
    required String selectedPanel,
    required String selectedStatus,
    required List<String> sectionOptions,
    required List<String> panelOptions,
    required ValueChanged<String> onSectionChanged,
    required ValueChanged<String> onPanelChanged,
    required ValueChanged<String> onStatusChanged,
    required VoidCallback onReset,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Jobdesc',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final fields = [
                _buildDropdownFilter(
                  label: 'Section',
                  value: selectedSection,
                  items: sectionOptions,
                  labelBuilder: (value) =>
                      value == 'all' ? 'Semua Section' : value,
                  onChanged: (value) => onSectionChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
                _buildDropdownFilter(
                  label: 'Panel',
                  value: selectedPanel,
                  items: panelOptions,
                  labelBuilder: (value) =>
                      value == 'all' ? 'Semua Panel' : value,
                  onChanged: (value) => onPanelChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
                _buildDropdownFilter(
                  label: 'Status / Progress',
                  value: selectedStatus,
                  items: const [
                    'all',
                    'plan',
                    'proses',
                    'qcready',
                    'done',
                    'below50',
                    'above50',
                    'full',
                  ],
                  labelBuilder: _statusProgressLabel,
                  onChanged: (value) => onStatusChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...fields
                        .expand((field) => [field, const SizedBox(height: 12)]),
                    OutlinedButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh,
                          size: 16, color: AppColors.gold),
                      label: const Text('Reset',
                          style: TextStyle(color: AppColors.gold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
                        foregroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...fields,
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh,
                        size: 16, color: AppColors.gold),
                    label: const Text('Reset',
                        style: TextStyle(color: AppColors.gold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      foregroundColor: AppColors.gold,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String value) labelBuilder,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        decoration: InputDecoration(labelText: label),
        dropdownColor: AppColors.surfaceCard,
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child:
                    Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _statusChip(String status) {
    final visual = _statusVisual(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12, color: visual.color),
          const SizedBox(width: 6),
          Text(
            visual.shortLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: visual.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildRevisionApprovalTab() {
    return FutureBuilder<List<CountdownJobdesc>>(
      key: ValueKey(_revisionListVersion),
      future: _loadPendingRevisionRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? const <CountdownJobdesc>[];
        if (requests.isEmpty) {
          return RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surfaceCard,
            onRefresh: () async {
              await _loadUnits();
              if (mounted) setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                _RevisionSectionHeader(
                  title: 'Approval Revisi Countdown',
                  subtitle: 'Belum ada pengajuan revisi yang menunggu ACC PM.',
                ),
              ],
            ),
          );
        }

        final grouped = <String, List<CountdownJobdesc>>{};
        for (final request in requests) {
          final unitDivision = _units
              .firstWhere((u) => u.carId == request.carId,
                  orElse: () => CountdownUnit(
                      carId: request.carId,
                      unitName: 'Unknown',
                      owner: '',
                      progress: 0,
                      status: '',
                      division: 'UNKNOWN'))
              .division;
          grouped.putIfAbsent(unitDivision, () => <CountdownJobdesc>[]);
          grouped[unitDivision]!.add(request);
        }

        final divisions = grouped.keys.toList()..sort();
        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: () async {
            await _loadUnits();
            if (mounted) setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const _RevisionSectionHeader(
                title: 'Approval Revisi Countdown',
                subtitle:
                    'List divisi dan pengajuan revisi yang menunggu ACC PM.',
              ),
              const SizedBox(height: 10),
              ...divisions.map((division) {
                final divisionRequests = grouped[division]!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ExpansionTile(
                    collapsedIconColor: AppColors.textMuted,
                    iconColor: AppColors.gold,
                    title: Text(
                      division,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${divisionRequests.length} pengajuan',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: divisionRequests.map((request) {
                      final fallbackUnit = CountdownUnit(
                          carId: request.carId,
                          unitName: "-",
                          owner: "",
                          progress: 0,
                          status: "",
                          division: "");
                      final unitName = _units
                          .firstWhere(
                            (u) => u.carId == request.carId,
                            orElse: () => fallbackUnit,
                          )
                          .unitName;
                      return _buildRevisionRequestCard(request, unitName);
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevisionRequestCard(CountdownJobdesc request, String unitName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$unitName • ${request.panelName}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.jobdesc,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Pengaju: ${request.requestedRevisionByName ?? '-'} • ${request.requestedRevisionAt?.toString().split(' ')[0] ?? '-'}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Jam diajukan: ${(request.requestedRevisionHours ?? 0).toStringAsFixed(1)} jam',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Deadline saat ini ${request.deadlineDate} -> usulan ${request.requestedRevisionDeadline ?? '-'}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Alasan: ${request.requestedRevisionReason ?? '-'}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _rejectRevisionRequest(request);
                    if (!mounted) return;
                    setState(() {
                      _revisionListVersion++;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Pengajuan revisi ditolak.')),
                    );
                    await _loadUnits();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusLocked,
                    side: const BorderSide(color: AppColors.statusLocked),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _showApproveRevisionDialog(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusDone,
                    foregroundColor: AppColors.background,
                  ),
                  child: const Text('ACC'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<CountdownJobdesc>> _loadPendingRevisionRequests() async {
    final requests = await _repository.getRevisionRequests();

    // Convert List<CountdownJobdesc> directly mapped from repository
    final sorted = List<CountdownJobdesc>.from(requests);
    sorted.sort((a, b) {
      final aTime = a.requestedRevisionAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.requestedRevisionAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  Future<void> _showApproveRevisionDialog(CountdownJobdesc request) async {
    final approvedHoursCtrl = TextEditingController(
      text: (request.requestedRevisionHours ?? 0).toStringAsFixed(1),
    );
    var approvedDeadline =
        DateTime.tryParse(request.requestedRevisionDeadline ?? '') ??
            DateTime.tryParse(request.deadlineDate) ??
            DateTime.now();

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'ACC Revisi Countdown',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_units.firstWhere((u) => u.carId == request.carId, orElse: () => CountdownUnit(carId: request.carId, unitName: "-", owner: "", progress: 0, status: "", division: "")).unitName} • ${request.panelName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.jobdesc,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: approvedHoursCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Jam Disetujui',
                    helperText: 'PM bisa edit jam sebelum ACC.',
                  ),
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline Disetujui',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(_formatDate(approvedDeadline),
                      style: const TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.gold, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: approvedDeadline,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2028),
                    );
                    if (picked != null) {
                      setDialogState(() => approvedDeadline = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final approvedHours =
                    double.tryParse(approvedHoursCtrl.text.trim());
                if (approvedHours == null || approvedHours < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Jam disetujui tidak valid.')),
                  );
                  return;
                }
                await _approveRevisionRequest(
                  request: request,
                  approvedHours: approvedHours,
                  approvedDeadline: _formatDate(approvedDeadline),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusDone,
                foregroundColor: AppColors.background,
              ),
              child: const Text('ACC'),
            ),
          ],
        ),
      ),
    );

    if (approved == true && mounted) {
      setState(() {
        _revisionListVersion++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan revisi berhasil di-ACC.')),
      );
      await _loadUnits();
    }
  }

  Future<void> _approveRevisionRequest({
    required CountdownJobdesc request,
    required double approvedHours,
    required String approvedDeadline,
  }) async {
    await _repository.processRevisionRequest(
      requestId: request.id,
      approved: true,
      approvedHours: approvedHours,
      approvedDeadline: approvedDeadline,
    );
  }

  Future<void> _rejectRevisionRequest(CountdownJobdesc request) async {
    await _repository.processRevisionRequest(
      requestId: request.id,
      approved: false,
      approvedHours: request.requestedRevisionHours ?? 0.0,
      approvedDeadline:
          request.requestedRevisionDeadline ?? DateTime.now().toIso8601String(),
    );
  }

  String _statusProgressLabel(String value) {
    switch (value) {
      case 'proses':
        return 'Sedang Dikerjakan';
      case 'plan':
        return 'Belum Dikerjakan';
      case 'qcready':
        return 'Siap QC';
      case 'done':
        return 'Selesai';
      case 'below50':
        return 'Progress < 50%';
      case 'above50':
        return 'Progress 50% - 99%';
      case 'full':
        return 'Progress 100%';
      default:
        return 'Semua Status / Progress';
    }
  }

  List<JobPlan> _plansFor(String countdownId) {
    return _plans
        .where((plan) =>
            plan.coreId == countdownId &&
            plan.status.toUpperCase() != 'REJECTED')
        .toList();
  }

  double _plannedHoursFor(String countdownId) {
    return _plansFor(countdownId)
        .fold(0.0, (sum, plan) => sum + plan.targetHours);
  }

  double _remainingPlanHoursFor(CountdownJobdesc item) {
    final unallocatedHours =
        item.targetHoursRevised - _plannedHoursFor(item.id);
    final remainingHours = item.remainingHours;
    final allowedHours =
        unallocatedHours < remainingHours ? unallocatedHours : remainingHours;
    return allowedHours > 0 ? allowedHours : 0;
  }

  int _activeFilterCount({
    required String selectedSection,
    required String selectedPanel,
    required String selectedStatus,
  }) {
    var count = 0;
    if (selectedSection != 'all') count++;
    if (selectedPanel != 'all') count++;
    if (selectedStatus != 'all') count++;
    return count;
  }

  List<String> _activeFilterLabels({
    required String selectedSection,
    required String selectedPanel,
    required String selectedStatus,
  }) {
    final labels = <String>[];
    if (selectedSection != 'all') labels.add(selectedSection);
    if (selectedPanel != 'all') labels.add(selectedPanel);
    if (selectedStatus != 'all') {
      labels.add(_statusProgressLabel(selectedStatus));
    }
    return labels;
  }

  Future<void> _showFilterSheet({
    required BuildContext context,
    required String selectedSection,
    required String selectedPanel,
    required String selectedStatus,
    required List<String> sectionOptions,
    required List<String> panelOptions,
    required ValueChanged<String> onSectionChanged,
    required ValueChanged<String> onPanelChanged,
    required ValueChanged<String> onStatusChanged,
    required VoidCallback onReset,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: _buildFilterBar(
              selectedSection: selectedSection,
              selectedPanel: selectedPanel,
              selectedStatus: selectedStatus,
              sectionOptions: sectionOptions,
              panelOptions: panelOptions,
              onSectionChanged: onSectionChanged,
              onPanelChanged: onPanelChanged,
              onStatusChanged: onStatusChanged,
              onReset: onReset,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVehicleCountdown(
      BuildContext context, CountdownUnit unit) async {
    final effectiveStatus = _unitStatuses[unit.carId] ?? unit.status;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupedUnitMonitoringPage(
          unit: unit,
          repository: _repository,
          effectiveUnitStatus: effectiveStatus,
          jobPlanRepository: _jobPlanRepository,
          qcIdsByCoreId: _qcIdsByCoreId,
          onRefreshNeeded: _loadUnits,
        ),
      ),
    );
  }

  // ─── PM Monitoring ───────────────────────────────────────────

  Future<void> _showPmUnitMonitoring(
      BuildContext context, CountdownUnit unit) async {
    final effectiveStatus = _unitStatuses[unit.carId] ?? unit.status;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupedUnitMonitoringPage(
          unit: unit,
          repository: _repository,
          effectiveUnitStatus: effectiveStatus,
          jobPlanRepository: _jobPlanRepository,
          qcIdsByCoreId: _qcIdsByCoreId,
          onRefreshNeeded: _loadUnits,
        ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    CountdownJobdesc item,
    CountdownUnit unit, {
    bool isPm = false,
  }) async {
    final rows = await _repository.getDetails(item.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.panelName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(item.jobdesc,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unit: ${unit.unitName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Section: ${item.sectionName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                          'Sisa jam kerja: ${item.remainingHours.toStringAsFixed(1)} jam',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                          'Status: ${_effectiveCountdownStatus(item)} • Progress: ${item.progress}%',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      if (_revisionStatusBanner(item) case final banner?) ...[
                        const SizedBox(height: 8),
                        _buildRevisionStatusBanner(banner),
                      ],
                      if (item.timeExtensionHours > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tambahan jam kerja: ${item.timeExtensionHours.toStringAsFixed(1)} jam • Target revisi ${item.targetHoursRevised.toStringAsFixed(1)} jam',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.orange),
                        ),
                      ],
                      if (item.qcValidationStatus == 'VALIDATED' &&
                          item.qcResultStatus == 'TIDAK_LOLOS') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Rework tervalidasi: ${item.qcEstimatedReworkHours?.toStringAsFixed(1) ?? '0.0'} jam • Deadline ${item.qcReworkDeadlineDate ?? '-'}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.statusLocked),
                        ),
                        if (_isRevisionPending(item)) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textMuted,
                                side: const BorderSide(color: AppColors.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.hourglass_top_rounded),
                              label: const Text('Menunggu ACC PM'),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                ),
                // Rework guidance banner intentionally hidden from UI.
                const SizedBox(height: 16),
                if (!isPm && _canOpenQc(item)) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openQc(context, item),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.fact_check_rounded),
                      label: const Text('Buka QC'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_plansFor(item.id).isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusDone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.statusDone.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'Plan aktif: ${_plansFor(item.id).length} item\nTeralokasi ${_plannedHoursFor(item.id).toStringAsFixed(1)} jam dari ${item.targetHoursRevised.toStringAsFixed(1)} jam\nSisa yang masih bisa dibuat ${_remainingPlanHoursFor(item).toStringAsFixed(1)} jam',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Detail yang sudah dikerjakan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  _buildEmptyMessage(
                      'Belum ada detail pekerjaan yang tercatat untuk jobdesc ini.')
                else
                  ...rows.map(
                    (row) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceInput,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row.employeeName} • ${row.job}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(row.detailJob,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Text(
                            '${row.workDate} • ${row.startTime} - ${row.finishTime}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Durasi ${row.durationHours.toStringAsFixed(1)} jam • Target ${row.targetHours.toStringAsFixed(1)} jam • Sisa ${row.remainingHours.toStringAsFixed(1)} jam',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                          if (row.overtimeHours > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Overtime ${row.overtimeHours.toStringAsFixed(1)} jam',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.orange),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _statusChip(row.status),
                              const SizedBox(width: 8),
                              Text(
                                'Progress ${row.percentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (!isPm)
                  SizedBox(
                    width: double.infinity,
                    child: item.isLockedByOtherDivision
                        ? FilledButton.icon(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  AppColors.background.withOpacity(0.5),
                              foregroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.lock_rounded),
                            label:
                                const Text('Terkunci (Dikerjakan Divisi Lain)'),
                          )
                        : _canOpenQc(item)
                            ? FilledButton.icon(
                                onPressed: () => _openQc(context, item),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.background,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.fact_check_rounded),
                                label: const Text('Lakukan QC'),
                              )
                            : !_canCreateTaskFromCountdown(item)
                                ? FilledButton.icon(
                                    onPressed: null,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    icon: const Icon(Icons.block_rounded),
                                    label: const Text('Task Tidak Bisa Dibuat'),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _markQcReady(
                                              context, item, sheetContext),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.gold,
                                            side: const BorderSide(
                                                color: AppColors.gold),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                          icon: const Icon(
                                              Icons.done_all_rounded,
                                              size: 20),
                                          label: const Text('Selesai'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: FilledButton.icon(
                                          onPressed: () async {
                                            final created =
                                                await CountdownDialogs
                                                    .showCreatePlanDialog(
                                              context: context,
                                              item: item,
                                              unit: unit,
                                              allUnitItems: const [],
                                              jobPlanRepository:
                                                  sl<JobPlanRepository>(),
                                              availablePlanHours:
                                                  _remainingPlanHoursFor(item),
                                            );
                                            if (created &&
                                                sheetContext.mounted) {
                                              Navigator.of(sheetContext).pop();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Task berhasil dibuat dari countdown.')),
                                              );
                                              _loadUnits();
                                            }
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.gold,
                                            foregroundColor:
                                                AppColors.background,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                          icon: const Icon(
                                              Icons.add_task_rounded),
                                          label:
                                              const Text('Buat Jobdesc Plan'),
                                        ),
                                      ),
                                    ],
                                  ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markQcReady(
    BuildContext context,
    CountdownJobdesc item,
    BuildContext sheetContext,
  ) async {
    try {
      await _repository.markAsQcReady(item.id);
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Status berhasil diubah ke Menunggu QC.')),
        );
        _loadUnits();
      }
    } catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan pekerjaan: $e')),
        );
      }
    }
  }

  bool _canCreateTaskFromCountdown(CountdownJobdesc item) {
    if (_isRevisionPending(item)) {
      return false;
    }
    final effectiveStatus = _effectiveCountdownStatus(item).toUpperCase();
    return effectiveStatus == 'PLAN' || effectiveStatus == 'PROGRESS';
  }

  bool _canOpenQc(CountdownJobdesc item) {
    final effectiveStatus = _effectiveCountdownStatus(item).toUpperCase();
    return effectiveStatus == 'READY_QC' ||
        effectiveStatus == 'WAITING_QC' ||
        item.qcValidationStatus == 'PENDING' ||
        item.qcLastStatus == 'READY_QC' ||
        item.qcLastStatus == 'WAITING_QC';
  }

  String _effectiveCountdownStatus(CountdownJobdesc item) {
    final s = item.status.toUpperCase();
    if (s == 'READY_QC' || s == 'WAITING_QC' || s == 'DONE') return s;
    if (item.qcLastStatus?.toUpperCase() == 'READY_QC') return 'READY_QC';
    if (item.qcLastStatus?.toUpperCase() == 'WAITING_QC') return 'WAITING_QC';
    return s;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  _CountdownStatusVisual _statusVisual(String status) {
    switch (status.toUpperCase()) {
      case 'DONE':
        return const _CountdownStatusVisual(
          shortLabel: 'DONE',
          hint: 'Selesai',
          color: AppColors.statusDone,
          icon: Icons.check_circle_rounded,
        );
      case 'WAITING_QC':
      case 'READY_QC':
        return const _CountdownStatusVisual(
          shortLabel: 'MENUNGGU QC',
          hint: 'Menunggu QC',
          color: AppColors.gold,
          icon: Icons.fact_check_rounded,
        );
      case 'PROSES':
        return const _CountdownStatusVisual(
          shortLabel: 'PROSES',
          hint: 'Sedang dikerjakan',
          color: AppColors.orange,
          icon: Icons.timelapse_rounded,
        );
      case 'PLAN':
      default:
        return const _CountdownStatusVisual(
          shortLabel: 'PLAN',
          hint: 'Belum dikerjakan',
          color: AppColors.textMuted,
          icon: Icons.schedule_rounded,
        );
    }
  }

  bool _isRevisionPending(CountdownJobdesc item) {
    return item.revisionRequestStatus?.toUpperCase() == 'REQUESTED';
  }

  _RevisionBannerData? _revisionStatusBanner(CountdownJobdesc item) {
    final status = item.revisionRequestStatus?.toUpperCase();
    if (status == null || status.isEmpty) return null;

    switch (status) {
      case 'REQUESTED':
        return _RevisionBannerData(
          color: AppColors.orange,
          icon: Icons.hourglass_top_rounded,
          title: 'Revisi sudah diajukan, menunggu ACC PM.',
          detail:
              'Usulan: +${(item.requestedRevisionHours ?? 0).toStringAsFixed(1)} jam • Deadline usulan ${item.requestedRevisionDeadline ?? item.deadlineDate}',
        );
      case 'APPROVED':
        return null;
      case 'REJECTED':
        return _RevisionBannerData(
          color: AppColors.statusLocked,
          icon: Icons.cancel_rounded,
          title: 'Pengajuan revisi ditolak PM.',
          detail: item.rejectedRevisionByName != null
              ? 'Ditolak oleh ${item.rejectedRevisionByName}. Silakan ajukan ulang dengan penyesuaian.'
              : 'Silakan ajukan ulang dengan penyesuaian.',
        );
      default:
        return null;
    }
  }

  Widget _buildRevisionStatusBanner(_RevisionBannerData banner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: banner.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: banner.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(banner.icon, size: 16, color: banner.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: banner.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banner.detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _qcIdFor(String coreId) {
    return _qcIdsByCoreId[coreId];
  }

  void _openQc(BuildContext context, CountdownJobdesc item) {
    final qcId = _qcIdFor(item.id);
    if (qcId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data QC untuk jobdesc ini belum tersedia.')),
      );
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route is! PopupRoute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final query = Uri(
        queryParameters: {
          'qcId': qcId,
          'date': item.deadlineDate,
        },
      ).query;
      this.context.push('/qc?$query');
    });
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

class _CountdownStatusVisual {
  const _CountdownStatusVisual({
    required this.shortLabel,
    required this.hint,
    required this.color,
    required this.icon,
  });

  final String shortLabel;
  final String hint;
  final Color color;
  final IconData icon;
}

class _RevisionBannerData {
  const _RevisionBannerData({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String detail;
}

class _RevisionSectionHeader extends StatelessWidget {
  const _RevisionSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
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
    );
  }
}
