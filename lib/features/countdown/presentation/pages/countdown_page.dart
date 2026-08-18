import 'package:flutter/material.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';

import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import 'grouped_monitoring_pages.dart';

class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key, this.focusCarId});

  final String? focusCarId;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  late final CountdownRepository _repository;
  late final JobPlanRepository _jobPlanRepository;
  List<CountdownUnit> _units = [];
  final Map<String, String> _qcIdsByCoreId = {};
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
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final session = sl<SessionManager>();
    final role = session.accessBucket ?? session.role ?? '';
    try {
      final units = await _repository.getUnits(
        role: role,
        division: session.divisionName,
      );
      final unitStatuses = <String, String>{
        for (var index = 0; index < units.length; index++)
          units[index].carId: units[index].status.toUpperCase(),
      };
      if (!mounted) return;
      setState(() {
        _units = _sortedUnits(units);
        _unitStatuses = unitStatuses;
        _isLoading = false;
      });
    } catch (e) {
      // Countdown units are critical; plans are supplemental — fail gracefully
      if (!mounted) return;
      try {
        final units = await _repository.getUnits(
          role: role,
          division: session.divisionName,
        );
        final unitStatuses = <String, String>{
          for (var u in units) u.carId: u.status.toUpperCase(),
        };
        setState(() {
          _units = _sortedUnits(units);
          _unitStatuses = unitStatuses;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal memuat data countdown'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final session = sl<SessionManager>();
    final canReviewRevision = hasPermission(
      session.role,
      Permission.countdownSubmitApproval,
    );

    if (!canReviewRevision) {
      return _buildCountdownListView();
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
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
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Instructional summary card intentionally hidden from UI.
          if (_units.isEmpty)
            _buildEmptyMessage(
              'Belum ada kendaraan countdown untuk ditampilkan.',
            )
          else
            ..._units.map((unit) => _buildVehicleCard(context, unit)),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, CountdownUnit unit) {
    final progress = unit.progress / 100;
    final isPm = sl<SessionManager>().isGlobalAccess;
    final isFocused = widget.focusCarId == unit.carId;

    return InkWell(
      onTap: () => isPm
          ? _showPmUnitMonitoring(context, unit)
          : _showVehicleCountdown(context, unit),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
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
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Fokus',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    unit.unitName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'DL: ${unit.deliveryDate ?? '-'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 10),
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
                SizedBox(width: 10),
                Text(
                  '${unit.progress}%',
                  style: TextStyle(
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

  Widget _buildEmptyMessage(String message) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildRevisionApprovalTab() {
    return FutureBuilder<List<CountdownJobdesc>>(
      key: ValueKey(_revisionListVersion),
      future: _loadPendingRevisionRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? <CountdownJobdesc>[];
        if (requests.isEmpty) {
          return RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.surfaceCard,
            onRefresh: () async {
              await _loadUnits();
              if (mounted) setState(() {});
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
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
              .firstWhere(
                (u) => u.carId == request.carId,
                orElse: () => CountdownUnit(
                  carId: request.carId,
                  unitName: 'Unknown',
                  owner: '',
                  progress: 0,
                  status: '',
                  division: 'UNKNOWN',
                ),
              )
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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _RevisionSectionHeader(
                title: 'Approval Revisi Countdown',
                subtitle:
                    'List divisi dan pengajuan revisi yang menunggu ACC PM.',
              ),
              SizedBox(height: 10),
              ...divisions.map((division) {
                final divisionRequests = grouped[division]!;
                return Container(
                  margin: EdgeInsets.only(bottom: 10),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${divisionRequests.length} pengajuan',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    childrenPadding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: divisionRequests.map((request) {
                      final fallbackUnit = CountdownUnit(
                        carId: request.carId,
                        unitName: "-",
                        owner: "",
                        progress: 0,
                        status: "",
                        division: "",
                      );
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
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            request.jobdesc,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pengaju: ${request.requestedRevisionByName ?? '-'} • ${request.requestedRevisionAt?.toString().split(' ')[0] ?? '-'}',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          SizedBox(height: 4),
          Text(
            'Jam diajukan: ${(request.requestedRevisionHours ?? 0).toStringAsFixed(1)} jam',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Deadline saat ini ${request.deadlineDate} -> usulan ${request.requestedRevisionDeadline ?? '-'}',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          SizedBox(height: 4),
          Text(
            'Alasan: ${request.requestedRevisionReason ?? '-'}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10),
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
                      SnackBar(
                        content: Text('Pengajuan revisi ditolak.'),
                      ),
                    );
                    await _loadUnits();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusLocked,
                    side: BorderSide(color: AppColors.statusLocked),
                  ),
                  child: Text('Tolak'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _showApproveRevisionDialog(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusDone,
                    foregroundColor: AppColors.background,
                  ),
                  child: Text('ACC'),
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
          title: Text(
            'ACC Revisi Countdown',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_units.firstWhere(
                    (u) => u.carId == request.carId,
                    orElse: () => CountdownUnit(carId: request.carId, unitName: "-", owner: "", progress: 0, status: "", division: ""),
                  ).unitName} • ${request.panelName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  request.jobdesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: approvedHoursCtrl,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Jam Disetujui',
                    helperText: 'PM bisa edit jam sebelum ACC.',
                  ),
                ),
                SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Deadline Disetujui',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _formatDate(approvedDeadline),
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  trailing: Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.gold,
                    size: 18,
                  ),
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
              child: Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final approvedHours = double.tryParse(
                  approvedHoursCtrl.text.trim(),
                );
                if (approvedHours == null || approvedHours < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Jam disetujui tidak valid.')),
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
              child: Text('ACC'),
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
        SnackBar(content: Text('Pengajuan revisi berhasil di-ACC.')),
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

  Future<void> _showVehicleCountdown(
    BuildContext context,
    CountdownUnit unit,
  ) async {
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
    BuildContext context,
    CountdownUnit unit,
  ) async {
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

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _RevisionSectionHeader extends StatelessWidget {
  const _RevisionSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
