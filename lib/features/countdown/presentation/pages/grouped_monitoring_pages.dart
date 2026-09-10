/*
Tujuan: Halaman monitoring Countdown berjenjang Unit, Divisi, Section, Jobdesc, dan Tracking Master Panel.
Caller: CountdownPage setelah user memilih unit.
Dependensi: CountdownRepository, JobPlanRepository, SessionManager, AppColors, Countdown widgets.
Main Functions: GroupedUnitMonitoringPage, GroupedDivisionPage, GroupedSectionPage.
Side Effects: HTTP read-only countdown/tracking dan action existing revision/job plan melalui repository.
*/

import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../utils/countdown_helper.dart';
import '../widgets/countdown_shared.dart';
import '../widgets/countdown_detail_sheet.dart';
import 'master_panel_tracking_view.dart';

const countdownPanelModeLabel = 'Panel';
const countdownOperationalModeLabel = 'Countdown';

class GroupedUnitMonitoringPage extends StatefulWidget {
  const GroupedUnitMonitoringPage({
    super.key,
    required this.unit,
    required this.repository,
    required this.effectiveUnitStatus,
    this.jobPlanRepository,
    this.qcIdsByCoreId,
    this.onRefreshNeeded,
  });

  final CountdownUnit unit;
  final CountdownRepository repository;
  final String effectiveUnitStatus;

  // Dependencies required for KD Plan Creation
  final JobPlanRepository? jobPlanRepository;
  final Map<String, String>? qcIdsByCoreId;
  final VoidCallback? onRefreshNeeded;

  @override
  State<GroupedUnitMonitoringPage> createState() =>
      _GroupedUnitMonitoringPageState();
}

class _GroupedUnitMonitoringPageState extends State<GroupedUnitMonitoringPage> {
  bool _isLoading = false;
  bool _trackingMode = true;
  List<CountdownDivision> _divisions = [];

  @override
  void initState() {
    super.initState();
  }

