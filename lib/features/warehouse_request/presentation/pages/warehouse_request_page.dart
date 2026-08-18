// Tujuan: Menampilkan dan mengelola pengajuan, pemakaian, riwayat, serta aktivitas warehouse.
// Caller: Route /warehouse melalui FeatureShellPage.
// Dependensi: WarehouseRepository, SessionManager, DateFilterBar, WarehouseLog.
// Main Functions: WarehouseRequestPage.
// Side Effects: Membaca dan mengubah transaksi warehouse melalui repository.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../features/task_execution/presentation/widgets/date_filter_bar.dart';
import '../../domain/entities/warehouse_log.dart';
import '../../domain/entities/warehouse_item_suggestion.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../utils/warehouse_history_filter.dart';
import '../widgets/warehouse_request_sheet.dart';

class WarehouseRequestPage extends StatefulWidget {
  const WarehouseRequestPage({super.key});

  @override
  State<WarehouseRequestPage> createState() => _WarehouseRequestPageState();
}

String _warehouseTrxLabel(String t) =>
    {
      'PEMINJAMAN': 'Peminjaman',
      'PENGAMBILAN': 'Pengambilan',
      'PENGEMBALIAN': 'Pengembalian',
      'PENYIMPANAN': 'Penyimpanan',
    }[t] ??
    t;

String _warehouseCategoryLabel(String t) =>
    {
      'TOOLS': 'Tools',
      'BAHAN': 'Bahan',
      'SPARE_PART': 'Spare Part',
      'SPAREPART': 'Spare Part',
      'MATERIAL': 'Bahan',
      'CONSUMABLE': 'Consumable',
    }[t] ??
    t;

String _normalizeWarehouseCategory(String category) {
  final raw = category.trim().toUpperCase().replaceAll('-', '_');
  switch (raw) {
    case 'SPAREPART':
    case 'SPARE_PART':
      return 'SPARE_PART';
    case 'MATERIAL':
    case 'BAHAN':
      return 'BAHAN';
    default:
      return raw;
  }
}

enum _WarehousePageMode { requester, console }

class _DivisionFilterOption {
  _DivisionFilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

class _UsageGroup {
  _UsageGroup({
    required this.id,
    required this.requester,
    required this.division,
    required this.items,
  });

  final String id;
  final String requester;
  final String division;
  final List<WarehouseLog> items;

  int get itemCount => items.length;
  DateTime get lastActivity =>
      items.first.actualReleaseDate ?? items.first.requestDate;
}

Set<String> _warehouseManagerRoles = {
  'KEPALA_GUDANG',
  'ADMIN_GUDANG',
  'GUDANG',
  'ADMIN',
};

String _normalizeWarehouseRole(String role, [String? jabatan]) {
  final raw = '$role ${jabatan ?? ''}'
      .toUpperCase()
      .replaceAll('—', ' ')
      .replaceAll('-', ' ')
      .replaceAll('_', ' ');

  bool has(String value) => raw.contains(value);
  bool hasAll(List<String> values) => values.every(has);

  if (has('GUDANG') && has('TOOLS')) return 'GUDANG_TOOLS';
  if (has('GUDANG') && (has('SPAREPART') || hasAll(['SPARE', 'PART']))) {
    return 'GUDANG_SPAREPART';
  }
  if (has('GUDANG') && (has('BAHAN') || has('MATERIAL') || has('CONSUMABLE'))) {
    return 'GUDANG_BAHAN';
  }
  if (has('KEPALA GUDANG') || hasAll(['KEPALA', 'GUDANG'])) {
    return 'KEPALA_GUDANG';
  }
  if (has('ADMIN GUDANG')) return 'ADMIN_GUDANG';
  if (has('PPIC') || has('PPC') || hasAll(['MANAGER', 'GUDANG'])) {
    return 'PPIC';
  }
  if (has('KETUA DIVISI')) return 'KETUA_DIVISI';
  if (has('TEAM LAPANGAN')) return 'TEAM_LAPANGAN';
  return role.toUpperCase();
}

String _divisionKey(WarehouseLog log) {
  final division = log.division.trim().isEmpty ? 'Tanpa Divisi' : log.division;
  return '${log.divisionId ?? 0}|${division.toUpperCase()}';
}

Set<String>? _warehouseScopeForRole(String role) {
  switch (role.toUpperCase()) {
    case 'GUDANG_TOOLS':
      return {'TOOLS'};
    case 'GUDANG_SPAREPART':
      return {'SPARE_PART'};
    case 'GUDANG_BAHAN':
      return {'BAHAN', 'CONSUMABLE'};
    default:
      return null;
  }
}

bool _canProcessWarehouseCategory(String role, String category) {
  final normalizedRole = role.toUpperCase();
  if (_warehouseManagerRoles.contains(normalizedRole)) return true;
  final scope = _warehouseScopeForRole(normalizedRole);
  if (scope == null) return false;
  return scope.contains(_normalizeWarehouseCategory(category));
}

String _warehouseScopeLabel(String role) {
  switch (role.toUpperCase()) {
    case 'GUDANG_TOOLS':
      return 'Scope tools';
    case 'GUDANG_SPAREPART':
      return 'Scope spare part';
    case 'GUDANG_BAHAN':
      return 'Scope bahan & consumable';
    case 'KEPALA_GUDANG':
      return 'Scope seluruh gudang';
    case 'PPIC':
    case 'PPC':
    case 'MANAGER_GUDANG':
      return 'Scope approval PPIC';
    case 'KD':
    case 'KETUA_DIVISI':
      return 'Scope approval divisi';
    case 'ADMIN':
      return 'Scope seluruh gudang';
    default:
      return 'Scope warehouse';
  }
}

class _WarehouseRequestPageState extends State<WarehouseRequestPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final SessionManager _session;
  late final WarehouseRepository _repo;

  List<WarehouseLog> _myLogs = [];
  List<WarehouseLog> _myItems = [];
  List<WarehouseLog> _pendingList = [];
  DateTime? _logsDateFilter;
  DateTime? _historyDateFilter;
  final Set<String> _selectedApprovalIds = <String>{};
  final Set<String> _selectedReminderGroupIds = <String>{};
  String? _selectedUsingDivisionKey;

  bool _isLoading = true;
  bool _isBulkApproving = false;
  bool _isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    _session = sl<SessionManager>();
    _repo = sl<WarehouseRepository>();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _logsDateFilter = DateTime(now.year, now.month, now.day);
    _historyDateFilter = DateTime(now.year, now.month, now.day);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── role helpers ──────────────────────────────────────────────
  String get _role => _session.isGlobalAccess
      ? 'ADMIN'
      : _normalizeWarehouseRole(_session.role ?? '', _session.jabatan);
  bool get _hasWarehouseLogsAccess =>
      _session.hasPerm(Perms.warehouseLogs) ||
      hasPermission(_role, Permission.warehouseLogsView);
  bool get _canApprove =>
      _session.hasPerm(Perms.warehouseApprove) ||
      hasPermission(_role, Permission.warehouseApprove);
  bool get _canRequest => true;
  bool get _isWarehouseStaffByPermissionsOnly =>
      _hasWarehouseLogsAccess && !_canRequest && !_canApprove;
  bool get _canProcessWarehouse =>
      _warehouseManagerRoles.contains(_role) ||
      _warehouseScopeForRole(_role) != null ||
      _isWarehouseStaffByPermissionsOnly;
  _WarehousePageMode get _mode =>
      (_canApprove ||
          _canProcessWarehouse ||
          (_hasWarehouseLogsAccess && !_canRequest))
      ? _WarehousePageMode.console
      : _WarehousePageMode.requester;

  bool _canProcessLogForCurrentUser(WarehouseLog log) {
    return _canProcessWarehouseCategory(_role, log.itemCategory) ||
        _isWarehouseStaffByPermissionsOnly;
  }

  bool _canApproveLog(WarehouseLog log) {
    if (!_canApprove) return false;
    if (_role == 'ADMIN' || _role == 'MIS') return log.isAnyPending;
    if (_role == 'KD' || _role == 'KETUA_DIVISI') return log.isPendingKd;
    if (_role == 'KEPALA_GUDANG' ||
        _role == 'ADMIN_GUDANG' ||
        _role == 'GUDANG') {
      return log.isPendingWh;
    }
    if (_role == 'PPIC' || _role == 'PPC') return log.isPendingPpic;
    return false;
  }

  bool _canBulkApproveLog(WarehouseLog log) =>
      _canApproveLog(log) && !log.isPenyimpanan;

