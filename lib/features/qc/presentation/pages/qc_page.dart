import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/time_parser.dart';
import '../../../../core/widgets/duration_input.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../data/datasources/remote_qc_datasource.dart';
import '../../domain/entities/qc_item.dart';
import '../../domain/repositories/qc_repository.dart';
import '../../../job_plan/data/datasources/job_plan_datasource.dart';

// ─── PAGE 1: LIST DIVISI (TAB UTAMA) ──────────────────────────────────────────

class QcTab extends StatefulWidget {
  const QcTab({super.key, this.focusCoreId});

  final String? focusCoreId;

  @override
  State<QcTab> createState() => _QcTabState();
}

class _QcTabState extends State<QcTab> {
  late final QcRepository _repo;
  List<QcDivision> _divisions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo = sl<QcRepository>();
    _loadDivisions();
    _checkAutoRecover();
  }

  Future<void> _checkAutoRecover() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemStr = prefs.getString('pending_qc_item');
      final passed = prefs.getBool('pending_qc_passed') ?? true;

      if (itemStr != null) {
        final item = QcItem.fromJson(itemStr);
        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QcSubmitPage(item: item, passed: passed),
            ),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDivisions() async {
    final divs = await _repo.getDivisions();
    if (!mounted) return;
    setState(() {
      _divisions = divs;
      _isLoading = false;
    });

    // Pindah otomatis jika dipanggil lewat notifikasi (ada focusCoreId)
    // Walaupun user menekan notifikasi, logic notif mungkin di handle di main.
    // Tapi jika ada focusCoreId, idealnya BE sudah return Divisi.
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_divisions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.domain_disabled,
              size: 56,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: 16),
            Text(
              'Tidak ada data divisi QC',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _divisions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final div = _divisions[i];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QcUnitsPage(
                  divisionId: div.divisionId,
                  divisionName: div.divisionName,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        div.divisionName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        div.totalItem > 0
                            ? '${div.totalItem} antrian pekerjaan'
                            : 'Ketuk untuk memuat antrian QC',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── PAGE 2: LIST UNIT PROGRESS (DALAM DIVISI) ───────────────────────────────

class QcUnitsPage extends StatefulWidget {
  final String divisionId;
  final String divisionName;

  const QcUnitsPage({
    super.key,
    required this.divisionId,
    required this.divisionName,
  });

  @override
  State<QcUnitsPage> createState() => _QcUnitsPageState();
}

class _QcUnitsPageState extends State<QcUnitsPage> {
  late final QcRepository _repo;
  List<QcUnitGroup> _unitGroups = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;

  // Pagination States
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repo = sl<QcRepository>();
    _scrollController.addListener(_onScroll);
    _loadUnits();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isFetchingMore && _hasMore) {
        _loadMoreUnits();
      }
    }
  }

  Future<void> _loadUnits() async {
    _page = 1;
    final response = await _repo.getQcItems(
      divisionId: widget.divisionId,
      page: _page,
    );
    if (!mounted) return;
    setState(() {
      _unitGroups = response.groups;
      _hasMore = response.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _loadMoreUnits() async {
    setState(() {
      _isFetchingMore = true;
    });

    _page++;
    final response = await _repo.getQcItems(
      divisionId: widget.divisionId,
      page: _page,
    );
    if (!mounted) return;

    setState(() {
      _hasMore = response.hasMore;

      // Append data by unit Id grouping
      for (final newGroup in response.groups) {
        final existingIdx = _unitGroups.indexWhere(
          (g) => g.unitId == newGroup.unitId,
        );
        if (existingIdx >= 0) {
          // Add jobdescs into existing unit group
          final existingJobdescs = List<QcItem>.from(
            _unitGroups[existingIdx].jobdescs,
          );
          existingJobdescs.addAll(newGroup.jobdescs);

          _unitGroups[existingIdx] = QcUnitGroup(
            unitId: newGroup.unitId,
            unitName: newGroup.unitName,
            jobdescs: existingJobdescs,
          );
        } else {
          // Add entirely new unit group entry
          _unitGroups.add(newGroup);
        }
      }

      _isFetchingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Divisi ${widget.divisionName}'),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unitGroups.isEmpty
          ? const Center(
              child: Text(
                'Tidak ada unit menunggu QC.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _unitGroups.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                if (i == _unitGroups.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_isLoading && !_isFetchingMore && _hasMore) {
                      _loadMoreUnits();
                    }
                  });
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final unit = _unitGroups[i];

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QcItemsPage(
                          divisionId: widget.divisionId,
                          divisionName: widget.divisionName,
                          unitId: unit.unitId,
                          unitName: unit.unitName,
                          initialItems: unit.jobdescs,
                        ),
                      ),
                    ).then((_) => _loadUnits()); // Reload when going back
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unit.unitName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Ketuk untuk memuat jobdesc QC',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
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
}

// ─── PAGE 3: ITEMS + DEBOUNCE SEARCH (DALAM UNIT) ─────────────────────────

class QcItemsPage extends StatefulWidget {
  final String divisionId;
  final String divisionName;
  final String unitId;
  final String unitName;
  final List<QcItem> initialItems;

  const QcItemsPage({
    super.key,
    required this.divisionId,
    required this.divisionName,
    required this.unitId,
    required this.unitName,
    required this.initialItems,
  });

  @override
  State<QcItemsPage> createState() => _QcItemsPageState();
}

class _QcItemsPageState extends State<QcItemsPage> {
  late final QcRepository _repo;
  List<QcItem> _items = [];
  bool _isLoading = true;
  String _selectedPanel = 'all';
  String _sortMode = 'panel_asc';

  Timer? _debounce;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = sl<QcRepository>();
    _items = widget.initialItems;
    _loadItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && query.length >= 3) {
        _loadItems(search: query);
      } else if (query.isEmpty) {
        _loadItems();
      }
    });
  }

  Future<void> _loadItems({String? search}) async {
    setState(() => _isLoading = true);
    final groups = await _repo.getQcItems(
      divisionId: widget.divisionId,
      unitId: widget.unitId,
      search: search,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _items = groups.groups.expand((g) => g.jobdescs).toList();
      if (_selectedPanel != 'all' &&
          !_items.any((item) => item.panelName == _selectedPanel)) {
        _selectedPanel = 'all';
      }
    });
  }

  List<QcItem> get _antrianItems => _items
      .where(
        (i) =>
            i.countdownStatus == 'READY_QC' ||
            i.countdownStatus == 'WAITING_QC' ||
            i.countdownStatus == 'QC_READY',
      )
      .toList();

  List<String> get _panelOptions {
    final panels = _antrianItems.map((item) => item.panelName).toSet().toList()
      ..sort();
    return ['all', ...panels];
  }

  List<QcItem> get _visibleItems {
    final items = _antrianItems.where((item) {
      if (_selectedPanel != 'all' && item.panelName != _selectedPanel) {
        return false;
      }
      return true;
    }).toList();

    items.sort((a, b) {
      switch (_sortMode) {
        case 'hours_desc':
          return (b.remainingHours ?? 0).compareTo(a.remainingHours ?? 0);
        case 'hours_asc':
          return (a.remainingHours ?? 0).compareTo(b.remainingHours ?? 0);
        case 'job_asc':
          return a.jobName.compareTo(b.jobName);
        case 'panel_asc':
        default:
          final panelCompare = a.panelName.compareTo(b.panelName);
          return panelCompare != 0
              ? panelCompare
              : a.jobName.compareTo(b.jobName);
      }
    });
    return items;
  }

  String _sortLabel(String value) {
    switch (value) {
      case 'hours_desc':
        return 'Jam terbesar';
      case 'hours_asc':
        return 'Jam terkecil';
      case 'job_asc':
        return 'Job A-Z';
      case 'panel_asc':
      default:
        return 'Panel A-Z';
    }
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedPanel = 'all';
      _sortMode = 'panel_asc';
    });
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final canSubmit = hasPermission(session.role, Permission.qcSubmit);
    final activeFilterCount =
        (_selectedPanel == 'all' ? 0 : 1) + (_sortMode == 'panel_asc' ? 0 : 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.unitName, style: const TextStyle(fontSize: 16)),
            Text(
              'Divisi ${widget.divisionName}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari panel/section/pekerjaan...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan pencarian',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textMuted,
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadItems();
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.surfaceInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _onSearchChanged(value);
                  },
                ),
                const SizedBox(height: 8),
                _buildCompactFilters(activeFilterCount),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(_visibleItems, canSubmit),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilters(int activeFilterCount) {
    final panelOptions = _panelOptions;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MiniFilterButton(
                  icon: Icons.fact_check_rounded,
                  label: 'Ready QC',
                  selected: true,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Filter panel',
                  onSelected: (value) => setState(() => _selectedPanel = value),
                  itemBuilder: (_) => panelOptions
                      .map(
                        (panel) => PopupMenuItem<String>(
                          value: panel,
                          child: Text(panel == 'all' ? 'Semua panel' : panel),
                        ),
                      )
                      .toList(),
                  child: _MiniFilterButton(
                    icon: Icons.filter_alt_rounded,
                    label: _selectedPanel == 'all' ? 'Panel' : _selectedPanel,
                    selected: _selectedPanel != 'all',
                    onTap: null,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Urutkan',
                  onSelected: (value) => setState(() => _sortMode = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'panel_asc', child: Text('Panel A-Z')),
                    PopupMenuItem(value: 'job_asc', child: Text('Job A-Z')),
                    PopupMenuItem(
                      value: 'hours_desc',
                      child: Text('Jam terbesar'),
                    ),
                    PopupMenuItem(
                      value: 'hours_asc',
                      child: Text('Jam terkecil'),
                    ),
                  ],
                  child: _MiniFilterButton(
                    icon: Icons.sort_rounded,
                    label: _sortLabel(_sortMode),
                    selected: _sortMode != 'panel_asc',
                    onTap: null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: activeFilterCount > 0 ? 'Reset filter' : 'Refresh data',
          onPressed: activeFilterCount > 0 ? _resetFilters : () => _loadItems(),
          icon: Icon(
            activeFilterCount > 0
                ? Icons.filter_alt_off_rounded
                : Icons.refresh_rounded,
            size: 20,
          ),
          color: activeFilterCount > 0 ? AppColors.gold : AppColors.textMuted,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildList(List<QcItem> items, bool canSubmit) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return _QcCard(
          item: item,
          canSubmit: canSubmit,
          onAction: (passed) async {
            // Push ke form submit
            final res = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QcSubmitPage(item: item, passed: passed),
              ),
            );
            if (res == true) {
              // Jika submit sukses (T/F return true untuk sukses flow), load ulang flat list.
              final query = _searchCtrl.text.trim();
              _loadItems(search: query.length >= 3 ? query : null);
            }
          },
        );
      },
    );
  }
}

