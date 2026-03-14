import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../../../job_plan/domain/entities/job_plan.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../../qc/domain/repositories/qc_repository.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key, this.focusCarId});

  final String? focusCarId;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  late final CountdownRepository _repository;
  late final JobPlanRepository _jobPlanRepository;
  late final QcRepository _qcRepository;
  late final LocalMockApiStore _store;
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
    _repository = sl<CountdownRepository>();
    _jobPlanRepository = sl<JobPlanRepository>();
    _qcRepository = sl<QcRepository>();
    _store = sl<LocalMockApiStore>();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final session = sl<SessionManager>();
    final results = await Future.wait<dynamic>([
      _repository.getUnits(
        role: session.role,
        division: session.divisionName,
      ),
      _jobPlanRepository.getPlans(),
    ]);
    final units = results[0] as List<CountdownUnit>;
    final plans = results[1] as List<JobPlan>;
    final countdownGroups = await Future.wait(
      units.map((unit) => _repository.getCountdowns(unit.carId)),
    );
    final qcIdsByCoreId = <String, String>{};
    final coreIds = countdownGroups
        .expand((group) => group.map((item) => item.id))
        .toSet()
        .toList();
    final qcItems = await Future.wait(
      coreIds.map((coreId) => _qcRepository.findQcItemByCoreId(coreId)),
    );
    for (final qcItem in qcItems) {
      if (qcItem != null) {
        qcIdsByCoreId[qcItem.coreId] = qcItem.qcId;
      }
    }
    final unitStatuses = <String, String>{
      for (var index = 0; index < units.length; index++)
        units[index].carId: _deriveUnitStatus(
          unit: units[index],
          items: countdownGroups[index],
        ),
    };
    if (!mounted) return;
    setState(() {
      _units = _sortedUnits(units);
      _plans = plans;
      _qcIdsByCoreId = qcIdsByCoreId;
      _unitStatuses = unitStatuses;
      _isLoading = false;
    });
    await _notifyKdApprovedRevisions(session);
  }

  Future<void> _notifyKdApprovedRevisions(SessionManager session) async {
    if (!mounted) return;
    if (session.role != 'kd') return;

    final countdowns = await _store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );

    final approvedForCurrentKd = <Map<String, dynamic>>[];
    for (final rows in countdowns.values) {
      for (final row in rows) {
        final requestStatus = (row['extensionRequestStatus'] as String?)?.toUpperCase();
        final requestedById = row['extensionRequestedById'] as String?;
        final notifiedAt = row['extensionApprovedNotifiedAt'] as String?;
        if (requestStatus == 'APPROVED' && requestedById == session.userId && notifiedAt == null) {
          approvedForCurrentKd.add(row);
        }
      }
    }

    if (approvedForCurrentKd.isEmpty) return;

    final first = approvedForCurrentKd.first;
    final approvedHours = (first['extensionApprovedHours'] as num?)?.toDouble() ??
        (first['extensionRequestedHours'] as num?)?.toDouble() ??
        0.0;
    final approvedDeadline = first['extensionApprovedDeadline'] as String? ??
        first['deadlineDate'] as String? ??
        '-';
    final count = approvedForCurrentKd.length;
    final text = count == 1
        ? 'Revisi countdown di-ACC PM: +${approvedHours.toStringAsFixed(1)} jam, deadline $approvedDeadline.'
        : '$count pengajuan revisi countdown sudah di-ACC PM.';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }

    for (final rows in countdowns.values) {
      for (final row in rows) {
        final requestStatus = (row['extensionRequestStatus'] as String?)?.toUpperCase();
        final requestedById = row['extensionRequestedById'] as String?;
        final notifiedAt = row['extensionApprovedNotifiedAt'] as String?;
        if (requestStatus == 'APPROVED' && requestedById == session.userId && notifiedAt == null) {
          row['extensionApprovedNotifiedAt'] = DateTime.now().toIso8601String();
        }
      }
    }

    await _store.writeGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      value: countdowns,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final role = sl<SessionManager>().role;
    final isPm = role == 'pm';

    if (!isPm) {
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
            _buildEmptyMessage('Belum ada kendaraan countdown untuk ditampilkan.')
          else
            ..._units.map((unit) => _buildVehicleCard(context, unit)),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, CountdownUnit unit) {
    final progress = unit.progress / 100;
    final isPm = sl<SessionManager>().role == 'pm';
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
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Dibuka dari Monitoring',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            Row(
              children: [
                const Icon(Icons.directions_car_filled_outlined, color: AppColors.gold),
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
              'Target delivery: ${unit.deliveryDate ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                  labelBuilder: (value) => value == 'all' ? 'Semua Section' : value,
                  onChanged: (value) => onSectionChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
                _buildDropdownFilter(
                  label: 'Panel',
                  value: selectedPanel,
                  items: panelOptions,
                  labelBuilder: (value) => value == 'all' ? 'Semua Panel' : value,
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
                    ...fields.expand((field) => [field, const SizedBox(height: 12)]),
                    OutlinedButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                      label: const Text('Reset', style: TextStyle(color: AppColors.gold)),
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
                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                    label: const Text('Reset', style: TextStyle(color: AppColors.gold)),
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
                child: Text(labelBuilder(item)),
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
    return FutureBuilder<List<_CountdownRevisionRequest>>(
      key: ValueKey(_revisionListVersion),
      future: _loadPendingRevisionRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? const <_CountdownRevisionRequest>[];
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

        final grouped = <String, List<_CountdownRevisionRequest>>{};
        for (final request in requests) {
          grouped.putIfAbsent(request.division, () => <_CountdownRevisionRequest>[]);
          grouped[request.division]!.add(request);
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
                subtitle: 'List divisi dan pengajuan revisi yang menunggu ACC PM.',
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
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: divisionRequests
                        .map((request) => _buildRevisionRequestCard(request))
                        .toList(),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevisionRequestCard(_CountdownRevisionRequest request) {
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
            '${request.unitName} • ${request.panelName}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.jobdesc,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Pengaju: ${request.requestedByName} • ${request.requestedAtLabel}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Jam diajukan: ${request.requestedHours.toStringAsFixed(1)} jam',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Deadline saat ini ${request.currentDeadline} -> usulan ${request.requestedDeadline}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Alasan: ${request.reason}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _rejectRevisionRequest(request);
                    if (!mounted) return;
                    setState(() { _revisionListVersion++; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengajuan revisi ditolak.')),
                    );
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

  Future<List<_CountdownRevisionRequest>> _loadPendingRevisionRequests() async {
    final grouped = await _store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );
    final unitByCar = {for (final unit in _units) unit.carId: unit};
    final requests = <_CountdownRevisionRequest>[];

    for (final entry in grouped.entries) {
      final unit = unitByCar[entry.key];
      for (final row in entry.value) {
        final requestStatus = (row['extensionRequestStatus'] as String?)?.toUpperCase();
        if (requestStatus != 'REQUESTED') continue;
        final requestedAtRaw = row['extensionRequestedAt'] as String?;
        final requestedAt = DateTime.tryParse(requestedAtRaw ?? '');
        requests.add(
          _CountdownRevisionRequest(
            countdownId: row['id'] as String? ?? '',
            carId: entry.key,
            unitName: unit?.unitName ?? (row['unitName'] as String? ?? '-'),
            division: unit?.division ?? (row['division'] as String? ?? 'UNKNOWN'),
            panelName: row['panelName'] as String? ?? '-',
            jobdesc: row['jobdesc'] as String? ?? '-',
            currentDeadline: row['deadlineDate'] as String? ?? '-',
            requestedDeadline: row['extensionRequestedDeadline'] as String? ?? (row['deadlineDate'] as String? ?? '-'),
            requestedHours: (row['extensionRequestedHours'] as num?)?.toDouble() ?? 0,
            reason: row['extensionRequestReason'] as String? ?? '-',
            requestedByName: row['extensionRequestedByName'] as String? ?? '-',
            requestedAt: requestedAt,
          ),
        );
      }
    }

    requests.sort((a, b) {
      final aTime = a.requestedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.requestedAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return requests;
  }

  Future<void> _showApproveRevisionDialog(_CountdownRevisionRequest request) async {
    final approvedHoursCtrl = TextEditingController(
      text: request.requestedHours.toStringAsFixed(1),
    );
    var approvedDeadline = DateTime.tryParse(request.requestedDeadline) ??
        DateTime.tryParse(request.currentDeadline) ??
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
                  '${request.unitName} • ${request.panelName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.jobdesc,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: approvedHoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Jam Disetujui',
                    helperText: 'PM bisa edit jam sebelum ACC.',
                  ),
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline Disetujui', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(_formatDate(approvedDeadline), style: const TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
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
                final approvedHours = double.tryParse(approvedHoursCtrl.text.trim());
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
      setState(() { _revisionListVersion++; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan revisi berhasil di-ACC.')),
      );
      await _loadUnits();
    }
  }

  Future<void> _approveRevisionRequest({
    required _CountdownRevisionRequest request,
    required double approvedHours,
    required String approvedDeadline,
  }) async {
    final countdowns = await _store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );
    final session = sl<SessionManager>();

    for (final entry in countdowns.entries) {
      final index = entry.value.indexWhere((row) => row['id'] == request.countdownId);
      if (index == -1) continue;

      final countdownItem = entry.value[index];
      final currentExtension = (countdownItem['timeExtensionHours'] as num?)?.toDouble() ?? 0.0;
      final currentTargetRevised = (countdownItem['targetHoursRevised'] as num?)?.toDouble() ?? 0.0;
      final currentRemaining = (countdownItem['remainingHours'] as num?)?.toDouble() ?? 0.0;

      countdownItem['timeExtensionHours'] = currentExtension + approvedHours;
      countdownItem['targetHoursRevised'] = currentTargetRevised + approvedHours;
      countdownItem['remainingHours'] = currentRemaining + approvedHours;
      countdownItem['deadlineDate'] = approvedDeadline;
      countdownItem['extensionRequestStatus'] = 'APPROVED';
      countdownItem['extensionApprovedByName'] = session.fullName ?? 'PM';
      countdownItem['extensionApprovedAt'] = DateTime.now().toIso8601String();
      countdownItem['extensionApprovedHours'] = approvedHours;
      countdownItem['extensionApprovedDeadline'] = approvedDeadline;
      countdownItem['extensionRejectedByName'] = null;
      countdownItem['extensionRejectedAt'] = null;
      break;
    }

    await _store.writeGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      value: countdowns,
    );
  }

  Future<void> _rejectRevisionRequest(_CountdownRevisionRequest request) async {
    final countdowns = await _store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );
    final session = sl<SessionManager>();

    for (final entry in countdowns.entries) {
      final index = entry.value.indexWhere((row) => row['id'] == request.countdownId);
      if (index == -1) continue;
      final countdownItem = entry.value[index];
      countdownItem['extensionRequestStatus'] = 'REJECTED';
      countdownItem['extensionRejectedByName'] = session.fullName ?? 'PM';
      countdownItem['extensionRejectedAt'] = DateTime.now().toIso8601String();
      countdownItem['extensionApprovedByName'] = null;
      countdownItem['extensionApprovedAt'] = null;
      countdownItem['extensionApprovedHours'] = null;
      countdownItem['extensionApprovedDeadline'] = null;
      break;
    }

    await _store.writeGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      value: countdowns,
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
            plan.coreId == countdownId && plan.status.toUpperCase() != 'REJECTED')
        .toList();
  }

  double _plannedHoursFor(String countdownId) {
    return _plansFor(countdownId)
        .fold(0.0, (sum, plan) => sum + plan.targetHours);
  }

  double _remainingPlanHoursFor(CountdownJobdesc item) {
    final unallocatedHours = item.targetHoursRevised - _plannedHoursFor(item.id);
    final remainingHours = item.remainingHours;
    final allowedHours = unallocatedHours < remainingHours
        ? unallocatedHours
        : remainingHours;
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
    if (selectedStatus != 'all') labels.add(_statusProgressLabel(selectedStatus));
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

  Future<void> _showVehicleCountdown(BuildContext context, CountdownUnit unit) async {
    final isPm = sl<SessionManager>().role == 'pm';
    final jobdescs = await _repository.getCountdowns(unit.carId);
    if (!context.mounted) return;

    var selectedSection = 'all';
    var selectedPanel = 'all';
    var selectedStatus = 'all';

    List<String> sectionOptions() {
      final values = jobdescs.map((item) => item.sectionName).toSet().toList()..sort();
      return ['all', ...values];
    }

    List<String> panelOptions() {
      final values = jobdescs.map((item) => item.panelName).toSet().toList()..sort();
      return ['all', ...values];
    }

    List<CountdownJobdesc> visibleItems() {
      final filtered = jobdescs.where((item) {
        final matchesSection = selectedSection == 'all' || item.sectionName == selectedSection;
        final matchesPanel = selectedPanel == 'all' || item.panelName == selectedPanel;
        final matchesStatus = selectedStatus == 'all' || _matchesStatusProgressWithValue(item, selectedStatus);
        return matchesSection && matchesPanel && matchesStatus;
      }).toList();
      filtered.sort((a, b) {
        final aDate = DateTime.tryParse(a.deadlineDate);
        final bDate = DateTime.tryParse(b.deadlineDate);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      return filtered;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final items = visibleItems();
          final activeFilterCount = _activeFilterCount(
            selectedSection: selectedSection,
            selectedPanel: selectedPanel,
            selectedStatus: selectedStatus,
          );
          final activeFilterLabels = _activeFilterLabels(
            selectedSection: selectedSection,
            selectedPanel: selectedPanel,
            selectedStatus: selectedStatus,
          );
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.94,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${unit.unitName} • ${unit.owner}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () => _showFilterSheet(
                                context: sheetContext,
                                selectedSection: selectedSection,
                                selectedPanel: selectedPanel,
                                selectedStatus: selectedStatus,
                                sectionOptions: sectionOptions(),
                                panelOptions: panelOptions(),
                                onSectionChanged: (value) => setSheetState(() => selectedSection = value),
                                onPanelChanged: (value) => setSheetState(() => selectedPanel = value),
                                onStatusChanged: (value) => setSheetState(() => selectedStatus = value),
                                onReset: () => setSheetState(() {
                                  selectedSection = 'all';
                                  selectedPanel = 'all';
                                  selectedStatus = 'all';
                                }),
                              ),
                              icon: const Icon(Icons.tune_rounded, color: AppColors.gold),
                              tooltip: 'Filter',
                              visualDensity: VisualDensity.compact,
                            ),
                            if (activeFilterCount > 0)
                              Positioned(
                                right: 4,
                                top: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$activeFilterCount',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.background,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (activeFilterLabels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...activeFilterLabels.map(
                              (label) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setSheetState(() {
                                selectedSection = 'all';
                                selectedPanel = 'all';
                                selectedStatus = 'all';
                              }),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textMuted,
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: items.isEmpty
                          ? _buildEmptyMessage('Tidak ada jobdesc countdown yang cocok dengan filter saat ini.')
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final plannedHours = _plannedHoursFor(item.id);
                                final remainingPlanHours = _remainingPlanHoursFor(item);
                                final hasPlan = plannedHours > 0;
                                final effectiveStatus = _effectiveCountdownStatus(item);
                                final canOpenQc = _canOpenQc(item) && !isPm;
                                return InkWell(
                                  onTap: () => _showDetail(context, item, unit, isPm: isPm),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceInput,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.panelName,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.jobdesc,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                _statusChip(effectiveStatus),
                                                if (canOpenQc) ...[
                                                  const SizedBox(height: 8),
                                                  OutlinedButton.icon(
                                                    onPressed: () => _openQc(context, item),
                                                    icon: const Icon(Icons.fact_check_rounded, size: 14),
                                                    label: const Text('QC'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: AppColors.gold,
                                                      side: const BorderSide(color: AppColors.gold),
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        LinearProgressIndicator(
                                          value: item.progress / 100,
                                          minHeight: 8,
                                          backgroundColor: AppColors.border,
                                          color: AppColors.gold,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${item.progress}% • Sisa ${item.remainingHours.toStringAsFixed(1)} jam • Deadline ${item.deadlineDate}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                        if (_revisionStatusBanner(item) case final banner?) ...[
                                          const SizedBox(height: 8),
                                          _buildRevisionStatusBanner(banner),
                                        ],
                                        if (_canRequestCountdownRevision(item)) ...[
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                await _showCountdownRevisionDialog(
                                                  context: context,
                                                  item: item,
                                                );
                                              },
                                              icon: const Icon(Icons.more_time_rounded, size: 16),
                                              label: const Text('Ajukan Revisi Countdown'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.orange,
                                                side: const BorderSide(color: AppColors.orange),
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (_isRevisionPending(item)) ...[
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: OutlinedButton.icon(
                                              onPressed: null,
                                              icon: const Icon(Icons.hourglass_top_rounded, size: 16),
                                              label: const Text('Menunggu ACC PM'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.textMuted,
                                                side: const BorderSide(color: AppColors.border),
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          hasPlan
                                              ? '${item.sectionName} • Teralokasi ${plannedHours.toStringAsFixed(1)} jam • Sisa plan ${remainingPlanHours.toStringAsFixed(1)} jam'
                                              : '${item.sectionName} • Belum ada plan',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasPlan ? AppColors.statusDone : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  // ─── PM Monitoring ───────────────────────────────────────────

  Future<void> _showPmUnitMonitoring(BuildContext context, CountdownUnit unit) async {
    final jobdescs = await _repository.getCountdowns(unit.carId);
    if (!context.mounted) return;

    final groupedByDivision = <String, List<CountdownJobdesc>>{};
    for (final item in jobdescs) {
      final division = unit.division.trim().isEmpty ? 'UMUM' : unit.division;
      groupedByDivision.putIfAbsent(division, () => <CountdownJobdesc>[]);
      groupedByDivision[division]!.add(item);
    }
    final divisions = groupedByDivision.keys.toList()..sort();

    final effectiveStatus = _unitStatuses[unit.carId] ?? unit.status;
    final totalItems = jobdescs.length;
    final doneItems =
        jobdescs.where((i) => _effectiveCountdownStatus(i).toUpperCase() == 'DONE').length;
    final totalHours = jobdescs.fold<double>(0, (s, i) => s + i.targetHoursRevised);
    final remainingHours = jobdescs.fold<double>(0, (s, i) => s + i.remainingHours);
    final overallProgress = totalItems == 0 ? 0.0 : doneItems / totalItems;

    final today = DateTime.now();
    final overdueCount = jobdescs.where((i) {
      final dl = DateTime.tryParse(i.deadlineDate);
      final effectiveItemStatus = _effectiveCountdownStatus(i).toUpperCase();
      return dl != null && dl.isBefore(today) && effectiveItemStatus != 'DONE';
    }).length;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (screenContext) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('${unit.unitName} - Divisi'),
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.owner, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (unit.deliveryDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'DL ${unit.deliveryDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        _statusChip(effectiveStatus),
                        if (overdueCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.statusLocked.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.statusLocked.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              '$overdueCount terlambat',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.statusLocked,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: overallProgress,
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(overallProgress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$doneItems/$totalItems jobdesc • ${remainingHours.toStringAsFixed(1)} jam sisa • total ${totalHours.toStringAsFixed(1)} jam',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Pilih divisi untuk lanjut ke Section',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: divisions.length,
                  itemBuilder: (_, index) {
                    final divisionName = divisions[index];
                    final divisionItems = groupedByDivision[divisionName]!;
                    final divisionDone =
                        divisionItems.where((i) => _effectiveCountdownStatus(i).toUpperCase() == 'DONE').length;
                    final divisionProgress = divisionItems.isEmpty ? 0.0 : divisionDone / divisionItems.length;
                    return _buildPmNavCard(
                      title: divisionName,
                      subtitle:
                          '$divisionDone/${divisionItems.length} jobdesc • ${(divisionProgress * 100).round()}%',
                      onTap: () => _showPmDivisionScreen(
                        screenContext,
                        unit: unit,
                        divisionName: divisionName,
                        items: divisionItems,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPmDivisionScreen(
    BuildContext context, {
    required CountdownUnit unit,
    required String divisionName,
    required List<CountdownJobdesc> items,
  }) async {
    final doneCount = items.where((i) => _effectiveCountdownStatus(i).toUpperCase() == 'DONE').length;
    final totalItems = items.length;
    final progress = totalItems == 0 ? 0.0 : doneCount / totalItems;
    final groupedBySection = <String, List<CountdownJobdesc>>{};
    for (final item in items) {
      groupedBySection.putIfAbsent(item.sectionName, () => <CountdownJobdesc>[]);
      groupedBySection[item.sectionName]!.add(item);
    }
    final sections = groupedBySection.keys.toList()..sort();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (screenContext) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('$divisionName - Section'),
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${unit.unitName} • $divisionName',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$doneCount/$totalItems jobdesc selesai',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: sections
                      .map(
                        (sectionName) => _buildPmNavCard(
                          title: sectionName,
                          subtitle: '${groupedBySection[sectionName]!.length} jobdesc',
                          onTap: () => _showPmSectionScreen(
                            screenContext,
                            unit: unit,
                            divisionName: divisionName,
                            sectionName: sectionName,
                            items: groupedBySection[sectionName]!,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPmSectionScreen(
    BuildContext context, {
    required CountdownUnit unit,
    required String divisionName,
    required String sectionName,
    required List<CountdownJobdesc> items,
  }) async {
    final doneCount = items.where((i) => _effectiveCountdownStatus(i).toUpperCase() == 'DONE').length;
    final totalItems = items.length;
    final progress = totalItems == 0 ? 0.0 : doneCount / totalItems;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (screenContext) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Jobdesc'),
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${unit.unitName} • $divisionName',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(sectionName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
                        Text('${(progress * 100).round()}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$doneCount/$totalItems jobdesc selesai',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final status = _effectiveCountdownStatus(item);
                    return _buildPmNavCard(
                      title: '${item.panelName} • ${item.jobdesc}',
                      subtitle:
                          '${item.progress}% • ${item.remainingHours.toStringAsFixed(1)} jam sisa • DL ${item.deadlineDate} • $status',
                      onTap: () => _showPmJobdescActualScreen(
                        screenContext,
                        unit: unit,
                        item: item,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPmJobdescActualScreen(
    BuildContext context, {
    required CountdownUnit unit,
    required CountdownJobdesc item,
  }) async {
    final status = _effectiveCountdownStatus(item);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (screenContext) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Aktual (Countdown Detail)'),
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.panelName} • ${item.jobdesc}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Status: $status • DL ${item.deadlineDate}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('${item.progress}% • ${item.remainingHours.toStringAsFixed(1)} jam sisa',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CountdownDetailItem>>(
                  future: _repository.getDetails(item.id),
                  builder: (_, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final details = snapshot.data ?? const <CountdownDetailItem>[];
                    if (details.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada aktual (countdown detail) untuk jobdesc ini.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: details.length,
                      itemBuilder: (_, index) {
                        final detail = details[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(detail.employeeName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  )),
                              const SizedBox(height: 2),
                              Text('${detail.job} • ${detail.detailJob}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 3),
                              Text(
                                '${detail.workDate} ${detail.startTime}-${detail.finishTime} • ${detail.durationHours.toStringAsFixed(1)} jam • ${detail.percentage.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: () => _showDetail(screenContext, item, unit, isPm: true),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Buka Detail Lengkap'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPmNavCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  bool _matchesStatusProgressWithValue(CountdownJobdesc item, String filterValue) {
    final effectiveStatus = _effectiveCountdownStatus(item);
    switch (filterValue) {
      case 'plan':
        return effectiveStatus == 'PLAN';
      case 'done':
        return effectiveStatus == 'DONE';
      case 'proses':
        return effectiveStatus == 'PROSES';
      case 'qcready':
        return effectiveStatus == 'WAITING_QC';
      case 'below50':
        return item.progress < 50;
      case 'above50':
        return item.progress >= 50 && item.progress < 100;
      case 'full':
        return item.progress >= 100;
      default:
        return true;
    }
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
                Text(item.panelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(item.jobdesc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                      Text('Unit: ${unit.unitName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Section: ${item.sectionName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Sisa jam kerja: ${item.remainingHours.toStringAsFixed(1)} jam', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Status: ${_effectiveCountdownStatus(item)} • Progress: ${item.progress}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (_revisionStatusBanner(item) case final banner?) ...[
                        const SizedBox(height: 8),
                        _buildRevisionStatusBanner(banner),
                      ],
                      if (item.timeExtensionHours > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tambahan jam kerja: ${item.timeExtensionHours.toStringAsFixed(1)} jam • Target revisi ${item.targetHoursRevised.toStringAsFixed(1)} jam',
                          style: const TextStyle(fontSize: 12, color: AppColors.orange),
                        ),
                      ],
                      if (item.qcValidationStatus == 'VALIDATED' && item.qcResultStatus == 'TIDAK_LOLOS') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Rework tervalidasi: ${item.qcEstimatedReworkHours?.toStringAsFixed(1) ?? '0.0'} jam • Deadline ${item.qcReworkDeadlineDate ?? '-'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.statusLocked),
                        ),
                        if (_canRequestCountdownRevision(item)) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showCountdownRevisionDialog(
                                context: context,
                                item: item,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.orange,
                                side: const BorderSide(color: AppColors.orange),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.more_time_rounded),
                              label: const Text('Ajukan Revisi Countdown'),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_isRevisionPending(item)) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textMuted,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 14),
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
                      border: Border.all(color: AppColors.statusDone.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'Plan aktif: ${_plansFor(item.id).length} item\nTeralokasi ${_plannedHoursFor(item.id).toStringAsFixed(1)} jam dari ${item.targetHoursRevised.toStringAsFixed(1)} jam\nSisa yang masih bisa dibuat ${_remainingPlanHoursFor(item).toStringAsFixed(1)} jam',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
                  _buildEmptyMessage('Belum ada detail pekerjaan yang tercatat untuk jobdesc ini.')
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
                          Text('${row.employeeName} • ${row.job}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(row.detailJob, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Text(
                            '${row.workDate} • ${row.startTime} - ${row.finishTime}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Durasi ${row.durationHours.toStringAsFixed(1)} jam • Target ${row.targetHours.toStringAsFixed(1)} jam • Sisa ${row.remainingHours.toStringAsFixed(1)} jam',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          if (row.overtimeHours > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Overtime ${row.overtimeHours.toStringAsFixed(1)} jam',
                              style: const TextStyle(fontSize: 11, color: AppColors.orange),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _statusChip(row.status),
                              const SizedBox(width: 8),
                              Text(
                                'Progress ${row.percentage.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                    child: FilledButton.icon(
                      onPressed: _canOpenQc(item)
                          ? () => _openQc(context, item)
                          : _canCreateTaskFromCountdown(item)
                              ? () async {
                                  final created = await _showCreatePlanDialog(
                                    context: context,
                                    item: item,
                                    unit: unit,
                                  );
                                  if (created && sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Task berhasil dibuat dari countdown.')),
                                    );
                                  }
                                }
                              : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(
                        _canOpenQc(item) ? Icons.fact_check_rounded : Icons.add_task_rounded,
                      ),
                      label: Text(
                        _canOpenQc(item)
                            ? 'Lakukan QC'
                            : _canCreateTaskFromCountdown(item)
                                ? 'Buat Jobdesc Plan'
                                : 'Task Tidak Bisa Dibuat',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showCreatePlanDialog({
    required BuildContext context,
    required CountdownJobdesc item,
    required CountdownUnit unit,
  }) async {
    final employees = DummyEmployees.all
        .where((employee) => employee['role'] == 'op' && employee['division'] == unit.division)
        .toList();
    final availablePlanHours = _remainingPlanHoursFor(item);
    String? selectedEmployeeId = employees.isNotEmpty ? employees.first['id'] as String : null;
    final hoursCtrl = TextEditingController(
      text: availablePlanHours > 0
          ? availablePlanHours.toStringAsFixed(1)
          : item.targetHoursRevised.toStringAsFixed(1),
    );
    final descriptionCtrl = TextEditingController();
    DateTime selectedDate = DateTime.tryParse(item.deadlineDate) ?? DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay finishTime = _calculateFinishTime(
      startTime: startTime,
      durationHours: availablePlanHours > 0 ? availablePlanHours : item.targetHoursRevised,
    );
    var finishTimeEdited = false;
    var isOvertime = false;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'Create Task',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unit: ${unit.unitName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Text('Panel: ${item.panelName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Text('Jobdesc: ${item.jobdesc}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'Nama Yang Mengerjakan',
                    helperText: 'Pilih anggota yang akan mengerjakan.',
                  ),
                  items: employees
                      .map(
                        (employee) => DropdownMenuItem<String>(
                          value: employee['id'] as String,
                          child: Text(employee['full_name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedEmployeeId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Target Jam Pengerjaan',
                    helperText:
                        'Maksimal ${availablePlanHours.toStringAsFixed(1)} jam yang masih bisa dibuat dari jobdesc ini.',
                  ),
                  onChanged: (value) {
                    if (finishTimeEdited) return;
                    final targetHours = double.tryParse(value.trim());
                    if (targetHours == null || targetHours <= 0) return;
                    setDialogState(() {
                      finishTime = _calculateFinishTime(
                        startTime: startTime,
                        durationHours: targetHours,
                      );
                    });
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Pengerjaan', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(_formatDate(selectedDate), style: const TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.gold, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2027),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Jam Mulai', style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text(_formatTime(startTime), style: const TextStyle(color: AppColors.textMuted)),
                        trailing: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
                        onTap: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: startTime);
                          if (picked != null) {
                            final targetHours = double.tryParse(hoursCtrl.text.trim());
                            setDialogState(() {
                              startTime = picked;
                              if (!finishTimeEdited && targetHours != null && targetHours > 0) {
                                finishTime = _calculateFinishTime(
                                  startTime: startTime,
                                  durationHours: targetHours,
                                );
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
                        subtitle: Text(_formatTime(finishTime), style: const TextStyle(color: AppColors.textMuted)),
                        trailing: const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 18),
                        onTap: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: finishTime);
                          if (picked != null) {
                            setDialogState(() {
                              finishTime = picked;
                              finishTimeEdited = true;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: isOvertime,
                  onChanged: (value) => setDialogState(() => isOvertime = value),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.gold,
                  title: const Text(
                    'Jam lembur',
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Aktifkan jika task ini dikerjakan di jam lembur.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: descriptionCtrl,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Description / POK',
                    helperText: 'Tambahan keterangan pekerjaan bila diperlukan.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (selectedEmployeeId == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Belum ada anggota yang bisa dipilih untuk divisi ini.')),
                  );
                  return;
                }
                final selectedEmployee = employees.firstWhere(
                  (employee) => employee['id'] == selectedEmployeeId,
                );
                final targetHours = double.tryParse(hoursCtrl.text.trim());
                if (targetHours == null || targetHours <= 0) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama pelaksana dan target jam wajib diisi dengan benar.')),
                  );
                  return;
                }
                if (targetHours > availablePlanHours) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Target jam melebihi sisa alokasi countdown. Maksimal ${availablePlanHours.toStringAsFixed(1)} jam.',
                      ),
                    ),
                  );
                  return;
                }
                final descriptionNote = descriptionCtrl.text.trim();
                final noteParts = <String>[
                  'Sumber: Countdown ${item.id}',
                  isOvertime ? 'Lembur: Ya' : 'Lembur: Tidak',
                  if (descriptionNote.isNotEmpty) 'POK: $descriptionNote',
                ];
                await _jobPlanRepository.createPlan(
                  coreId: item.id,
                  carId: item.carId,
                  sourceType: 'COUNTDOWN',
                  sourceRefId: item.id,
                  unitName: unit.unitName,
                  panelName: item.panelName,
                  assignedDivision: unit.division,
                  assignedUserId: selectedEmployeeId!,
                  assignedTo: selectedEmployee['full_name'] as String,
                  description: item.jobdesc,
                  targetHours: targetHours,
                  workDate: _formatDate(selectedDate),
                  startTime: _formatTime(startTime),
                  finishTime: _formatTime(finishTime),
                  isOvertime: isOvertime,
                  note: noteParts.join(' | '),
                );
                final plans = await _jobPlanRepository.getPlans();
                if (!mounted) return;
                setState(() => _plans = plans);
                if (ctx.mounted) {
                  Navigator.pop(ctx, true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    return created == true;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  _CountdownStatusVisual _statusVisual(String status) {
    final normalized = status.toUpperCase();
    return switch (normalized) {
      'PLAN' => const _CountdownStatusVisual(
          shortLabel: 'PLAN',
          hint: 'Belum mulai',
          color: AppColors.orange,
          icon: Icons.schedule_rounded,
        ),
      'WAITING_QC' => const _CountdownStatusVisual(
          shortLabel: 'WAITING QC',
          hint: 'Menunggu pemeriksaan QC',
          color: AppColors.goldBright,
          icon: Icons.fact_check_rounded,
        ),
      'QC_READY' => const _CountdownStatusVisual(
          shortLabel: 'WAITING QC',
          hint: 'Menunggu pemeriksaan QC',
          color: AppColors.goldBright,
          icon: Icons.fact_check_rounded,
        ),
      'DONE' => const _CountdownStatusVisual(
          shortLabel: 'DONE',
          hint: 'Pekerjaan selesai',
          color: AppColors.statusDone,
          icon: Icons.check_circle_rounded,
        ),
      _ => const _CountdownStatusVisual(
          shortLabel: 'PROSES',
          hint: 'Sedang dikerjakan',
          color: AppColors.gold,
          icon: Icons.build_circle_rounded,
        ),
    };
  }

  String _effectiveCountdownStatus(CountdownJobdesc item) {
    final normalizedStatus = item.status.toUpperCase();
    final qcStatus = item.qcLastStatus?.toUpperCase();
    final qcValidationStatus = item.qcValidationStatus?.toUpperCase();
    final qcResultStatus = item.qcResultStatus?.toUpperCase();

    if (qcValidationStatus == 'VALIDATED' && qcResultStatus == 'TIDAK_LOLOS') {
      return 'PROSES';
    }
    if (qcValidationStatus == 'VALIDATED' && qcResultStatus == 'LOLOS') {
      return 'DONE';
    }

    if ((normalizedStatus == 'DONE' || normalizedStatus == 'QC_READY' || item.progress >= 100) &&
        qcStatus != 'LOLOS') {
      return 'WAITING_QC';
    }
    if (qcStatus == 'LOLOS') {
      return 'DONE';
    }
    return normalizedStatus;
  }

  String _deriveUnitStatus({
    required CountdownUnit unit,
    required List<CountdownJobdesc> items,
  }) {
    if (items.isEmpty) {
      return unit.status.toUpperCase();
    }

    final statuses = items.map(_effectiveCountdownStatus).toSet();
    if (statuses.contains('WAITING_QC')) {
      return 'WAITING_QC';
    }
    if (statuses.length == 1 && statuses.contains('DONE')) {
      return 'DONE';
    }
    if (statuses.length == 1 && statuses.contains('PLAN')) {
      return 'PLAN';
    }
    return 'PROSES';
  }

  bool _canOpenQc(CountdownJobdesc item) {
    final effectiveStatus = _effectiveCountdownStatus(item);
    return effectiveStatus == 'WAITING_QC' && _qcIdFor(item.id) != null;
  }

  bool _canCreateTaskFromCountdown(CountdownJobdesc item) {
    final effectiveStatus = _effectiveCountdownStatus(item);
    if (effectiveStatus == 'WAITING_QC' || effectiveStatus == 'DONE') {
      return false;
    }
    return _remainingPlanHoursFor(item) > 0;
  }

  bool _canRequestCountdownRevision(CountdownJobdesc item) {
    final role = sl<SessionManager>().role;
    if (role != 'kd') return false;

    final effectiveStatus = _effectiveCountdownStatus(item);
    if (effectiveStatus == 'DONE' || effectiveStatus == 'WAITING_QC') {
      return false;
    }

    if (_isRevisionPending(item)) {
      return false;
    }

    return true;
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

  Future<void> _showCountdownRevisionDialog({
    required BuildContext context,
    required CountdownJobdesc item,
  }) async {
    final hoursCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var deadline = DateTime.tryParse(item.deadlineDate)?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1));

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'Ajukan Revisi Countdown',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.panelName} • ${item.jobdesc}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deadline saat ini ${item.deadlineDate} • Target saat ini ${item.targetHoursRevised.toStringAsFixed(1)} jam',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Tambahan Jam Kerja (opsional)',
                    helperText: 'Kosongkan jika hanya revisi deadline.',
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline Revisi', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(_formatDate(deadline), style: const TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.calendar_today_rounded, color: AppColors.orange, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: deadline,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2027),
                    );
                    if (picked != null) {
                      setDialogState(() => deadline = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Alasan Revisi',
                    helperText: 'Jelaskan kebutuhan revisi deadline dan/atau tambahan jam kerja.',
                  ),
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
                final rawHours = hoursCtrl.text.trim();
                final requestedHours = rawHours.isEmpty ? 0.0 : double.tryParse(rawHours);
                if (requestedHours == null || requestedHours < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Format tambahan jam kerja tidak valid.')),
                  );
                  return;
                }
                final selectedDeadline = _formatDate(deadline);
                final isDeadlineChanged = selectedDeadline != item.deadlineDate;
                if (requestedHours == 0 && !isDeadlineChanged) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ubah deadline atau isi tambahan jam kerja terlebih dahulu.')),
                  );
                  return;
                }
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alasan revisi wajib diisi.')),
                  );
                  return;
                }
                await _submitCountdownRevision(
                  item: item,
                  requestedHours: requestedHours,
                  revisedDeadline: selectedDeadline,
                  reason: reasonCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Pengajuan revisi countdown berhasil disimpan.')),
      );
      await _loadUnits();
    }
  }

  Future<void> _submitCountdownRevision({
    required CountdownJobdesc item,
    required double requestedHours,
    required String revisedDeadline,
    required String reason,
  }) async {
    final countdowns = await _store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );

    final session = sl<SessionManager>();

    for (final entry in countdowns.entries) {
      final index = entry.value.indexWhere((row) => row['id'] == item.id);
      if (index == -1) continue;

      final countdownItem = entry.value[index];
      countdownItem['extensionRequestReason'] = reason;
      countdownItem['extensionRequestedHours'] = requestedHours;
      countdownItem['extensionRequestedDeadline'] = revisedDeadline;
      countdownItem['extensionRequestedAt'] = DateTime.now().toIso8601String();
      countdownItem['extensionRequestedById'] = session.userId;
      countdownItem['extensionRequestedByName'] = session.fullName ?? 'KD';
      countdownItem['extensionRequestStatus'] = 'REQUESTED';
      countdownItem['extensionApprovedByName'] = null;
      countdownItem['extensionApprovedAt'] = null;
      countdownItem['extensionApprovedHours'] = null;
      countdownItem['extensionApprovedDeadline'] = null;
      countdownItem['extensionRejectedByName'] = null;
      countdownItem['extensionRejectedAt'] = null;
      break;
    }

    await _store.writeGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      value: countdowns,
    );
  }

  String? _qcIdFor(String coreId) {
    return _qcIdsByCoreId[coreId];
  }

  void _openQc(BuildContext context, CountdownJobdesc item) {
    final qcId = _qcIdFor(item.id);
    if (qcId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data QC untuk jobdesc ini belum tersedia.')),
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

class _CountdownRevisionRequest {
  const _CountdownRevisionRequest({
    required this.countdownId,
    required this.carId,
    required this.unitName,
    required this.division,
    required this.panelName,
    required this.jobdesc,
    required this.currentDeadline,
    required this.requestedDeadline,
    required this.requestedHours,
    required this.reason,
    required this.requestedByName,
    required this.requestedAt,
  });

  final String countdownId;
  final String carId;
  final String unitName;
  final String division;
  final String panelName;
  final String jobdesc;
  final String currentDeadline;
  final String requestedDeadline;
  final double requestedHours;
  final String reason;
  final String requestedByName;
  final DateTime? requestedAt;

  String get requestedAtLabel {
    final time = requestedAt;
    if (time == null) return '-';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}