  // ── load ──────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<List<WarehouseLog>>([
        _repo.getLogs(),
        if (_mode == _WarehousePageMode.console && _canApprove)
          _repo.getPendingApprovals()
        else
          Future.value(<WarehouseLog>[]),
        if (_mode == _WarehousePageMode.requester)
          _repo.getMyItems()
        else
          Future.value(<WarehouseLog>[]),
      ]);
      if (!mounted) return;
      final validSelection = results[1]
          .where(_canBulkApproveLog)
          .map((item) => item.id)
          .where(_selectedApprovalIds.contains)
          .toSet();
      final usingDivisionKeys = _visibleUsingItemsFrom(
        results[0],
      ).map(_divisionKey).toSet();
      setState(() {
        _myLogs = results[0];
        _pendingList = results[1];
        _myItems = results[2];
        _selectedApprovalIds
          ..clear()
          ..addAll(validSelection);
        _selectedReminderGroupIds.clear();
        if (_selectedUsingDivisionKey != null &&
            !usingDivisionKeys.contains(_selectedUsingDivisionKey)) {
          _selectedUsingDivisionKey = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal memuat data'),
        );
      }
    }
  }

  List<WarehouseLog> get _activeItems => _myLogs
      .where((l) => !l.isReturned && !l.isRejected && !l.isStored)
      .toList();

  List<WarehouseLog> get _historyItems =>
      _myLogs.where((l) => l.isReturned || l.isRejected || l.isStored).toList();

  List<WarehouseLog> get _filteredActiveItems => _activeItems;

  List<WarehouseLog> get _filteredHistoryItems {
    return warehouseLogsForDate(
      _historyItems,
      _historyDateFilter ?? DateTime.now(),
    );
  }

  List<WarehouseLog> get _filteredLogItems {
    return warehouseLogsForDate(_myLogs, _logsDateFilter ?? DateTime.now());
  }

  List<WarehouseLog> _visibleUsingItemsFrom(List<WarehouseLog> source) {
    final items = source.where((log) {
      if (!log.isReleased && !log.isInstalled) return false;
      if (_mode == _WarehousePageMode.console && _canProcessWarehouse) {
        return _canProcessLogForCurrentUser(log);
      }
      return true;
    }).toList();
    items.sort((a, b) {
      final aDate = a.actualReleaseDate ?? a.requestDate;
      final bDate = b.actualReleaseDate ?? b.requestDate;
      return bDate.compareTo(aDate);
    });
    return items;
  }

  List<WarehouseLog> get _usingItems => _visibleUsingItemsFrom(_myLogs);

  List<_DivisionFilterOption> get _usingDivisionOptions {
    final map = <String, String>{};
    for (final item in _usingItems) {
      final label = item.division.trim().isEmpty
          ? 'Tanpa Divisi'
          : item.division;
      map[_divisionKey(item)] = label;
    }
    final options = map.entries
        .map(
          (entry) => _DivisionFilterOption(key: entry.key, label: entry.value),
        )
        .toList();
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  List<WarehouseLog> get _filteredUsingItems {
    if (_selectedUsingDivisionKey == null) return _usingItems;
    return _usingItems
        .where((item) => _divisionKey(item) == _selectedUsingDivisionKey)
        .toList();
  }

  List<_UsageGroup> get _usingGroups {
    final grouped = <String, List<WarehouseLog>>{};
    final requesterMeta = <String, ({String requester, String division})>{};

    for (final item in _filteredUsingItems) {
      final key = '${item.employeeId ?? item.requester}|${_divisionKey(item)}';
      grouped.putIfAbsent(key, () => <WarehouseLog>[]).add(item);
      requesterMeta[key] = (
        requester: item.requester,
        division: item.division.trim().isEmpty ? 'Tanpa Divisi' : item.division,
      );
    }

    final groups = grouped.entries.map((entry) {
      final items = entry.value
        ..sort((a, b) {
          final aDate = a.actualReleaseDate ?? a.requestDate;
          final bDate = b.actualReleaseDate ?? b.requestDate;
          return bDate.compareTo(aDate);
        });
      final meta = requesterMeta[entry.key]!;
      return _UsageGroup(
        id: entry.key,
        requester: meta.requester,
        division: meta.division,
        items: items,
      );
    }).toList();

    groups.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return groups;
  }

  int get _selectedReminderCount => _usingGroups
      .where((group) => _selectedReminderGroupIds.contains(group.id))
      .length;

  bool get _areAllRemindersSelected =>
      _usingGroups.isNotEmpty &&
      _usingGroups.every(
        (group) => _selectedReminderGroupIds.contains(group.id),
      );

  void _toggleReminderSelection(String groupId, bool selected) {
    setState(() {
      if (selected) {
        _selectedReminderGroupIds.add(groupId);
      } else {
        _selectedReminderGroupIds.remove(groupId);
      }
    });
  }

  void _toggleSelectAllReminders() {
    if (_usingGroups.isEmpty) return;
    setState(() {
      if (_areAllRemindersSelected) {
        _selectedReminderGroupIds.removeAll(
          _usingGroups.map((group) => group.id),
        );
      } else {
        _selectedReminderGroupIds.addAll(_usingGroups.map((group) => group.id));
      }
    });
  }

  String _reminderSummaryForGroup(_UsageGroup group) {
    if (group.items.length == 1) {
      return 'Harap kembalikan ${group.items.first.itemName} ke gudang.';
    }
    final names = group.items.take(3).map((item) => item.itemName).join(', ');
    final suffix = group.items.length > 3 ? ', dan lainnya' : '';
    return 'Harap kembalikan ${group.items.length} barang ke gudang: $names$suffix.';
  }

  Future<void> _sendReminderForGroup(_UsageGroup group) async {
    await _repo.remindReturn(
      logId: group.items.first.id,
      notes: _reminderSummaryForGroup(group),
    );
  }

  Future<void> _submitBulkReminder() async {
    if (_isSendingReminder) return;
    final selectedGroups = _usingGroups
        .where((group) => _selectedReminderGroupIds.contains(group.id))
        .toList();
    if (selectedGroups.isEmpty) {
      AppNotification.showWarning(context, 'Pilih anggota dulu.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Kirim Reminder',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Kirim reminder ke ${selectedGroups.length} anggota terpilih?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: Text('Kirim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSendingReminder = true);
    final failedIds = <String>{};
    var successCount = 0;

    for (final group in selectedGroups) {
      try {
        await _sendReminderForGroup(group);
        successCount += 1;
      } catch (_) {
        failedIds.add(group.id);
      }
    }

    if (!mounted) return;
    setState(() {
      _isSendingReminder = false;
      _selectedReminderGroupIds
        ..clear()
        ..addAll(failedIds);
    });

    if (failedIds.isEmpty) {
      AppNotification.showSuccess(
        context,
        'Reminder terkirim ke $successCount anggota',
      );
      return;
    }

    final failedCount = failedIds.length;
    final prefix = successCount > 0 ? '$successCount berhasil. ' : '';
    AppNotification.showError(
      context,
      '$prefix$failedCount reminder gagal dikirim.',
    );
  }

  List<WarehouseLog> get _warehouseActionItems {
    return _myLogs.where((log) {
      if (!_canProcessLogForCurrentUser(log)) return false;
      if (log.isApproved && !log.isPenyimpanan && log.isOpen) {
        return true;
      }
      if (log.isReady) return true;
      if (log.isReturned) return true;
      if (log.isPenyimpanan && log.isStored) return true;
      return false;
    }).toList();
  }

  List<WarehouseLog> get _consoleInboxItems {
    final map = <String, WarehouseLog>{};
    for (final item in _pendingList) {
      map[item.id] = item;
    }
    for (final item in _warehouseActionItems) {
      map[item.id] = item;
    }
    final items = map.values.toList();
    items.sort((a, b) {
      final rankCompare = _queueRank(a).compareTo(_queueRank(b));
      if (rankCompare != 0) return rankCompare;
      return b.requestDate.compareTo(a.requestDate);
    });
    return items;
  }

  Future<void> _showRequestMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Pilih Aksi Gudang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: AppColors.gold),
              title: const Text('Peminjaman'),
              subtitle: const Text('Pinjam barang dari gudang'),
              onTap: () => Navigator.pop(ctx, 'PEMINJAMAN'),
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app_rounded, color: AppColors.gold),
              title: const Text('Ambil'),
              subtitle: const Text('Ambil barang untuk dipakai langsung'),
              onTap: () => Navigator.pop(ctx, 'PENGAMBILAN'),
            ),
            ListTile(
              leading: Icon(
                Icons.assignment_return_outlined,
                color: AppColors.gold,
              ),
              title: const Text('Pengembalian'),
              subtitle: const Text('Kembalikan barang yang dipinjam'),
              onTap: () => Navigator.pop(ctx, 'RETURN'),
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined, color: AppColors.gold),
              title: const Text('Penyimpanan'),
              subtitle: const Text('Simpan barang yang dilepas dari unit'),
              onTap: () => Navigator.pop(ctx, 'STORE'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'PEMINJAMAN':
      case 'PENGAMBILAN':
        final ok = await WarehouseRequestSheet.show(
          context: context,
          transactionType: choice,
        );
        if (ok && mounted) _loadAll();
      case 'RETURN':
        await _openReturnList();
      case 'STORE':
        final stored = await WarehouseRequestSheet.showStorage(
          context: context,
        );
        if (stored && mounted) _loadAll();
    }
  }

  Future<void> _openReturnList() async {
    final items = (await _repo.getMyItems())
        .where(
          (l) =>
              l.transactionType == 'PEMINJAMAN' && !l.isReturned && !l.isStored,
        )
        .toList();
    if (!mounted) return;
    final selected = await showModalBottomSheet<WarehouseLog>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Tidak ada barang pinjaman untuk dikembalikan.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Pilih Barang yang Dikembalikan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...items.map(
                    (log) => ListTile(
                      leading: Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.gold,
                      ),
                      title: Text(
                        log.itemName,
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        '${log.unitName} · ${log.qty % 1 == 0 ? log.qty.toInt() : log.qty} ${log.uom}',
                      ),
                      onTap: () => Navigator.pop(ctx, log),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
    if (!mounted || selected == null) return;
    final returned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnSheet(log: selected, repo: _repo),
    );
    if (returned == true && mounted) _loadAll();
  }

  List<WarehouseLog> get _bulkApprovalItems =>
      _pendingList.where(_canBulkApproveLog).toList();

  int get _selectedApprovalCount => _bulkApprovalItems
      .where((item) => _selectedApprovalIds.contains(item.id))
      .length;

  bool get _areAllBulkApprovalSelected =>
      _bulkApprovalItems.isNotEmpty &&
      _bulkApprovalItems.every(
        (item) => _selectedApprovalIds.contains(item.id),
      );

  int _queueRank(WarehouseLog log) {
    if (log.isAnyPending) return 0;
    if (log.isApproved && !log.isPenyimpanan && log.isOpen) {
      return 1;
    }
    if (log.isReady) return 2;
    if (log.isReturned) return 3;
    if (log.isPenyimpanan && log.isStored) return 4;
    return 9;
  }

  void _toggleApprovalSelection(String logId, bool selected) {
    setState(() {
      if (selected) {
        _selectedApprovalIds.add(logId);
      } else {
        _selectedApprovalIds.remove(logId);
      }
    });
  }

  void _toggleSelectAllApprovals() {
    if (_bulkApprovalItems.isEmpty) return;
    setState(() {
      if (_areAllBulkApprovalSelected) {
        _selectedApprovalIds.removeAll(
          _bulkApprovalItems.map((item) => item.id),
        );
      } else {
        _selectedApprovalIds.addAll(_bulkApprovalItems.map((item) => item.id));
      }
    });
  }

  Future<void> _submitBulkApproval(bool approved) async {
    if (_isBulkApproving) return;
    final selectedItems = _bulkApprovalItems
        .where((item) => _selectedApprovalIds.contains(item.id))
        .toList();
    if (selectedItems.isEmpty) {
      AppNotification.showWarning(context, 'Pilih item dulu.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          approved ? 'Setujui Beberapa Item' : 'Tolak Beberapa Item',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          approved
              ? 'Setujui ${selectedItems.length} item yang dipilih?'
              : 'Tolak ${selectedItems.length} item yang dipilih?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: approved
                  ? AppColors.statusDone
                  : AppColors.statusLocked,
              foregroundColor: Colors.white,
            ),
            child: Text(approved ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBulkApproving = true);
    final failedIds = <String>[];
    var successCount = 0;
    for (final item in selectedItems) {
      try {
        await _repo.setApprovalStatus(logId: item.id, approved: approved);
        successCount += 1;
      } catch (_) {
        failedIds.add(item.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _isBulkApproving = false;
      _selectedApprovalIds
        ..clear()
        ..addAll(failedIds);
    });
    await _loadAll();
    if (!mounted) return;

    if (failedIds.isEmpty) {
      AppNotification.showSuccess(
        context,
        approved
            ? '$successCount item disetujui'
            : '$successCount item ditolak',
      );
      return;
    }

    final failedCount = failedIds.length;
    final prefix = successCount > 0 ? '$successCount berhasil. ' : '';
    AppNotification.showError(
      context,
      '$prefix$failedCount item gagal diproses.',
    );
  }

  // ── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tabs = _mode == _WarehousePageMode.console
        ? [
            _canProcessWarehouse ? 'Antrean' : 'Persetujuan',
            'Sedang Dipakai',
            'Aktivitas',
          ]
        : ['Pengajuan', 'Sedang Dipakai', 'Riwayat'];

    return Column(
      children: [
        // Tab bar
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 3, color: AppColors.gold),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            dividerHeight: 0,
            tabs: tabs.map((t) {
              final isPrimary =
                  (_mode == _WarehousePageMode.console && t == tabs.first) ||
                  (_mode == _WarehousePageMode.requester && t == 'Pengajuan');
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPrimary) ...[
                      Icon(Icons.warehouse_outlined, size: 16),
                      SizedBox(width: 8),
                    ],
                    Text(t),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: _mode == _WarehousePageMode.console
                            ? [_consoleTab(), _usingTab(), _logsTab()]
                            : [_activeTab(), _myItemsTab(), _historyTab()],
                      ),
              ),
              if (_mode == _WarehousePageMode.console && _canRequest)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'wh_fab_req_console',
                    onPressed: _showRequestMenu,
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.background,
                    icon: Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      'Ajukan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─ Tabs for OP ───────────────────────────────────────────────
  Widget _activeTab() => Column(
    children: [
      Expanded(
        child: _listScaffold(
          items: _filteredActiveItems,
          emptyMsg: 'Tidak ada transaksi aktif',
          fab: _canRequest
              ? FloatingActionButton.extended(
                  heroTag: 'wh_fab_req',
                  onPressed: _showRequestMenu,
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.background,
                  icon: Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    'Ajukan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        ),
      ),
    ],
  );

  Widget _myItemsTab() => _listScaffold(
    items: _myItems,
    emptyMsg: 'Tidak ada barang yang sedang Anda pegang',
  );

  // ─ Tabs for warehouse console ────────────────────────────────
  Widget _consoleTab() => Column(
    children: [
      if (_canProcessWarehouse) ...[
        _WarehouseRoleBanner(
          title: 'Antrean Gudang',
          subtitle: _warehouseScopeLabel(_role),
        ),
        _WarehouseConsoleSummary(
          waitingApproval: _pendingList.length,
          needPrepare: _warehouseActionItems
              .where(
                (log) => log.isApproved && !log.isPenyimpanan && log.isOpen,
              )
              .length,
          readyToHandover: _warehouseActionItems
              .where((log) => log.isReady)
              .length,
          needStoreOrLocate: _warehouseActionItems
              .where(
                (log) => log.isReturned || (log.isPenyimpanan && log.isStored),
              )
              .length,
        ),
      ],
      if (_canApprove && _bulkApprovalItems.isNotEmpty)
        _ApprovalBulkBar(
          selectedCount: _selectedApprovalCount,
          areAllSelected: _areAllBulkApprovalSelected,
          isBusy: _isBulkApproving,
          onToggleAll: _toggleSelectAllApprovals,
          onApprove: () => _submitBulkApproval(true),
          onReject: () => _submitBulkApproval(false),
        ),
      Expanded(
        child: _listScaffold(
          items: _consoleInboxItems,
          emptyMsg: _canProcessWarehouse
              ? 'Tidak ada antrean gudang yang perlu diproses'
              : 'Tidak ada persetujuan yang menunggu',
        ),
      ),
    ],
  );

  Widget _usingTab() {
    final groups = _usingGroups;
    // Warehouse console (gudang staff) = bisa send reminder
    // KD/PPIC/KEPALA_GUDANG sebagai approver-only = hanya monitoring, tidak send reminder
    final canSendReminder = _canProcessWarehouse;
    return Column(
      children: [
        if (_mode == _WarehousePageMode.console)
          _WarehouseRoleBanner(
            title: 'Sedang Dipakai',
            subtitle: _warehouseScopeLabel(_role),
          ),
        // Summary harian (jumlah bahan/consumable dipakai hari ini)
        if (_mode == _WarehousePageMode.console)
          _DailyUsageSummaryBar(allItems: _usingItems),
        _UsageOverviewBar(
          memberCount: groups.length,
          itemCount: _filteredUsingItems.length,
        ),
        _DivisionFilterBar(
          options: _usingDivisionOptions,
          selectedKey: _selectedUsingDivisionKey,
          onSelected: (key) {
            setState(() {
              _selectedUsingDivisionKey = key;
              _selectedReminderGroupIds.clear();
            });
          },
        ),
        if (canSendReminder && _usingGroups.isNotEmpty)
          _ReminderBulkBar(
            selectedCount: _selectedReminderCount,
            areAllSelected: _areAllRemindersSelected,
            isBusy: _isSendingReminder,
            onToggleAll: _toggleSelectAllReminders,
            onSend: _submitBulkReminder,
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _loadAll,
            child: groups.isEmpty
                ? ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.24,
                      ),
                      _EmptyState(
                        message: 'Belum ada anggota yang sedang memakai barang',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: groups.length,
                    itemBuilder: (_, index) => _UsageGroupCard(
                      group: groups[index],
                      showSelection: canSendReminder,
                      selected: _selectedReminderGroupIds.contains(
                        groups[index].id,
                      ),
                      selectionBusy: _isSendingReminder,
                      onSelectedChanged: canSendReminder
                          ? (selected) => _toggleReminderSelection(
                              groups[index].id,
                              selected,
                            )
                          : null,
                      onRemind: canSendReminder
                          ? () async {
                              try {
                                await _sendReminderForGroup(groups[index]);
                                if (!mounted) return;
                                AppNotification.showSuccess(
                                  context,
                                  'Reminder terkirim ke ${groups[index].requester}',
                                );
                              } catch (e) {
                                if (!mounted) return;
                                AppNotification.showError(
                                  context,
                                  friendlyMessage(
                                    e,
                                    fallback: 'Gagal kirim reminder',
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _logsTab() => Column(
    children: [
      if (_mode == _WarehousePageMode.console)
        _WarehouseRoleBanner(
          title: 'Aktivitas Warehouse',
          subtitle: _warehouseScopeLabel(_role),
        ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 200) return;
            setState(() {
              _logsDateFilter = (_logsDateFilter ?? DateTime.now()).add(
                Duration(days: velocity < 0 ? 1 : -1),
              );
            });
          },
          child: DateFilterBar(
            selectedDate: _logsDateFilter ?? DateTime.now(),
            onDateChanged: (date) {
              setState(() => _logsDateFilter = date);
            },
          ),
        ),
      ),
      Expanded(
        child: _listScaffold(
          items: _filteredLogItems,
          emptyMsg: _logsDateFilter != null
              ? 'Tidak ada aktivitas pada tanggal ini'
              : 'Belum ada aktivitas warehouse',
        ),
      ),
    ],
  );

  Widget _historyTab() => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 200) return;
            setState(() {
              _historyDateFilter = (_historyDateFilter ?? DateTime.now()).add(
                Duration(days: velocity < 0 ? 1 : -1),
              );
            });
          },
          child: DateFilterBar(
            selectedDate: _historyDateFilter ?? DateTime.now(),
            onDateChanged: (date) {
              setState(() => _historyDateFilter = date);
            },
          ),
        ),
      ),
      Expanded(
        child: _listScaffold(
          items: _filteredHistoryItems,
          emptyMsg: _historyDateFilter != null
              ? 'Tidak ada riwayat pada tanggal ini'
              : 'Belum ada riwayat transaksi',
        ),
      ),
    ],
  );

  // ─ Shared scroll scaffold ────────────────────────────────────
  Widget _listScaffold({
    required List<WarehouseLog> items,
    required String emptyMsg,
    Widget? fab,
  }) {
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _loadAll,
          child: items.isEmpty
              ? ListView(
                  physics: AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                    _EmptyState(message: emptyMsg),
                    SizedBox(height: 12),
                  ],
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    fab != null ? 88 : 24,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _LogCard(
                    log: items[i],
                    canApprove: _canApprove,
                    canProcessWarehouse: _canProcessWarehouse,
                    forceWarehouseProcessing:
                        _isWarehouseStaffByPermissionsOnly,
                    currentRole: _role,
                    currentUserId: _session.userId ?? _session.employeeId ?? '',
                    repo: _repo,
                    onDone: _loadAll,
                    showSelection: _canBulkApproveLog(items[i]),
                    selected: _selectedApprovalIds.contains(items[i].id),
                    selectionBusy: _isBulkApproving,
                    onSelectedChanged: (selected) =>
                        _toggleApprovalSelection(items[i].id, selected),
                  ),
                ),
        ),
        if (fab != null) Positioned(right: 16, bottom: 24, child: fab),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DAILY USAGE SUMMARY BAR (monitoring KP di "Sedang Dipakai")
// ═══════════════════════════════════════════════════════════════
class _DailyUsageSummaryBar extends StatelessWidget {
  const _DailyUsageSummaryBar({required this.allItems});

  final List<WarehouseLog> allItems;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    final todayBahan = allItems.where((l) {
      final released = l.actualReleaseDate ?? l.requestDate;
      return (l.itemCategory == 'BAHAN' || l.itemCategory == 'CONSUMABLE') &&
          sameDay(released);
    }).length;

    final todayTools = allItems.where((l) {
      final released = l.actualReleaseDate ?? l.requestDate;
      return l.itemCategory == 'TOOLS' && sameDay(released);
    }).length;

    final todaySparepart = allItems.where((l) {
      final released = l.actualReleaseDate ?? l.requestDate;
      return l.itemCategory == 'SPARE_PART' && sameDay(released);
    }).length;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.today_outlined, size: 14, color: AppColors.gold),
          SizedBox(width: 6),
          Text(
            'Hari ini:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          SizedBox(width: 12),
          _SummaryChip(
            label: 'Bahan',
            count: todayBahan,
            color: Color(0xFF13B8A6),
          ),
          SizedBox(width: 8),
          _SummaryChip(
            label: 'Tools',
            count: todayTools,
            color: AppColors.gold,
          ),
          SizedBox(width: 8),
          _SummaryChip(
            label: 'Sparepart',
            count: todaySparepart,
            color: Color(0xFF5B8EFF),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        margin: EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.inventory_2_outlined,
                size: 26,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada data',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseRoleBanner extends StatelessWidget {
  const _WarehouseRoleBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.warehouse_outlined, size: 12, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarehouseConsoleSummary extends StatelessWidget {
  const _WarehouseConsoleSummary({
    required this.waitingApproval,
    required this.needPrepare,
    required this.readyToHandover,
    required this.needStoreOrLocate,
  });

  final int waitingApproval;
  final int needPrepare;
  final int readyToHandover;
  final int needStoreOrLocate;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: EdgeInsets.only(bottom: 12),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          _StatPill(
            label: 'ACC',
            value: waitingApproval,
            color: AppColors.statusInProgress,
          ),
          _StatPill(
            label: 'Siapkan',
            value: needPrepare,
            color: Color(0xFF13B8A6),
          ),
          _StatPill(
            label: 'Siap Ambil',
            value: readyToHandover,
            color: AppColors.gold,
          ),
          _StatPill(
            label: 'Masuk',
            value: needStoreOrLocate,
            color: Color(0xFF5B8EFF),
          ),
        ],
      ),
    );
  }
}

class _UsageOverviewBar extends StatelessWidget {
  const _UsageOverviewBar({required this.memberCount, required this.itemCount});

  final int memberCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _OverviewMetric(
            icon: Icons.people_outline_rounded,
            label: 'Anggota',
            value: '$memberCount',
          ),
          SizedBox(width: 10),
          Container(width: 1, height: 28, color: AppColors.border),
          SizedBox(width: 10),
          _OverviewMetric(
            icon: Icons.inventory_2_outlined,
            label: 'Barang',
            value: '$itemCount',
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.gold),
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DivisionFilterBar extends StatelessWidget {
  const _DivisionFilterBar({
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<_DivisionFilterOption> options;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return SizedBox(height: 2);
    return SizedBox(
      height: 42,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          _DivisionChip(
            label: 'Semua',
            selected: selectedKey == null,
            onTap: () => onSelected(null),
          ),
          for (final option in options)
            _DivisionChip(
              label: option.label,
              selected: option.key == selectedKey,
              onTap: () => onSelected(option.key),
            ),
        ],
      ),
    );
  }
}

class _DivisionChip extends StatelessWidget {
  const _DivisionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? AppColors.background : AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.gold
              : AppColors.border.withValues(alpha: 0.9),
        ),
        backgroundColor: AppColors.surfaceCard,
        selectedColor: AppColors.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }
}