class _MiniFilterButton extends StatelessWidget {
  const _MiniFilterButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PAGE 4: FORM SUBMIT FULL SCREEN ───────────────────────────────────────

class QcSubmitPage extends StatefulWidget {
  final QcItem item;
  final bool passed;

  const QcSubmitPage({super.key, required this.item, required this.passed});

  @override
  State<QcSubmitPage> createState() => _QcSubmitPageState();
}

class _QcSubmitPageState extends State<QcSubmitPage> {
  final _notesCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  double? _reworkHours = 7.0;

  String? _selectedUserId;
  List<Map<String, dynamic>> _availableUsers = [];

  DateTime? _reworkDate;
  String? _photoBeforeUrl;
  String? _evidencePhotoUrl;
  File? _photoBeforeLocal;
  File? _evidencePhotoLocal;

  bool _isUploadingBefore = false;
  bool _isUploadingEvidence = false;

  SessionManager get _session => sl<SessionManager>();

  bool get _needsDirectReworkPlan {
    final rawRole = (_session.role ?? '').trim().toLowerCase();
    return rawRole == 'kd' || rawRole == 'ketua_divisi';
  }

  String? _safeCurrentRoute() {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return ModalRoute.of(context)?.settings.name;
    }
  }

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.passed && _needsDirectReworkPlan) {
      _loadUsers();
    }
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('pending_qc_form');
      if (draftStr != null) {
        final map = jsonDecode(draftStr) as Map<String, dynamic>;
        if (map['notes'] != null) {
          _notesCtrl.text = map['notes'];
        }
        if (map['duration'] != null) {
          _durationCtrl.text = map['duration'];
        }
        if (map['reworkHours'] != null) {
          _reworkHours = map['reworkHours'] is num
              ? (map['reworkHours'] as num).toDouble()
              : TimeParser.parseHHmmToDecimal(map['reworkHours'].toString());
        }
        if (map['selectedUserId'] != null) {
          _selectedUserId = map['selectedUserId'];
        }
        if (map['reworkDate'] != null) {
          _reworkDate = DateTime.tryParse(map['reworkDate']);
        }
        if (map['photoBeforeUrl'] != null) {
          _photoBeforeUrl = map['photoBeforeUrl'];
        }
        if (map['evidencePhotoUrl'] != null) {
          _evidencePhotoUrl = map['evidencePhotoUrl'];
        }
        if (map['photoBeforeLocal'] != null) {
          _photoBeforeLocal = File(map['photoBeforeLocal']);
        }
        if (map['evidencePhotoLocal'] != null) {
          _evidencePhotoLocal = File(map['evidencePhotoLocal']);
        }
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _triggerAutoSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save Item and Passed boolean
      await prefs.setString('pending_qc_item', widget.item.toJson());
      await prefs.setBool('pending_qc_passed', widget.passed);

      // Save Form data
      final draftMap = {
        'notes': _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        'duration': _durationCtrl.text.isNotEmpty ? _durationCtrl.text : null,
        'reworkHours': _reworkHours != null
            ? TimeParser.formatDecimalToHHmm(_reworkHours!)
            : null,
        'selectedUserId': _selectedUserId,
        'reworkDate': _reworkDate?.toIso8601String(),
        'photoBeforeUrl': _photoBeforeUrl,
        'evidencePhotoUrl': _evidencePhotoUrl,
        'photoBeforeLocal': _photoBeforeLocal?.path,
        'evidencePhotoLocal': _evidencePhotoLocal?.path,
      };
      await prefs.setString('pending_qc_form', jsonEncode(draftMap));
    } catch (_) {}
  }

  Future<void> _loadUsers() async {
    try {
      final jobDs = sl<JobPlanDataSource>();
      final data = await jobDs.getDropdowns();
      if (!mounted) return;
      setState(() {
        _availableUsers = data['users'] ?? [];
      });
    } catch (_) {}
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDateLabel(DateTime date) =>
      DateFormat('d MMM yyyy', 'id_ID').format(date);

  Future<String?> _uploadPhoto(File file, String type) async {
    final remoteDs = sl<RemoteQcDataSource>();
    final session = sl<SessionManager>();

    final now = DateTime.now();
    final monthNames = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final monthFolder = monthNames[now.month];
    final tanggal = DateFormat('yyyy-MM-dd').format(now);

    final unit = _sanitizePath(widget.item.unitName);
    final div = _sanitizePath(session.divisionName ?? 'DIVISI');
    final job = _sanitizePath(widget.item.jobName);
    final panel = _sanitizePath(widget.item.panelName);
    final safeType = _sanitizePath(type);

    // Path: unit/divisi/Bulan/tanggal/{jobdesc} {panel}_{type} QC.jpg
    final filename =
        '$unit/$div/$monthFolder/$tanggal/$job ${panel}_$safeType QC.jpg';

    try {
      final ticket = await remoteDs.getQcUploadTicket(filename);
      final uploadUrl = ticket['upload_url'] ?? '';
      final publicUrl = ticket['public_url'] ?? '';
      if (uploadUrl.isEmpty || publicUrl.isEmpty) {
        throw Exception('Tiket upload QC tidak valid.');
      }

      // Simple PUT — much more reliable than StreamedRequest on mobile networks
      final bytes = await file.readAsBytes();
      final response = await http
          .put(
            Uri.parse(uploadUrl),
            headers: {
              'Content-Type': 'image/jpeg',
              'Content-Length': bytes.length.toString(),
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return publicUrl;
      }

      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint("UPLOAD S3 ERROR: $e");
      rethrow;
    }
  }

  static String _sanitizePath(String value) {
    return value
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_')
        .trim();
  }

  Future<void> _pickAndUpload(bool isBefore) async {
    final slot = isBefore ? 'before' : 'evidence';
    final label = isBefore ? 'Foto QC 1 (Before)' : 'Foto QC 2 (Evidence)';
    final currentRoute = _safeCurrentRoute();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Auto-save context
    try {
      final prefs = await SharedPreferences.getInstance();
      String? targetRoute = currentRoute;
      if (targetRoute != null &&
          targetRoute.isNotEmpty &&
          !targetRoute.contains('qcId=')) {
        targetRoute += targetRoute.contains('?') ? '&' : '?';
        targetRoute += 'qcId=${widget.item.coreId}';
      }
      if (targetRoute != null && targetRoute.isNotEmpty) {
        await prefs.setString('pending_camera_route', targetRoute);
      }
      await prefs.setString('pending_camera_slot', slot);
    } catch (_) {}
    await _triggerAutoSave();

    // Open In-App Camera (no OOM risk)
    final path = await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => InAppCameraPage(slot: slot, label: label),
        fullscreenDialog: true,
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_camera_slot');
    } catch (_) {}

    if (!mounted || path == null) return;

    final xfile = XFile(path);
    await _uploadPickedFile(xfile, isBefore, messenger);
  }

  Future<void> _uploadPickedFile(
    XFile pickedFile,
    bool isBefore,
    ScaffoldMessengerState messenger,
  ) async {
    if (!mounted) return;
    setState(() {
      if (isBefore) {
        _isUploadingBefore = true;
      } else {
        _isUploadingEvidence = true;
      }
    });

    try {
      final url = await _uploadPhoto(
        File(pickedFile.path),
        isBefore ? 'QC 1' : 'QC 2',
      );

      if (!mounted) return;
      setState(() {
        if (isBefore) {
          _photoBeforeUrl = url;
          _photoBeforeLocal = File(pickedFile.path);
          _isUploadingBefore = false;
        } else {
          _evidencePhotoUrl = url;
          _evidencePhotoLocal = File(pickedFile.path);
          _isUploadingEvidence = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isBefore) {
          _isUploadingBefore = false;
        } else {
          _isUploadingEvidence = false;
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal: $e'),
          backgroundColor: AppColors.statusLocked,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _submitData() async {
    final needsDirectReworkPlan = !widget.passed && _needsDirectReworkPlan;

    if (needsDirectReworkPlan) {
      if (_reworkDate == null ||
          _selectedUserId == null ||
          (_reworkHours == null || _reworkHours == 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal, pekerja, dan jam rework wajib diisi.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final repo = sl<QcRepository>();
      await repo.submitQc(
        coreId: widget.item.coreId,
        action: widget.passed ? 'lolos' : 'tidak_lolos',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        inspectionDurationMinutes: int.tryParse(_durationCtrl.text.trim()),
        photoBeforeUrl: _photoBeforeUrl,
        evidencePhotoUrl: _evidencePhotoUrl,
        reworkDate: needsDirectReworkPlan ? _formatDate(_reworkDate!) : null,
        reworkAssignedUser: needsDirectReworkPlan ? _selectedUserId : null,
        reworkDailyHours: needsDirectReworkPlan
            ? TimeParser.formatDecimalToHHmm(_reworkHours ?? 7.0)
            : null,
      );

      if (!mounted) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_qc_item');
        await prefs.remove('pending_qc_passed');
        await prefs.remove('pending_qc_form');
      } catch (_) {}

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.passed
                ? 'QC Lolos berhasil disimpan.'
                : needsDirectReworkPlan
                ? 'QC Tidak Lolos — rework dijadwalkan.'
                : 'QC Tidak Lolos — notifikasi dikirim ke KD.',
          ),
          backgroundColor: AppColors.statusDone,
        ),
      );
      navigator.pop(true); // Success
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal submit: $e'),
          backgroundColor: AppColors.statusLocked,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.passed ? 'Lolos QC' : 'Tidak Lolos QC'),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Pekerjaan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.passed
                    ? AppColors.statusDone.withValues(alpha: 0.1)
                    : AppColors.statusLocked.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.passed
                      ? AppColors.statusDone.withValues(alpha: 0.3)
                      : AppColors.statusLocked.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.panelName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.jobName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form
            TextField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Catatan QC',
                filled: true,
                fillColor: AppColors.surfaceInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Durasi QC (menit)',
                filled: true,
                fillColor: AppColors.surfaceInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Foto
            const Text(
              'Dokumentasi Foto',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            _PhotoPickerRow(
              label: 'Foto QC 1 ',
              url: _photoBeforeUrl,
              localFile: _photoBeforeLocal,
              isUploading: _isUploadingBefore,
              onPick: () => _pickAndUpload(true),
            ),
            const SizedBox(height: 12),
            _PhotoPickerRow(
              label: 'Foto QC 2 ',
              url: _evidencePhotoUrl,
              localFile: _evidencePhotoLocal,
              isUploading: _isUploadingEvidence,
              onPick: () => _pickAndUpload(false),
            ),

            if (!widget.passed && _needsDirectReworkPlan) ...[
              const SizedBox(height: 24),
              const Text(
                'Jadwal Pengerjaan Ulang',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.statusLocked,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2028),
                  );
                  if (picked != null) {
                    setState(() => _reworkDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal Pengerjaan Ulang',
                    filled: true,
                    fillColor: AppColors.surfaceInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  child: Text(
                    _reworkDate == null
                        ? 'Pilih tanggal'
                        : _formatDateLabel(_reworkDate!),
                    style: TextStyle(
                      color: _reworkDate == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedUserId,
                decoration: InputDecoration(
                  labelText: 'Pekerja',
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AppColors.surfaceCard,
                items: _availableUsers.map((u) {
                  final id = '${u['id'] ?? ''}'.trim();
                  final name = '${u['name'] ?? u['full_name'] ?? id}';
                  return DropdownMenuItem<String>(
                    value: id.isNotEmpty ? id : null,
                    child: Text(
                      name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedUserId = val);
                },
                hint: const Text(
                  'Pilih anggota',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              DurationInput(
                initialHours: _reworkHours,
                isTripleHours: false,
                labelText: '007:00',
                onChanged: (val) {
                  setState(() => _reworkHours = val);
                },
              ),
            ],
            if (!widget.passed && !_needsDirectReworkPlan) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusLocked.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.statusLocked.withValues(alpha: 0.2),
                  ),
                ),
                child: const Text(
                  'Reject pada level ini hanya mengirim pemberitahuan ke KD. Jobdesc penyempurnaan dan penjadwalan tindak lanjut dibuat oleh KD.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed:
                    (_isUploadingBefore ||
                        _isUploadingEvidence ||
                        _isSubmitting)
                    ? null
                    : _submitData,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.passed
                      ? AppColors.statusDone
                      : AppColors.statusLocked,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kirim Hasil QC',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── REUSABLE WIDGETS ────────────────────────────────────────────────────────

class _PhotoPickerRow extends StatelessWidget {
  final String label;
  final String? url;
  final File? localFile;
  final bool isUploading;
  final VoidCallback onPick;

  const _PhotoPickerRow({
    required this.label,
    required this.url,
    this.localFile,
    required this.isUploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  url != null ? '✅ Berhasil Dilampirkan' : label,
                  style: TextStyle(
                    fontSize: 13,
                    color: url != null
                        ? AppColors.statusDone
                        : AppColors.textMuted,
                  ),
                ),
              ),
              if (isUploading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (url == null)
                InkWell(
                  onTap: onPick,
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.gold,
                    size: 24,
                  ),
                )
              else
                InkWell(
                  onTap: onPick,
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.textMuted,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
        if (url != null && localFile != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              localFile!,
              cacheWidth: 1080,
              cacheHeight: 720,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: double.infinity,
                height: 180,
                color: AppColors.background,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image,
                  color: AppColors.textMuted,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QcCard extends StatelessWidget {
  final QcItem item;
  final bool canSubmit;
  final Function(bool) onAction; // true=Lolos, false=Reject

  const _QcCard({
    required this.item,
    required this.canSubmit,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isAntrian =
        item.countdownStatus == 'READY_QC' ||
        item.countdownStatus == 'WAITING_QC' ||
        item.countdownStatus == 'QC_READY';
    final isLolos = item.qcLastStatus == 'LOLOS';
    final isReject = item.qcLastStatus == 'TIDAK_LOLOS';

    Color statusColor;
    String statusLabel;

    if (isLolos) {
      statusColor = AppColors.statusDone;
      statusLabel = 'Lolos (${item.qcLevel ?? 'QC'})';
    } else if (isReject) {
      statusColor = AppColors.statusLocked;
      statusLabel = 'Reject (${item.qcLevel ?? 'QC'})';
    } else if (isAntrian) {
      statusColor = AppColors.orange;
      statusLabel = 'Antrian QC';
    } else {
      statusColor = AppColors.textMuted;
      statusLabel = 'Monitoring';
    }

    final canAct = canSubmit && isAntrian;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.panelName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              item.jobName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'Sisa Jam: ${(item.remainingHours ?? 0).toStringAsFixed(1)} h',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          if (item.qcNotes != null && item.qcNotes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInput,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Catatan Pengecekan: ${item.qcNotes}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          if (canAct)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onAction(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.statusLocked),
                        foregroundColor: AppColors.statusLocked,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Tidak Lolos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onAction(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusDone,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Lolos'),
                    ),
                  ),
                ],
              ),
            ),
          if (!canAct) const SizedBox(height: 6),
        ],
      ),
    );
  }
}
