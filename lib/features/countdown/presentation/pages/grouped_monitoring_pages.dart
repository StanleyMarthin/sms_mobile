import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/countdown_entities.dart';
import '../../domain/repositories/countdown_repository.dart';
import '../../../job_plan/domain/repositories/job_plan_repository.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../utils/countdown_helper.dart';
import '../widgets/countdown_shared.dart';
import '../widgets/countdown_detail_sheet.dart';

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
  bool _isLoading = true;
  List<CountdownDivision> _divisions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Level 2: hanya tarik list divisi
    final data = await widget.repository.getDivisions(widget.unit.carId);
    if (!mounted) return;
    setState(() {
      _divisions = data;
      _isLoading = false;
    });
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Summary dari data L2
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
                Text(widget.unit.unitName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.unit.contractDeliveryDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.orange.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          'DL ${widget.unit.contractDeliveryDate}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    CountdownStatusChip(status: widget.effectiveUnitStatus),
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
                  '${_divisions.length} divisi',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
      backgroundColor: AppColors.surfaceInput,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.border,
        ),
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progress = widget.division.divisionProgress / 100.0;
    final totalJobdesc =
        _sections.fold<int>(0, (s, sec) => s + sec.totalJobdesc);
    final totalRemainingHours =
        _sections.fold<double>(0, (s, sec) => s + sec.totalRemainingHours);

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
                Text(
                    '${widget.unit.unitName} • ${widget.division.divisionName}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
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
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalJobdesc jobdesc • ${totalRemainingHours.toStringAsFixed(1)} jam sisa',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Plan', 'plan'),
                const SizedBox(width: 8),
                _buildFilterChip('Proses', 'proses'),
                const SizedBox(width: 8),
                _buildFilterChip('Menunggu QC', 'qcready'),
                const SizedBox(width: 8),
                _buildFilterChip('Selesai', 'done'),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                _debounce = Timer(const Duration(milliseconds: 600), () {
                  setState(() => _searchQuery = value);
                  _loadSections();
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama panel/part...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadSections();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceInput,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _sections.length,
              itemBuilder: (_, index) {
                final sec = _sections[index];
                return CountdownNavCard(
                  title: sec.sectionName,
                  subtitle:
                      '${sec.totalJobdesc} jobdesc • ${sec.totalRemainingHours.toStringAsFixed(1)} jam sisa • ${sec.sectionProgress.toStringAsFixed(1)}% • ${sec.sectionStatus}',
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final doneCount = _items
        .where((i) =>
            CountdownHelper.effectiveCountdownStatus(i).toUpperCase() == 'DONE')
        .length;
    final totalItems = _items.length;
    final progress = totalItems == 0 ? 0.0 : doneCount / totalItems;

    final filteredItems = List<CountdownJobdesc>.from(_items);

    final statusWeight = {
      'plan': 1,
      'proses': 2,
      'ready_qc': 3,
      'waiting_qc': 3,
      'qc ready': 3,
      'done': 4
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
                Text(
                    '${widget.unit.unitName} • ${widget.division.divisionName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(widget.section.sectionName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$doneCount/$totalItems jobdesc selesai',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredItems.length,
              itemBuilder: (_, index) {
                final item = filteredItems[index];
                final status = CountdownHelper.effectiveCountdownStatus(item);
                return _CountdownJobdescListCard(
                  panelName: item.panelName,
                  jobdesc: item.jobdesc,
                  subtitle:
                      '${item.progress}% • ${item.remainingHours.toStringAsFixed(1)} jam sisa • DL ${item.deadlineDate}',
                  statusStr: status,
                  onTap: () {
                    final role = sl<SessionManager>().role;
                    if (role == 'pm') {
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
                Text('${widget.item.panelName} • ${widget.item.jobdesc}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Status: $status • DL ${widget.item.deadlineDate}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                    '${widget.item.progress}% • ${widget.item.remainingHours.toStringAsFixed(1)} jam sisa',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CountdownDetailItem>>(
              future: _detailsFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final details = snapshot.data ?? const <CountdownDetailItem>[];
                if (details.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada aktual (countdown detail) untuk jobdesc ini.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 3),
                          Text(
                            '${detail.workDate} ${detail.startTime}-${detail.finishTime} • ${detail.durationHours.toStringAsFixed(1)} jam • ${detail.percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted),
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
    final data = await widget.repository.getDivisions(widget.unit.carId);
    if (!mounted) return;
    setState(() {
      _divisions = data;
      _isLoading = false;
    });
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
        body: const Center(child: CircularProgressIndicator()),
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
                Text(widget.unit.unitName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
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
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_divisions.length} divisi',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    final data = await widget.repository.getSections(
      carId: widget.unit.carId,
      divisionId: widget.division.divisionId,
    );
    if (!mounted) return;
    setState(() {
      _sections = data;
      _isLoading = false;
    });
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final progress = widget.division.divisionProgress / 100.0;
    final totalJobdesc =
        _sections.fold<int>(0, (s, sec) => s + sec.totalJobdesc);
    final totalRemaining =
        _sections.fold<double>(0, (s, sec) => s + sec.totalRemainingHours);

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
                Text(
                    '${widget.unit.unitName} • ${widget.division.divisionName}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '$totalJobdesc jobdesc • ${totalRemaining.toStringAsFixed(1)} jam sisa',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Panel/Part',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                filled: true,
                fillColor: AppColors.surfaceInput,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredSections.length,
              itemBuilder: (_, index) {
                final sec = filteredSections[index];
                return CountdownNavCard(
                  title: sec.sectionName,
                  subtitle:
                      '${sec.totalJobdesc} jobdesc • ${sec.totalRemainingHours.toStringAsFixed(1)} jam sisa • ${sec.sectionProgress.toStringAsFixed(1)}%',
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final doneCount = _items
        .where((i) =>
            CountdownHelper.effectiveCountdownStatus(i).toUpperCase() == 'DONE')
        .length;
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
      'done': 4
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
                Text(widget.unit.unitName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(widget.section.sectionName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$doneCount/$totalItems jobdesc selesai',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Plan', 'plan'),
                const SizedBox(width: 8),
                _buildFilterChip('Proses', 'proses'),
                const SizedBox(width: 8),
                _buildFilterChip('Menunggu QC', 'qcready'),
                const SizedBox(width: 8),
                _buildFilterChip('Selesai', 'done'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari jobdesc...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                filled: true,
                fillColor: AppColors.surfaceInput,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredItems.length,
              itemBuilder: (_, index) {
                final item = filteredItems[index];
                final status = CountdownHelper.effectiveCountdownStatus(item);
                return _CountdownJobdescListCard(
                  panelName: item.panelName,
                  jobdesc: item.jobdesc,
                  subtitle:
                      '${item.progress}% • ${item.remainingHours.toStringAsFixed(1)} jam sisa • DL ${item.deadlineDate}',
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
      side: BorderSide(
        color: isSelected ? AppColors.gold : AppColors.border,
      ),
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
                    panelName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    jobdesc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CountdownStatusChip(status: statusStr),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ),
                    ],
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
}