class _ApprovalBulkBar extends StatelessWidget {
  const _ApprovalBulkBar({
    required this.selectedCount,
    required this.areAllSelected,
    required this.isBusy,
    required this.onToggleAll,
    required this.onApprove,
    required this.onReject,
  });

  final int selectedCount;
  final bool areAllSelected;
  final bool isBusy;
  final VoidCallback onToggleAll;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selectedCount > 0
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedCount > 0
              ? AppColors.gold.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: areAllSelected,
            onChanged: isBusy ? null : (_) => onToggleAll(),
            activeColor: AppColors.gold,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 2),
          Text(
            selectedCount == 0 ? 'Pilih Semua' : '$selectedCount dipilih',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selectedCount > 0 ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          Spacer(),
          if (selectedCount > 0) ...[
            TextButton(
              onPressed: isBusy ? null : onReject,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.statusLocked,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Tolak',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(width: 4),
            FilledButton.icon(
              onPressed: isBusy ? null : onApprove,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusDone,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                visualDensity: VisualDensity.compact,
              ),
              icon: isBusy
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.done_all_rounded, size: 16),
              label: Text('ACC', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderBulkBar extends StatelessWidget {
  const _ReminderBulkBar({
    required this.selectedCount,
    required this.areAllSelected,
    required this.isBusy,
    required this.onToggleAll,
    required this.onSend,
  });

  final int selectedCount;
  final bool areAllSelected;
  final bool isBusy;
  final VoidCallback onToggleAll;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selectedCount > 0
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedCount > 0
              ? AppColors.gold.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: areAllSelected,
            onChanged: isBusy ? null : (_) => onToggleAll(),
            activeColor: AppColors.gold,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 2),
          Text(
            selectedCount == 0
                ? 'Pilih Semua'
                : '$selectedCount anggota dipilih',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selectedCount > 0 ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          Spacer(),
          FilledButton.icon(
            onPressed: isBusy ? null : onSend,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            icon: isBusy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  )
                : Icon(Icons.notifications_active_outlined, size: 16),
            label: Text(
              'Reminder',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasData = value > 0;
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: hasData ? color.withValues(alpha: 0.12) : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasData ? color.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: hasData ? color : AppColors.textMuted,
            ),
          ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasData ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageGroupCard extends StatelessWidget {
  const _UsageGroupCard({
    required this.group,
    this.showSelection = false,
    this.selected = false,
    this.selectionBusy = false,
    this.onSelectedChanged,
    this.onRemind,
  });

  final _UsageGroup group;
  final bool showSelection;
  final bool selected;
  final bool selectionBusy;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onRemind;
  static final _df = DateFormat('d MMM', 'id_ID');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.requester,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      group.division,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showSelection)
                Checkbox(
                  value: selected,
                  onChanged: selectionBusy
                      ? null
                      : (value) => onSelectedChanged?.call(value ?? false),
                  activeColor: AppColors.gold,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${group.itemCount} barang',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...group.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _UsageItemRow(log: item, dateFormat: _df),
            ),
          ),
          if (onRemind != null) ...[
            SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: selectionBusy ? null : onRemind,
                icon: Icon(Icons.notifications_active_outlined, size: 16),
                label: Text('Reminder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.5),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageItemRow extends StatelessWidget {
  const _UsageItemRow({required this.log, required this.dateFormat});

  final WarehouseLog log;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final statusLabel = log.isInstalled ? 'Terpasang' : 'Dipakai';
    final accent = log.isInstalled ? AppColors.gold : Color(0xFF13B8A6);
    final subtitleParts = <String>[
      '${log.qty % 1 == 0 ? log.qty.toInt() : log.qty} ${log.uom}',
      if (log.unitName != null && log.unitName!.trim().isNotEmpty)
        log.unitName!,
      if (log.jobdesc != null && log.jobdesc!.trim().isNotEmpty) log.jobdesc!,
    ];

    return Container(
      padding: EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  log.itemName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            subtitleParts.join(' · '),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 11,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 4),
              Text(
                dateFormat.format(log.actualReleaseDate ?? log.requestDate),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOG CARD
// ═══════════════════════════════════════════════════════════════
class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.canApprove,
    required this.canProcessWarehouse,
    required this.forceWarehouseProcessing,
    required this.currentRole,
    required this.currentUserId,
    required this.repo,
    required this.onDone,
    this.showSelection = false,
    this.selected = false,
    this.selectionBusy = false,
    this.onSelectedChanged,
  });

  final WarehouseLog log;
  final bool canApprove;
  final bool canProcessWarehouse;
  final bool forceWarehouseProcessing;
  final String currentRole;
  final String currentUserId;
  final WarehouseRepository repo;
  final VoidCallback onDone;
  final bool showSelection;
  final bool selected;
  final bool selectionBusy;
  final ValueChanged<bool>? onSelectedChanged;

  static final _df = DateFormat('d MMM yy', 'id_ID');
  bool get _isOwner =>
      currentUserId.isNotEmpty && log.employeeId == currentUserId;
  bool get _isWarehouseProcessor =>
      canProcessWarehouse &&
      (forceWarehouseProcessing ||
          _canProcessWarehouseCategory(currentRole, log.itemCategory));
  bool get _isPrivilegedReleaseRole =>
      _isWarehouseProcessor ||
      {
        'KD',
        'KEPALA_GUDANG',
        'PPIC',
        'ADMIN',
        'KETUA_DIVISI',
        'PPC',
        'MANAGER_GUDANG',
        'MIS',
      }.contains(currentRole.toUpperCase());
  bool get _canReady =>
      _isWarehouseProcessor &&
      log.isApproved &&
      !log.isPenyimpanan &&
      log.isOpen;
  bool get _canLocate =>
      _isWarehouseProcessor && log.isPenyimpanan && log.isStored;
  bool get _canStore => _isWarehouseProcessor && log.isReturned;
  bool get _canRelease => (_isPrivilegedReleaseRole || _isOwner) && log.isReady;
  bool get _canInstall => _isOwner && log.isReleased;
  bool get _canReturn => _isOwner && (log.isReleased || log.isInstalled);
  bool get _canRemindReturn =>
      !_isOwner && _isWarehouseProcessor && (log.isReleased || log.isInstalled);
  bool get _canMatchName =>
      _isPrivilegedReleaseRole &&
      !log.isRejected &&
      !log.isReturned &&
      !log.isStored;

  // status colours / icons ──────────────────────────────────────
  Color get _statusColor {
    if (log.isRejected) return AppColors.statusLocked;
    if (log.normalizedItemStatus == 'LOST') return Color(0xFF111111);
    if (log.isStored) return Color(0xFF5B8EFF);
    if (log.isReturned) return Color(0xFF8B5CF6);
    if (log.isReady) return Color(0xFF13B8A6);
    if (log.isAnyPending) return AppColors.statusInProgress;
    if (log.isReleased) return AppColors.statusDone;
    if (log.isApproved) return Color(0xFF7C8799);
    if (log.isOpen) return AppColors.textMuted;
    return AppColors.textMuted;
  }

  IconData get _icon {
    if (log.isRejected) return Icons.cancel_outlined;
    if (log.normalizedItemStatus == 'LOST') return Icons.error_outline_rounded;
    if (log.isStored) return Icons.archive_rounded;
    if (log.isReturned) return Icons.check_circle_outline_rounded;
    if (log.isInstalled) return Icons.build_circle_outlined;
    if (log.isReady) return Icons.inventory_rounded;
    if (log.isAnyPending) return Icons.hourglass_top_rounded;
    return Icons.inventory_2_outlined;
  }

  String get _badge {
    if (log.isRejected) return 'Ditolak';
    if (log.isPendingKd) return 'Menunggu Ketua Divisi';
    if (log.isPendingWh) return 'Menunggu Gudang';
    if (log.isPendingPpic) return 'Menunggu PPIC';
    if (_canReady) return 'Perlu Disiapkan';
    if (_canRelease && !_isOwner) return 'Menunggu Diambil';
    if (_canStore) return 'Masuk Gudang';
    if (_canLocate) {
      return log.needsLocate ? 'Tentukan Lokasi' : 'Perbarui Lokasi';
    }
    if (log.isReady) return 'Siap Diambil';
    if (log.isStored) return 'Sudah Disimpan';
    if (log.isReturned) return 'Dikembalikan';
    if (log.isReleased) return 'Sudah Diambil';
    if (log.isApproved) return 'Diproses Gudang';
    if (log.normalizedItemStatus == 'LOST') return 'Hilang';
    return 'Menunggu';
  }

  String _cleanNotes(String n) {
    final idx = n.indexOf('[APPROVAL_HISTORY]');
    if (idx != -1) n = n.substring(0, idx);
    return n
        .replaceAll('[INSTALL_TO_UNIT]', '')
        .replaceAll('[PENYIMPANAN]', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LogDetailSheet(
          log: log,
          footer: _showActions() ? _buildActions(context) : null,
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.55)
                : log.isAnyPending
                ? _statusColor.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_icon, size: 18, color: _statusColor),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.itemName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${_warehouseTrxLabel(log.transactionType)} · ${log.qty % 1 == 0 ? log.qty.toInt() : log.qty} ${log.uom}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showSelection) ...[
                            Checkbox(
                              value: selected,
                              onChanged: selectionBusy
                                  ? null
                                  : (value) =>
                                        onSelectedChanged?.call(value ?? false),
                              activeColor: AppColors.gold,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(width: 6),
                          ],
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _badge.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (log.unitName != null)
                        _chip(Icons.directions_car_outlined, log.unitName!),
                      _chip(Icons.person_outline_rounded, log.requester),
                      _chip(Icons.business_outlined, log.division),
                      _chip(
                        Icons.calendar_today_outlined,
                        _df.format(log.requestDate),
                      ),
                    ],
                  ),
                  if (log.notes != null &&
                      _cleanNotes(log.notes!).isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
                      'Catatan: ${_cleanNotes(log.notes!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (log.photoUrls != null && log.photoUrls!.isNotEmpty) ...[
                    SizedBox(height: 10),
                    _PhotoStrip(photoUrls: log.photoUrls!),
                  ],
                ],
              ),
            ),
            // ── Action buttons ──────────────────────────────────────
            if (_showActions()) _buildActions(context),
          ],
        ),
      ),
    );
  }

  bool get _canApproveThis {
    if (!canApprove) return false;
    final r = currentRole.toUpperCase();
    if (r == 'ADMIN' || r == 'MIS') return log.isAnyPending;
    if (r == 'KD' || r == 'KETUA_DIVISI') return log.isPendingKd;
    if (r == 'KEPALA_GUDANG' || r == 'ADMIN_GUDANG' || r == 'GUDANG') {
      return log.isPendingWh;
    }
    if (r == 'PPIC' || r == 'PPC') return log.isPendingPpic;
    return false;
  }

  bool _showActions() {
    return _canApproveThis ||
        _canReady ||
        _canLocate ||
        _canStore ||
        _canRelease ||
        _canInstall ||
        _canReturn ||
        _canRemindReturn ||
        _canMatchName;
  }

  Widget _buildActions(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_canApproveThis) ...[
          _actionBtn(
            context,
            'Tolak',
            Icons.cancel_outlined,
            AppColors.statusLocked,
            () => _doApproval(context, false),
            outlined: true,
          ),
          _actionBtn(
            context,
            'Setujui',
            Icons.check_circle_outline,
            AppColors.statusDone,
            () => _doApproval(context, true),
          ),
        ],
        if (_canMatchName)
          _actionBtn(
            context,
            'Koreksi Nama',
            Icons.edit_note_rounded,
            AppColors.gold,
            () => _doMatchName(context),
            outlined: true,
          ),
        if (_canReady)
          _actionBtn(
            context,
            'Tandai Siap',
            Icons.inventory_rounded,
            Color(0xFF13B8A6),
            () => _doReady(context),
          ),
        if (_canRelease)
          _actionBtn(
            context,
            _isOwner ? 'Ambil' : 'Sudah Diambil',
            Icons.north_east_rounded,
            Color(0xFF13B8A6),
            () => _doRelease(context),
          ),
        if (_canInstall)
          _actionBtn(
            context,
            'Install',
            Icons.build_circle_outlined,
            AppColors.gold,
            () => _doInstall(context),
          ),
        if (_canReturn)
          _actionBtn(
            context,
            'Kembalikan',
            Icons.assignment_return_outlined,
            AppColors.statusLocked,
            () => _doReturn(context),
            outlined: true,
          ),
        if (_canRemindReturn)
          _actionBtn(
            context,
            'Reminder',
            Icons.notifications_active_outlined,
            AppColors.gold,
            () => _doRemindReturn(context),
            outlined: true,
          ),
        if (_canStore)
          _actionBtn(
            context,
            'Masuk Gudang',
            Icons.archive_rounded,
            Color(0xFF5B8EFF),
            () => _doStore(context),
          ),
        if (_canLocate)
          _actionBtn(
            context,
            log.needsLocate ? 'Tentukan Lokasi' : 'Ubah Lokasi',
            Icons.place_outlined,
            Color(0xFF5B8EFF),
            () => _doLocate(context),
            outlined: !log.needsLocate,
          ),
      ],
    ),
  );

  Widget _chip(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }

  Widget _actionBtn(
    BuildContext ctx,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return outlined
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.6)),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          )
        : FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
  }

  // ─ action impl ───────────────────────────────────────────────
  Future<void> _doInstall(BuildContext ctx) async {
    try {
      await repo.installItem(logId: log.id);
      if (ctx.mounted) {
        AppNotification.showSuccess(
          ctx,
          '${log.itemName} berhasil ditandai terpasang',
        );
        onDone();
      }
    } catch (e) {
      if (ctx.mounted) {
        AppNotification.showError(
          ctx,
          friendlyMessage(e, fallback: 'Gagal install barang'),
        );
      }
    }
  }

  Future<void> _doReady(BuildContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseFlowSheet(
        title: 'Tandai Siap Diambil',
        subtitle: 'Simpan status dan kirim notifikasi ke peminjam.',
        actionLabel: 'Tandai Siap',
        accentColor: Color(0xFF13B8A6),
        icon: Icons.inventory_rounded,
        showLocationPicker: true,
        repo: repo,
        onSubmit: ({notes, storageLocationId, locationDetail, photoUrls}) {
          return repo.markReady(
            logId: log.id,
            notes: notes,
            storageLocationId: storageLocationId,
            locationDetail: locationDetail,
            photoUrls: photoUrls,
          );
        },
      ),
    );
    if (ok == true && ctx.mounted) onDone();
  }

  Future<void> _doRelease(BuildContext ctx) async {
    try {
      await repo.releaseItem(logId: log.id);
      if (ctx.mounted) {
        AppNotification.showSuccess(
          ctx,
          '${log.itemName} sudah ditandai diambil',
        );
        onDone();
      }
    } catch (e) {
      if (ctx.mounted) {
        AppNotification.showError(
          ctx,
          friendlyMessage(e, fallback: 'Gagal konfirmasi pengambilan'),
        );
      }
    }
  }

  Future<void> _doReturn(BuildContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReturnSheet(log: log, repo: repo),
    );
    if (ok == true && ctx.mounted) onDone();
  }

  Future<void> _doMatchName(BuildContext context) async {
    final selectedItem = await showDialog<WarehouseItemSuggestion>(
      context: context,
      builder: (ctx) => _MatchNameDialog(log: log),
    );

    if (selectedItem != null) {
      if (!context.mounted) return;
      try {
        await repo.matchItem(
          logId: log.id,
          masterId: selectedItem.id,
          masterName: selectedItem.itemName,
        );
        if (context.mounted) {
          AppNotification.showSuccess(
            context,
            'Nama barang berhasil dikoreksi.',
          );
          onDone();
        }
      } catch (e) {
        if (context.mounted) {
          AppNotification.showError(
            context,
            friendlyMessage(e, fallback: 'Gagal koreksi nama'),
          );
        }
      }
    }
  }

  Future<void> _doRemindReturn(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Kirim Reminder',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Kirim reminder pengembalian untuk ${log.requester}?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: Text('Kirim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repo.remindReturn(logId: log.id);
      if (ctx.mounted) {
        AppNotification.showSuccess(
          ctx,
          'Reminder terkirim ke ${log.requester}',
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        AppNotification.showError(
          ctx,
          friendlyMessage(e, fallback: 'Gagal kirim reminder'),
        );
      }
    }
  }

  Future<void> _doApproval(BuildContext ctx, bool approved) async {
    final ok = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApprovalSheet(log: log, repo: repo, approved: approved),
    );
    if (ok == true && ctx.mounted) onDone();
  }

  Future<void> _doStore(BuildContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseFlowSheet(
        title: 'Masuk Gudang',
        subtitle:
            'Simpan kembali barang yang sudah dikembalikan dan catat lokasinya.',
        actionLabel: 'Simpan',
        accentColor: Color(0xFF5B8EFF),
        icon: Icons.archive_rounded,
        showLocationPicker: true,
        repo: repo,
        onSubmit: ({notes, storageLocationId, locationDetail, photoUrls}) {
          return repo.storeItem(
            logId: log.id,
            notes: notes,
            storageLocationId: storageLocationId,
            locationDetail: locationDetail,
          );
        },
      ),
    );
    if (ok == true && ctx.mounted) onDone();
  }

  Future<void> _doLocate(BuildContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseFlowSheet(
        title: 'Tentukan Lokasi Rak',
        subtitle: 'Simpan lokasi final supaya part mudah ditemukan lagi.',
        actionLabel: log.needsLocate ? 'Simpan Lokasi' : 'Perbarui Lokasi',
        accentColor: Color(0xFF5B8EFF),
        icon: Icons.place_outlined,
        showLocationPicker: true,
        initialLocationDetail: log.locationDetail,
        repo: repo,
        onSubmit: ({notes, storageLocationId, locationDetail, photoUrls}) {
          return repo.locateItem(
            logId: log.id,
            notes: notes,
            storageLocationId: storageLocationId,
            locationDetail: locationDetail,
          );
        },
      ),
    );
    if (ok == true && ctx.mounted) onDone();
  }
}