  void _showDivisionMode() {
    setState(() => _trackingMode = false);
    if (_divisions.isEmpty && !_isLoading) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // Level 2: hanya tarik list divisi
    try {
      final data = await widget.repository.getDivisions(widget.unit.carId);
      if (!mounted) return;
      setState(() {
        _divisions = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat data'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.unit.unitName),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UnitModeSwitch(
            trackingMode: _trackingMode,
            onTracking: () => setState(() => _trackingMode = true),
            onDivision: _showDivisionMode,
          ),
          Expanded(
            child: _trackingMode
                ? MasterPanelTrackingView(
                    unit: widget.unit,
                    repository: widget.repository,
                  )
                : _buildDivisionMode(),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionMode() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final overallProgress = _divisions.isEmpty
        ? 0.0
        : _divisions.fold<double>(0, (s, d) => s + d.divisionProgress) /
              _divisions.length /
              100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.unit.unitName,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.unit.contractDeliveryDate != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'DL ${widget.unit.contractDeliveryDate}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  CountdownStatusChip(status: widget.effectiveUnitStatus),
                ],
              ),
              SizedBox(height: 10),
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
                  SizedBox(width: 8),
                  Text(
                    '${(overallProgress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '${_divisions.length} divisi',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Pilih divisi untuk lanjut ke Section',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _divisions.length,
            itemBuilder: (_, index) {
              final div = _divisions[index];
              return CountdownNavCard(
                title: div.divisionName,
                subtitle: '${div.divisionProgress.toStringAsFixed(1)}% selesai',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GroupedDivisionPage(
                        unit: widget.unit,
                        division: div,
                        repository: widget.repository,
                        jobPlanRepository: widget.jobPlanRepository,
                        qcIdsByCoreId: widget.qcIdsByCoreId,
                        onRefreshNeeded: widget.onRefreshNeeded,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnitModeSwitch extends StatelessWidget {
  const _UnitModeSwitch({
    required this.trackingMode,
    required this.onTracking,
    required this.onDivision,
  });

  final bool trackingMode;
  final VoidCallback onTracking;
  final VoidCallback onDivision;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: countdownPanelModeLabel,
            selected: trackingMode,
            onTap: onTracking,
          ),
          _ModeButton(
            label: countdownOperationalModeLabel,
            selected: !trackingMode,
            onTap: onDivision,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.gold : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class GroupedDivisionPage extends StatefulWidget {
  const GroupedDivisionPage({
    super.key,
    required this.unit,
    required this.division,
    required this.repository,
    this.jobPlanRepository,
    this.qcIdsByCoreId,
    this.onRefreshNeeded,
  });

  final CountdownUnit unit;
  final CountdownDivision division;
  final CountdownRepository repository;
  final JobPlanRepository? jobPlanRepository;
  final Map<String, String>? qcIdsByCoreId;
  final VoidCallback? onRefreshNeeded;

  @override
  State<GroupedDivisionPage> createState() => _GroupedDivisionPageState();
}

class _GroupedDivisionPageState extends State<GroupedDivisionPage> {
  bool _isLoading = true;
  List<CountdownSection> _sections = [];
  String _selectedStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = value);
        _loadSections();
      },
      selectedColor: AppColors.gold.withValues(alpha: 0.2),
      checkmarkColor: AppColors.gold,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? AppColors.gold : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: AppColors.surfaceInput,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.gold : AppColors.border),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    // Level 3: hanya tarik list section untuk divisi ini
    try {
      final data = await widget.repository.getSections(
        carId: widget.unit.carId,
        divisionId: widget.division.divisionId,
        search: _searchQuery,
        status: _selectedStatus,
      );
      if (!mounted) return;
      setState(() {
        _sections = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat data'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('${widget.division.divisionName} - Section'),
          backgroundColor: AppColors.surfaceCard,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = widget.division.divisionProgress / 100.0;
    final totalJobdesc = _sections.fold<int>(
      0,
      (s, sec) => s + sec.totalJobdesc,
    );
    final totalRemainingHours = _sections.fold<double>(
      0,
      (s, sec) => s + sec.totalRemainingHours,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.division.divisionName} - Section'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.unit.unitName} • ${widget.division.divisionName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
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
                    SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$totalJobdesc jobdesc • ${CountdownHelper.formatWorkHours(totalRemainingHours)} sisa',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                SizedBox(width: 8),
                _buildFilterChip('Plan', 'plan'),
                SizedBox(width: 8),
                _buildFilterChip('Proses', 'proses'),
                SizedBox(width: 8),
                _buildFilterChip('Menunggu QC', 'qcready'),
                SizedBox(width: 8),
                _buildFilterChip('Selesai', 'done'),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                _debounce?.cancel();
                if (value.isEmpty) {
                  setState(() => _searchQuery = '');
                  _loadSections();
                  return;
                }
                if (value.length < 3) return;
                _debounce = Timer(Duration(milliseconds: 600), () {
                  setState(() => _searchQuery = value);
                  _loadSections();
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama panel/part...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadSections();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceInput,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _sections.length,
              itemBuilder: (_, index) {
                final sec = _sections[index];
                return CountdownNavCard(
                  title: sec.sectionName,
                  subtitle:
                      '${sec.totalJobdesc} jobdesc • ${sec.totalRemainingHoursAlias ?? CountdownHelper.formatWorkHours(sec.totalRemainingHours)} sisa • ${sec.sectionProgress.toStringAsFixed(1)}% • ${sec.sectionStatus}',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GroupedSectionPage(
                          unit: widget.unit,
                          division: widget.division,
                          section: sec,
                          repository: widget.repository,
                          jobPlanRepository: widget.jobPlanRepository,
                          qcIdsByCoreId: widget.qcIdsByCoreId,
                          onRefreshNeeded: widget.onRefreshNeeded,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GroupedSectionPage extends StatefulWidget {
  const GroupedSectionPage({
    super.key,
    required this.unit,
    required this.division,
    required this.section,
    required this.repository,
    this.jobPlanRepository,
    this.qcIdsByCoreId,
    this.onRefreshNeeded,
  });

  final CountdownUnit unit;
  final CountdownDivision division;
  final CountdownSection section;
  final CountdownRepository repository;
  final JobPlanRepository? jobPlanRepository;
  final Map<String, String>? qcIdsByCoreId;
  final VoidCallback? onRefreshNeeded;

  @override
  State<GroupedSectionPage> createState() => _GroupedSectionPageState();
}

class _GroupedSectionPageState extends State<GroupedSectionPage> {
  bool _isLoading = true;
  List<CountdownJobdesc> _items = [];

  @override
  void initState() {
    super.initState();
    _loadJobdescs();
  }

  Future<void> _loadJobdescs() async {
    // Level 4: tarik jobdesc per panel_id
    try {
      final data = await widget.repository.getJobdescs(
        carId: widget.unit.carId,
        divisionId: widget.division.divisionId,
        panelId: widget.section.panelId,
      );
      if (!mounted) return;
      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat data'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.section.sectionName),
          backgroundColor: AppColors.surfaceCard,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final doneCount = _items.where(CountdownHelper.isWorkCompleted).length;
    final totalItems = _items.length;
    final progress = totalItems == 0 ? 0.0 : doneCount / totalItems;

    final filteredItems = List<CountdownJobdesc>.from(_items);

    final statusWeight = {
      'plan': 1,
      'proses': 2,
      'ready_qc': 3,
      'waiting_qc': 3,
      'qc ready': 3,
      'done': 4,
    };
    filteredItems.sort((a, b) {
      final stA = CountdownHelper.effectiveCountdownStatus(a).toLowerCase();
      final stB = CountdownHelper.effectiveCountdownStatus(b).toLowerCase();
      final wA = statusWeight[stA] ?? 99;
      final wB = statusWeight[stB] ?? 99;
      if (wA != wB) return wA.compareTo(wB);

      final dlA = DateTime.tryParse(a.deadlineDate) ?? DateTime(2099);
      final dlB = DateTime.tryParse(b.deadlineDate) ?? DateTime(2099);
      return dlA.compareTo(dlB);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.section.sectionName),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.unit.unitName} • ${widget.division.divisionName}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  widget.section.sectionName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
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
                    SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$doneCount/$totalItems jobdesc selesai',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredItems.length,
              itemBuilder: (_, index) {
                final item = filteredItems[index];
                final status = CountdownHelper.effectiveCountdownStatus(item);
                return _CountdownJobdescListCard(
                  panelName: item.panelName,
                  jobdesc: item.jobdesc,
                  subtitle:
                      '${item.progress}% • ${item.remainingHoursAlias ?? CountdownHelper.formatWorkHours(item.remainingHours)} sisa • DL ${item.deadlineDate}',
                  statusStr: status,
                  onTap: () {
                    final session = sl<SessionManager>();
                    if (session.isGlobalAccess) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PmJobdescActualPage(
                            unit: widget.unit,
                            item: item,
                            repository: widget.repository,
                          ),
                        ),
                      );
                    } else if (widget.jobPlanRepository != null &&
                        widget.qcIdsByCoreId != null &&
                        widget.onRefreshNeeded != null) {
                      CountdownDetailSheet.show(
                        context: context,
                        item: item,
                        unit: widget.unit,
                        allUnitItems: _items,
                        isPm: false,
                        repository: widget.repository,
                        jobPlanRepository: widget.jobPlanRepository!,
                        qcIdsByCoreId: widget.qcIdsByCoreId!,
                        onPlanCreated: () {
                          widget.onRefreshNeeded!();
                          Navigator.of(context).pop();
                        },
                        onRevisionRequested: () {
                          widget.onRefreshNeeded!();
                          Navigator.of(context).pop();
                        },
                        onDeclared: widget.onRefreshNeeded,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PmJobdescActualPage extends StatefulWidget {
  const PmJobdescActualPage({
    super.key,
    required this.unit,
    required this.item,
    required this.repository,
  });

  final CountdownUnit unit;
  final CountdownJobdesc item;
  final CountdownRepository repository;

  @override
  State<PmJobdescActualPage> createState() => _PmJobdescActualPageState();
}

class _PmJobdescActualPageState extends State<PmJobdescActualPage> {
  late Future<List<CountdownDetailItem>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = widget.repository.getDetails(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final status = CountdownHelper.effectiveCountdownStatus(widget.item);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Aktual (Countdown Detail)'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.item.panelName} • ${widget.item.jobdesc}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Status: $status • DL ${widget.item.deadlineDate}',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                SizedBox(height: 4),
                Text(
                  '${widget.item.progress}% • ${widget.item.remainingHoursAlias ?? CountdownHelper.formatWorkHours(widget.item.remainingHours)} sisa',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CountdownDetailItem>>(
              future: _detailsFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final details = snapshot.data ?? <CountdownDetailItem>[];
                if (details.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada aktual (countdown detail) untuk jobdesc ini.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: details.length,
                  itemBuilder: (_, index) {
                    final detail = details[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detail.employeeName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${detail.job} • ${detail.detailJob}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '${detail.workDate} ${detail.startTime}-${detail.finishTime} • ${detail.durationHours.toStringAsFixed(1)} jam • ${detail.percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
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
    );
  }
}

class KdGroupedPanelPage extends StatefulWidget {
  const KdGroupedPanelPage({
    super.key,
    required this.unit,
    required this.repository,
    this.jobPlanRepository,
    this.qcIdsByCoreId,
    this.onRefreshNeeded,
  });

  final CountdownUnit unit;
  final CountdownRepository repository;
  final JobPlanRepository? jobPlanRepository;
  final Map<String, String>? qcIdsByCoreId;
  final VoidCallback? onRefreshNeeded;

  @override
  State<KdGroupedPanelPage> createState() => _KdGroupedPanelPageState();
}

class _KdGroupedPanelPageState extends State<KdGroupedPanelPage> {
  bool _isLoading = true;
  List<CountdownDivision> _divisions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Level 2: list divisi saja
    try {
      final data = await widget.repository.getDivisions(widget.unit.carId);
      if (!mounted) return;
      setState(() {
        _divisions = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat data'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('${widget.unit.unitName} - Divisi'),
          backgroundColor: AppColors.surfaceCard,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final overallProgress = _divisions.isEmpty
        ? 0.0
        : _divisions.fold<double>(0, (s, d) => s + d.divisionProgress) /
              _divisions.length /
              100.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.unit.unitName} - Divisi'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.unit.unitName,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 10),
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
                    SizedBox(width: 8),
                    Text(
                      '${(overallProgress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${_divisions.length} divisi',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _divisions.length,
              itemBuilder: (_, index) {
                final div = _divisions[index];
                return CountdownNavCard(
                  title: div.divisionName,
                  subtitle:
                      '${div.divisionProgress.toStringAsFixed(1)}% selesai',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KdDivisionSectionPage(
                          unit: widget.unit,
                          division: div,
                          repository: widget.repository,
                          jobPlanRepository: widget.jobPlanRepository,
                          qcIdsByCoreId: widget.qcIdsByCoreId,
                          onRefreshNeeded: widget.onRefreshNeeded,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Level 3 page for KD: list sections per division.
class KdDivisionSectionPage extends StatefulWidget {
  const KdDivisionSectionPage({
    super.key,
    required this.unit,
    required this.division,
    required this.repository,
    this.jobPlanRepository,
    this.qcIdsByCoreId,
    this.onRefreshNeeded,
  });

  final CountdownUnit unit;
  final CountdownDivision division;
  final CountdownRepository repository;
  final JobPlanRepository? jobPlanRepository;
  final Map<String, String>? qcIdsByCoreId;
  final VoidCallback? onRefreshNeeded;

  @override
  State<KdDivisionSectionPage> createState() => _KdDivisionSectionPageState();
}

class _KdDivisionSectionPageState extends State<KdDivisionSectionPage> {
  bool _isLoading = true;
  List<CountdownSection> _sections = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final data = await widget.repository.getSections(
        carId: widget.unit.carId,
        divisionId: widget.division.divisionId,
      );
      if (!mounted) return;
      setState(() {
        _sections = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat data'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('${widget.division.divisionName} - Section'),
          backgroundColor: AppColors.surfaceCard,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = widget.division.divisionProgress / 100.0;
    final totalJobdesc = _sections.fold<int>(
      0,
      (s, sec) => s + sec.totalJobdesc,
    );
    final totalRemaining = _sections.fold<double>(
      0,
      (s, sec) => s + sec.totalRemainingHours,
    );

    final filteredSections = _sections.where((sec) {
      if (_searchQuery.isEmpty) return true;
      return sec.sectionName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.division.divisionName} - Section'),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.unit.unitName} • ${widget.division.divisionName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
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
                    SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$totalJobdesc jobdesc • ${CountdownHelper.formatWorkHours(totalRemaining)} sisa',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Panel/Part',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceInput,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredSections.length,
              itemBuilder: (_, index) {
                final sec = filteredSections[index];
                return CountdownNavCard(
                  title: sec.sectionName,
                  subtitle:
                      '${sec.totalJobdesc} jobdesc • ${sec.totalRemainingHoursAlias ?? CountdownHelper.formatWorkHours(sec.totalRemainingHours)} sisa • ${sec.sectionProgress.toStringAsFixed(1)}%',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KdPanelJobdescPage(
                          unit: widget.unit,
                          division: widget.division,
                          section: sec,
                          repository: widget.repository,
                          jobPlanRepository: widget.jobPlanRepository,
                          qcIdsByCoreId: widget.qcIdsByCoreId,
                          onRefreshNeeded: widget.onRefreshNeeded,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class KdPanelJobdescPage extends StatefulWidget {
  const KdPanelJobdescPage({
    super.key,
    required this.unit,
    required this.division,
    required this.section,
    required this.repository,
    this.jobPlanRepository,
    this.qcIdsByCoreId,
    this.onRefreshNeeded,
  });

  final CountdownUnit unit;
  final CountdownDivision division;
  final CountdownSection section;
  final CountdownRepository repository;
  final JobPlanRepository? jobPlanRepository;
  final Map<String, String>? qcIdsByCoreId;
  final VoidCallback? onRefreshNeeded;

  @override
  State<KdPanelJobdescPage> createState() => _KdPanelJobdescPageState();
}

class _KdPanelJobdescPageState extends State<KdPanelJobdescPage> {
  bool _isLoading = true;
  List<CountdownJobdesc> _items = [];
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadJobdescs();
  }

  Future<void> _loadJobdescs() async {
    // Level 4: list jobdesc per panel
    try {
      final data = await widget.repository.getJobdescs(
        carId: widget.unit.carId,
        divisionId: widget.division.divisionId,
        panelId: widget.section.panelId,
      );
      if (!mounted) return;
      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat data'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.section.sectionName),
          backgroundColor: AppColors.surfaceCard,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final doneCount = _items.where(CountdownHelper.isWorkCompleted).length;
    final totalItems = _items.length;
    final progress = totalItems == 0 ? 0.0 : doneCount / totalItems;

    final filteredItems = _items.where((i) {
      if (_searchQuery.isNotEmpty &&
          !i.jobdesc.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedStatus == 'all') return true;
      final st = CountdownHelper.effectiveCountdownStatus(i).toLowerCase();
      if (_selectedStatus == 'plan') return st == 'plan';
      if (_selectedStatus == 'proses') return st == 'proses';
      if (_selectedStatus == 'qcready') {
        return st == 'ready_qc' || st == 'waiting_qc' || st == 'qc ready';
      }
      if (_selectedStatus == 'done') return st == 'done';
      return true;
    }).toList();

    final statusWeight = {
      'plan': 1,
      'proses': 2,
      'ready_qc': 3,
      'waiting_qc': 3,
      'qc ready': 3,
      'done': 4,
    };
    filteredItems.sort((a, b) {
      final stA = CountdownHelper.effectiveCountdownStatus(a).toLowerCase();
      final stB = CountdownHelper.effectiveCountdownStatus(b).toLowerCase();
      final wA = statusWeight[stA] ?? 99;
      final wB = statusWeight[stB] ?? 99;
      if (wA != wB) return wA.compareTo(wB);

      final dlA = DateTime.tryParse(a.deadlineDate) ?? DateTime(2099);
      final dlB = DateTime.tryParse(b.deadlineDate) ?? DateTime(2099);
      return dlA.compareTo(dlB);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.section.sectionName),
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.unit.unitName,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  widget.section.sectionName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
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
                    SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '$doneCount/$totalItems jobdesc selesai',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                SizedBox(width: 8),
                _buildFilterChip('Plan', 'plan'),
                SizedBox(width: 8),
                _buildFilterChip('Proses', 'proses'),
                SizedBox(width: 8),
                _buildFilterChip('Menunggu QC', 'qcready'),
                SizedBox(width: 8),
                _buildFilterChip('Selesai', 'done'),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari jobdesc...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceInput,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredItems.length,
              itemBuilder: (_, index) {
                final item = filteredItems[index];
                final status = CountdownHelper.effectiveCountdownStatus(item);
                return _CountdownJobdescListCard(
                  panelName: item.panelName,
                  jobdesc: item.jobdesc,
                  subtitle:
                      '${item.progress}% • ${item.remainingHoursAlias ?? CountdownHelper.formatWorkHours(item.remainingHours)} sisa • DL ${item.deadlineDate}',
                  statusStr: status,
                  onTap: () {
                    if (widget.jobPlanRepository != null &&
                        widget.qcIdsByCoreId != null &&
                        widget.onRefreshNeeded != null) {
                      CountdownDetailSheet.show(
                        context: context,
                        item: item,
                        unit: widget.unit,
                        allUnitItems: _items,
                        isPm: false,
                        repository: widget.repository,
                        jobPlanRepository: widget.jobPlanRepository!,
                        qcIdsByCoreId: widget.qcIdsByCoreId!,
                        onPlanCreated: () {
                          widget.onRefreshNeeded!();
                          Navigator.of(context).pop();
                        },
                        onRevisionRequested: () {
                          widget.onRefreshNeeded!();
                          Navigator.of(context).pop();
                        },
                        onDeclared: widget.onRefreshNeeded,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatus = value),
      selectedColor: AppColors.gold.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.gold : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide(color: isSelected ? AppColors.gold : AppColors.border),
    );
  }
}

class _CountdownJobdescListCard extends StatelessWidget {
  const _CountdownJobdescListCard({
    required this.panelName,
    required this.jobdesc,
    required this.subtitle,
    required this.statusStr,
    required this.onTap,
  });

  final String panelName;
  final String jobdesc;
  final String subtitle;
  final String statusStr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
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
                    panelName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    jobdesc,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CountdownStatusChip(status: statusStr),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