class _MatchNameDialog extends StatefulWidget {
  const _MatchNameDialog({required this.log});

  final WarehouseLog log;

  @override
  State<_MatchNameDialog> createState() => _MatchNameDialogState();
}

class _MatchNameDialogState extends State<_MatchNameDialog> {
  late final TextEditingController _controller;
  WarehouseItemSuggestion? _selectedItem;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final currentAlias = log.itemAliasUsed ?? log.itemName;

    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      title: Text(
        'Koreksi Nama Barang',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.68,
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(text: 'Nama awal:\n'),
                      TextSpan(
                        text: currentAlias,
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentAlias.trim().isNotEmpty &&
                    currentAlias != log.itemName) ...[
                  SizedBox(height: 8),
                  Text(
                    'Nama master saat ini: ${log.itemName}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
                SizedBox(height: 16),
                Text(
                  'Pilih barang dari master:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                SizedBox(height: 8),
                WarehouseItemSearchField(
                  controller: _controller,
                  category: log.itemCategory,
                  hintText: 'Cari di gudang...',
                  onSelected: (item) {
                    setState(() => _selectedItem = item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
        ),
        FilledButton(
          onPressed: _selectedItem == null
              ? null
              : () => Navigator.of(context).pop(_selectedItem),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textMuted,
          ),
          child: Text('Simpan'),
        ),
      ],
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  const _LogDetailSheet({required this.log, this.footer});
  final WarehouseLog log;
  final Widget? footer;

  static final _df = DateFormat('EEEE, d MMMM yyyy HH:mm', 'id_ID');

  String _cleanNotes(String? n) {
    if (n == null) return '';
    final idx = n.indexOf('[APPROVAL_HISTORY]');
    if (idx != -1) n = n.substring(0, idx);
    return n
        .replaceAll('[INSTALL_TO_UNIT]', '')
        .replaceAll('[PENYIMPANAN]', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.itemName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ID Transaksi: #${log.id.split("-").first}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(),
            ],
          ),
          SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Informasi Barang'),
                  _detailRow(
                    Icons.swap_horiz_rounded,
                    'Tipe Transaksi',
                    _warehouseTrxLabel(log.transactionType),
                  ),
                  _detailRow(
                    Icons.category_outlined,
                    'Kategori',
                    _warehouseCategoryLabel(log.itemCategory),
                  ),
                  if ((log.itemAliasUsed ?? '').trim().isNotEmpty &&
                      log.itemAliasUsed != log.itemName)
                    _detailRow(
                      Icons.edit_note_outlined,
                      'Nama Diajukan',
                      log.itemAliasUsed!,
                      valueColor: AppColors.gold,
                    ),
                  _detailRow(
                    Icons.numbers_rounded,
                    'Jumlah',
                    '${log.qty % 1 == 0 ? log.qty.toInt() : log.qty} ${log.uom}',
                  ),
                  if (log.itemCondition != null)
                    _detailRow(
                      Icons.info_outline,
                      'Kondisi',
                      log.itemCondition!,
                      valueColor: log.itemCondition == 'GOOD'
                          ? AppColors.statusDone
                          : AppColors.statusLocked,
                    ),
                  SizedBox(height: 20),
                  _sectionHeader('Konteks Kerja'),
                  _detailRow(
                    Icons.person_outline_rounded,
                    'Pemohon',
                    log.requester,
                  ),
                  _detailRow(Icons.business_outlined, 'Divisi', log.division),
                  if (log.unitName != null)
                    _detailRow(
                      Icons.directions_car_outlined,
                      'Unit Mobil',
                      log.unitName!,
                    ),
                  if (log.jobdesc != null)
                    _detailRow(
                      Icons.assignment_outlined,
                      'Pekerjaan',
                      log.jobdesc!,
                    ),
                  SizedBox(height: 20),
                  _sectionHeader('Waktu & Lokasi'),
                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Tgl Pengajuan',
                    _df.format(log.requestDate),
                  ),
                  if (log.actualReleaseDate != null)
                    _detailRow(
                      Icons.north_east_rounded,
                      'Tgl Keluar',
                      _df.format(log.actualReleaseDate!),
                    ),
                  if (log.actualReturnDate != null)
                    _detailRow(
                      Icons.assignment_return_outlined,
                      'Tgl Kembali',
                      _df.format(log.actualReturnDate!),
                    ),
                  if (log.locationDetail != null)
                    _detailRow(
                      Icons.place_outlined,
                      'Lokasi Simpan',
                      log.locationDetail!,
                      valueColor: Color(0xFF5B8EFF),
                    ),
                  if (_cleanNotes(log.notes).isNotEmpty) ...[
                    SizedBox(height: 20),
                    _sectionHeader('Catatan Tambahan'),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        _cleanNotes(log.notes),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (log.photoUrls != null && log.photoUrls!.isNotEmpty) ...[
                    SizedBox(height: 20),
                    _sectionHeader('Lampiran Foto'),
                    SizedBox(height: 8),
                    _PhotoStrip(photoUrls: log.photoUrls!),
                  ],
                  if (log.approvalHistory.isNotEmpty) ...[
                    SizedBox(height: 24),
                    _sectionHeader('Riwayat Persetujuan'),
                    SizedBox(height: 12),
                    _ApprovalTimeline(steps: log.approvalHistory),
                  ],
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (footer != null) ...[SizedBox(height: 8), footer!],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.gold,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: AppColors.textMuted),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        log.displayStatus,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photoUrls});

  final List<String> photoUrls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoUrls.length > 3 ? 3 : photoUrls.length,
        separatorBuilder: (context, index) => SizedBox(width: 8),
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            photoUrls[index],
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 76,
              height: 76,
              color: AppColors.background,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalTimeline extends StatelessWidget {
  const _ApprovalTimeline({required this.steps});

  final List<WarehouseApprovalStep> steps;

  static final _dtf = DateFormat('d MMM, HH:mm', 'id_ID');

  String _label(String stage) {
    switch (stage) {
      case 'PENDING_KD':
        return 'Ketua Divisi';
      case 'PENDING_KEPALA_GUDANG':
        return 'Kepala Gudang';
      case 'PENDING_PPIC':
        return 'PPIC';
      default:
        return stage.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Riwayat Persetujuan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 10),
          ...steps.map((step) {
            final approved = step.action.toUpperCase() == 'APPROVED';
            final color = approved
                ? AppColors.statusDone
                : AppColors.statusLocked;
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      approved ? Icons.check_rounded : Icons.close_rounded,
                      size: 14,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_label(step.stage)} · ${approved ? "Disetujui" : "Ditolak"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (step.name?.isNotEmpty == true ||
                            step.timestamp != null)
                          Text(
                            [
                              if (step.name?.isNotEmpty == true) step.name!,
                              if (step.timestamp != null)
                                _dtf.format(step.timestamp!),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (step.notes?.trim().isNotEmpty == true)
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              step.notes!.trim(),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

typedef _WarehouseSheetSubmit =
    Future<void> Function({
      String? notes,
      int? storageLocationId,
      String? locationDetail,
      List<String>? photoUrls,
    });

class _WarehouseFlowSheet extends StatefulWidget {
  const _WarehouseFlowSheet({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.accentColor,
    required this.icon,
    required this.repo,
    required this.onSubmit,
    this.showLocationPicker = false,
    this.initialLocationDetail,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Color accentColor;
  final IconData icon;
  final WarehouseRepository repo;
  final _WarehouseSheetSubmit onSubmit;
  final bool showLocationPicker;
  final String? initialLocationDetail;

  @override
  State<_WarehouseFlowSheet> createState() => _WarehouseFlowSheetState();
}

class _WarehouseFlowSheetState extends State<_WarehouseFlowSheet> {
  final _notesCtrl = TextEditingController();
  final _locationDetailCtrl = TextEditingController();
  List<Map<String, dynamic>> _locations = [];
  int? _storageLocationId;
  bool _isLoadingLocations = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _locationDetailCtrl.text = widget.initialLocationDetail ?? '';
    if (widget.showLocationPicker) {
      _loadLocations();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _locationDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final items = await widget.repo.getStorageLocations();
      if (!mounted) return;
      setState(() => _locations = items);
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.accentColor,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.subtitle,
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
              if (widget.showLocationPicker) ...[
                SizedBox(height: 18),
                Text(
                  'Lokasi Penyimpanan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 8),
                if (_isLoadingLocations)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _storageLocationId,
                    dropdownColor: AppColors.surfaceCard,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Pilih lokasi penyimpanan',
                    ),
                    items: _locations.map((location) {
                      return DropdownMenuItem<int>(
                        value: (location['id'] as num?)?.toInt(),
                        child: Text('${location['label'] ?? '-'}'),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _storageLocationId = value),
                  ),
                SizedBox(height: 12),
                TextField(
                  controller: _locationDetailCtrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Detail lokasi (opsional)',
                    prefixIcon: Icon(
                      Icons.place_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Catatan (opsional)',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(widget.icon),
                label: Text(
                  _isSaving ? 'Menyimpan...' : widget.actionLabel,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        storageLocationId: _storageLocationId,
        locationDetail: _locationDetailCtrl.text.trim().isEmpty
            ? null
            : _locationDetailCtrl.text.trim(),
        photoUrls: null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppNotification.showSuccess(context, 'Perubahan berhasil disimpan.');
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal menyimpan perubahan'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ApprovalSheet extends StatefulWidget {
  const _ApprovalSheet({
    required this.log,
    required this.repo,
    required this.approved,
  });

  final WarehouseLog log;
  final WarehouseRepository repo;
  final bool approved;

  @override
  State<_ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends State<_ApprovalSheet> {
  final _notesCtrl = TextEditingController();
  final _locationDetailCtrl = TextEditingController();

  List<Map<String, dynamic>> _locations = [];
  int? _storageLocationId;
  bool _isLoadingLocations = false;
  bool _isSaving = false;

  bool get _needsStorageLocation => widget.approved && widget.log.isPenyimpanan;

  @override
  void initState() {
    super.initState();
    if (_needsStorageLocation) _loadLocations();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _locationDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final items = await widget.repo.getStorageLocations();
      if (!mounted) return;
      setState(() => _locations = items);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              SizedBox(height: 16),
              Text(
                widget.approved ? 'Persetujuan Barang' : 'Tolak Pengajuan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                widget.log.itemName,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              SizedBox(height: 16),
              _summaryRow(
                Icons.swap_horiz_rounded,
                '${_warehouseTrxLabel(widget.log.transactionType)} · ${_warehouseCategoryLabel(widget.log.itemCategory)}',
              ),
              _summaryRow(
                Icons.numbers_outlined,
                '${widget.log.qty % 1 == 0 ? widget.log.qty.toInt() : widget.log.qty} ${widget.log.uom}',
              ),
              if (widget.log.unitName != null)
                _summaryRow(
                  Icons.directions_car_outlined,
                  widget.log.unitName!,
                ),
              if (widget.log.itemCondition != null)
                _summaryRow(
                  Icons.info_outline,
                  'Kondisi: ${widget.log.itemCondition!}',
                ),
              if (widget.log.photoUrls != null &&
                  widget.log.photoUrls!.isNotEmpty) ...[
                SizedBox(height: 14),
                _PhotoStrip(photoUrls: widget.log.photoUrls!),
              ],
              if (_needsStorageLocation) ...[
                SizedBox(height: 16),
                Text(
                  'Lokasi Simpan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 8),
                if (_isLoadingLocations)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _storageLocationId,
                    dropdownColor: AppColors.surfaceCard,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Pilih rak / lokasi gudang',
                    ),
                    items: _locations.map((location) {
                      return DropdownMenuItem<int>(
                        value: (location['id'] as num?)?.toInt(),
                        child: Text('${location['label'] ?? '-'}'),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _storageLocationId = value),
                  ),
                SizedBox(height: 12),
                TextField(
                  controller: _locationDetailCtrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Detail tambahan lokasi (opsional)',
                    prefixIcon: Icon(
                      Icons.place_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.approved
                      ? 'Catatan persetujuan (opsional)'
                      : 'Alasan penolakan (opsional)',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.approved
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                      ),
                label: Text(
                  _isSaving
                      ? 'Menyimpan...'
                      : widget.approved
                      ? 'Setujui'
                      : 'Tolak',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.approved
                      ? AppColors.statusDone
                      : AppColors.statusLocked,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await widget.repo.setApprovalStatus(
        logId: widget.log.id,
        approved: widget.approved,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        storageLocationId: _storageLocationId,
        locationDetail: _locationDetailCtrl.text.trim().isNotEmpty
            ? _locationDetailCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppNotification.showSuccess(
        context,
        widget.approved
            ? '${widget.log.itemName} disetujui'
            : '${widget.log.itemName} ditolak',
      );
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal memproses persetujuan'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// RETURN SHEET
// ═══════════════════════════════════════════════════════════════
class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({required this.log, required this.repo});
  final WarehouseLog log;
  final WarehouseRepository repo;

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  final _notesCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String _condition = 'GOOD';
  bool _isSaving = false;

  bool get _isBahan =>
      widget.log.itemCategory == 'BAHAN' ||
      widget.log.itemCategory == 'CONSUMABLE';

  @override
  void dispose() {
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          SizedBox(height: 16),
          Text(
            'Kembalikan Barang',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            widget.log.itemName,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          SizedBox(height: 20),
          if (!_isBahan) ...[
            Text(
              'Kondisi Barang',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 8),
            _conditionRow(),
            SizedBox(height: 14),
          ] else ...[
            Text(
              'Qty Sisa (dikembalikan)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Qty asli: ${widget.log.qty} ${widget.log.uom}',
                prefixIcon: Icon(
                  Icons.numbers_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
            SizedBox(height: 14),
          ],
          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 3,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Catatan pengembalian (opsional)',
              prefixIcon: Icon(
                Icons.notes_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
            ),
          ),
          SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _submit,
            icon: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.assignment_return_outlined, size: 18),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Konfirmasi Pengembalian',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _conditionRow() {
    final opts = ['GOOD', 'DAMAGED', 'SCRAP'];
    final labels = ['Baik', 'Rusak', 'Scrap'];
    final colors = [
      AppColors.statusDone,
      AppColors.statusInProgress,
      AppColors.statusLocked,
    ];
    return Row(
      children: List.generate(3, (i) {
        final active = _condition == opts[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _condition = opts[i]),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? colors[i].withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? colors[i] : AppColors.border,
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? colors[i] : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      double? qty;
      if (_isBahan && _qtyCtrl.text.trim().isNotEmpty) {
        qty = double.tryParse(_qtyCtrl.text.trim());
      }
      await widget.repo.returnItem(
        logId: widget.log.id,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        itemCondition: _isBahan ? null : _condition,
        qtyReturned: qty,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        AppNotification.showSuccess(
          context,
          '${widget.log.itemName} berhasil dikembalikan',
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal mengembalikan barang'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
