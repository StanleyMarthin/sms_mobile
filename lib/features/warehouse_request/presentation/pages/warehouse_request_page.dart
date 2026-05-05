import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';
import '../../domain/entities/warehouse_log.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../widgets/active_job_picker.dart';
import '../widgets/warehouse_request_sheet.dart';

class WarehouseRequestPage extends StatefulWidget {
  const WarehouseRequestPage({super.key});

  @override
  State<WarehouseRequestPage> createState() => _WarehouseRequestPageState();
}

String _warehouseTrxLabel(String t) =>
    const {
      'PEMINJAMAN': 'Peminjaman',
      'PENGAMBILAN': 'Pengambilan',
      'PENGEMBALIAN': 'Pengembalian',
      'PENYIMPANAN': 'Penyimpanan',
    }[t] ??
    t;

String _warehouseCategoryLabel(String t) =>
    const {
      'TOOLS': 'Tools',
      'BAHAN': 'Bahan',
      'SPARE_PART': 'Spare Part',
      'CONSUMABLE': 'Consumable',
    }[t] ??
    t;

class _WarehouseRequestPageState extends State<WarehouseRequestPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final SessionManager _session;
  late final WarehouseRepository _repo;

  List<WarehouseLog> _myLogs = [];
  List<WarehouseLog> _myItems = [];
  List<WarehouseLog> _pendingList = [];
  DateTime _logsDateFilter = DateTime.now();
  DateTime _historyDateFilter = DateTime.now();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _session = sl<SessionManager>();
    _repo = sl<WarehouseRepository>();
    _tabController = TabController(length: _isApprover ? 2 : 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── role helpers ──────────────────────────────────────────────
  String get _role => (_session.role ?? '').toUpperCase();
  bool get _isApprover =>
      hasPermission(_session.role, Permission.warehouseApprove);
  bool get _isWh => {'KEPALA_GUDANG', 'ADMIN'}.contains(_role);

  // ── load ──────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<List<WarehouseLog>>([
        _repo.getLogs(),
        if (_isApprover) _repo.getPendingApprovals(),
        if (!_isApprover) _repo.getMyItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _myLogs = results[0];
        if (_isApprover) {
          _pendingList = results[1];
        } else {
          _myItems = results[1];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.showError(context, 'Gagal memuat data: $e');
      }
    }
  }

  List<WarehouseLog> get _activeItems => _myLogs
      .where((l) => !l.isReturned && !l.isRejected && !l.isStored)
      .toList();

  List<WarehouseLog> get _historyItems =>
      _myLogs.where((l) => l.isReturned || l.isRejected || l.isStored).toList();

  List<WarehouseLog> get _filteredHistoryItems {
    return _historyItems
        .where((item) => _sameDate(item.requestDate, _historyDateFilter))
        .toList();
  }

  List<WarehouseLog> get _filteredLogItems {
    return _myLogs
        .where((item) => _sameDate(item.requestDate, _logsDateFilter))
        .toList();
  }

  // ── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tabs = _isApprover
        ? ['Perlu Persetujuan', 'Semua Aktivitas']
        : ['Berjalan', 'Barang Saya', 'Riwayat'];

    return Column(children: [
      // Tab bar
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          dividerHeight: 0,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      Expanded(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : TabBarView(
                controller: _tabController,
                children: _isApprover
                    ? [_pendingTab(), _logsTab()]
                    : [_activeTab(), _myItemsTab(), _historyTab()],
              ),
      ),
    ]);
  }

  // ─ Tabs for OP ───────────────────────────────────────────────
  Widget _activeTab() => _listScaffold(
        items: _activeItems,
        emptyMsg: 'Tidak ada transaksi aktif',
        fab: FloatingActionButton.extended(
          heroTag: 'wh_fab_req',
          onPressed: () async {
            final ctx = await ActiveJobPicker.show(context);
            if (!mounted) return;
            final ok = await WarehouseRequestSheet.show(
                context: context, jobContext: ctx);
            if (ok && mounted) _loadAll();
          },
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.background,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Ajukan',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  Widget _myItemsTab() => _listScaffold(
        items: _myItems,
        emptyMsg: 'Tidak ada barang yang sedang Anda pegang',
        fab: FloatingActionButton.extended(
          heroTag: 'wh_fab_store',
          onPressed: () async {
            if (await WarehouseStorageSheet.show(context: context)) _loadAll();
          },
          backgroundColor: const Color(0xFF5B8EFF),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.archive_outlined, size: 20),
          label: const Text('Simpan Barang',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  // ─ Tabs for approvers ────────────────────────────────────────
  Widget _pendingTab() => _listScaffold(
      items: _pendingList,
      emptyMsg: 'Tidak ada aktivitas yang menunggu persetujuan');

  Widget _logsTab() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DateFilterBar(
              selectedDate: _logsDateFilter,
              onDateChanged: (date) {
                setState(() => _logsDateFilter = date);
              },
              label: 'Filter',
            ),
          ),
          Expanded(
            child: _listScaffold(
              items: _filteredLogItems,
              emptyMsg: 'Tidak ada aktivitas pada tanggal ini',
            ),
          ),
        ],
      );

  Widget _historyTab() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DateFilterBar(
              selectedDate: _historyDateFilter,
              onDateChanged: (date) {
                setState(() => _historyDateFilter = date);
              },
              label: 'Filter',
            ),
          ),
          Expanded(
            child: _listScaffold(
              items: _filteredHistoryItems,
              emptyMsg: 'Tidak ada riwayat pada tanggal ini',
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
    return Stack(children: [
      RefreshIndicator(
        color: AppColors.gold,
        onRefresh: _loadAll,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                  _EmptyState(message: emptyMsg),
                  const SizedBox(height: 12),
                ],
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 12, 16, fab != null ? 88 : 24),
                itemCount: items.length,
                itemBuilder: (_, i) => _LogCard(
                  log: items[i],
                  isApprover: _isApprover,
                  isWh: _isWh,
                  currentRole: _session.role ?? '',
                  currentUserId: _session.userId ?? _session.employeeId ?? '',
                  repo: _repo,
                  onDone: _loadAll,
                ),
              ),
      ),
      if (fab != null) Positioned(right: 16, bottom: 24, child: fab),
    ]);
  }

  Widget _dateFilterBar({
    required DateTime? selectedDate,
    required VoidCallback onPick,
    required VoidCallback onReset,
  }) {
    final label = selectedDate == null
        ? 'Semua tanggal'
        : DateFormat('d MMM yyyy', 'id_ID').format(selectedDate);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selectedDate != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(color: AppColors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Reset',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickLogsDate() async {
    final picked = await _showFilterDatePicker(_logsDateFilter);
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _logsDateFilter = picked);
  }

  Future<void> _pickHistoryDate() async {
    final picked = await _showFilterDatePicker(_historyDateFilter);
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _historyDateFilter = picked);
  }

  Future<DateTime?> _showFilterDatePicker(DateTime? selectedDate) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.surfaceCard,
          ),
        ),
        child: child!,
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 28),
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
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 26,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

// ═══════════════════════════════════════════════════════════════
// LOG CARD
// ═══════════════════════════════════════════════════════════════
class _LogCard extends StatelessWidget {
  const _LogCard({
    required this.log,
    required this.isApprover,
    required this.isWh,
    required this.currentRole,
    required this.currentUserId,
    required this.repo,
    required this.onDone,
  });

  final WarehouseLog log;
  final bool isApprover;
  final bool isWh;
  final String currentRole;
  final String currentUserId;
  final WarehouseRepository repo;
  final VoidCallback onDone;

  static final _df = DateFormat('d MMM yy', 'id_ID');
  bool get _isOwner =>
      currentUserId.isNotEmpty && log.employeeId == currentUserId;
  bool get _isPrivilegedReleaseRole =>
      {'KD', 'KEPALA_GUDANG', 'PPIC', 'ADMIN'}.contains(
        currentRole.toUpperCase(),
      );
  bool get _canReady =>
      isWh && log.isApproved && !log.isPenyimpanan && log.itemStatus == 'OPEN';
  bool get _canLocate => isWh && log.isPenyimpanan && log.isStored;
  bool get _canStore => isWh && log.itemCategory == 'TOOLS' && log.isReturned;
  bool get _canRelease => (_isPrivilegedReleaseRole || _isOwner) && log.isReady;
  bool get _canInstall => _isOwner && log.isReleased;
  bool get _canReturn => _isOwner && (log.isReleased || log.isInstalled);

  // status colours / icons ──────────────────────────────────────
  Color get _statusColor {
    if (log.isRejected) return AppColors.statusLocked;
    if (log.itemStatus == 'LOST') return const Color(0xFF111111);
    if (log.isStored) return const Color(0xFF5B8EFF);
    if (log.isReturned) return const Color(0xFF8B5CF6);
    if (log.isReady) return const Color(0xFF13B8A6);
    if (log.isAnyPending) return AppColors.statusInProgress;
    if (log.isReleased) return AppColors.statusDone;
    if (log.isApproved) return const Color(0xFF7C8799);
    if (log.itemStatus == 'OPEN') return AppColors.textMuted;
    return AppColors.textMuted;
  }

  IconData get _icon {
    if (log.isRejected) return Icons.cancel_outlined;
    if (log.itemStatus == 'LOST') return Icons.error_outline_rounded;
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
    if (_canReady) return 'Siapkan Barang';
    if (log.isReady) return 'Siap Diambil';
    if (log.isStored) return 'Sudah Disimpan';
    if (log.isReturned) return 'Dikembalikan';
    if (log.isReleased) return 'Sudah Diambil';
    if (log.isApproved) return 'Menunggu Gudang';
    if (log.itemStatus == 'LOST') return 'Hilang';
    return 'Menunggu';
  }

  String _cleanNotes(String n) => n
      .replaceAll('[INSTALL_TO_UNIT]', '')
      .replaceAll('[PENYIMPANAN]', '')
      .trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: log.isAnyPending
              ? _statusColor.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────
        Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_icon, size: 18, color: _statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.itemName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${_warehouseTrxLabel(log.transactionType)} · ${_warehouseCategoryLabel(log.itemCategory)} · '
                        '${log.qty % 1 == 0 ? log.qty.toInt() : log.qty} ${log.uom}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  )),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_badge,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                            letterSpacing: 0.2)),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  if (log.unitName != null)
                    _chip(Icons.directions_car_outlined, log.unitName!),
                  _chip(Icons.person_outline_rounded, log.requester),
                  _chip(Icons.business_outlined, log.division),
                  _chip(Icons.calendar_today_outlined,
                      _df.format(log.requestDate)),
                  if (log.isReady)
                    _chip(Icons.notifications_active_outlined,
                        'Menunggu pengambilan',
                        color: const Color(0xFF13B8A6)),
                  if (log.actualReleaseDate != null)
                    _chip(Icons.check_circle_outline,
                        'Keluar: ${_df.format(log.actualReleaseDate!)}',
                        color: AppColors.statusDone),
                  if (log.actualReturnDate != null)
                    _chip(Icons.assignment_return_outlined,
                        'Kembali: ${_df.format(log.actualReturnDate!)}',
                        color: AppColors.statusDone),
                  if (log.itemCondition != null)
                    _chip(Icons.info_outline, 'Kondisi: ${log.itemCondition}',
                        color: log.itemCondition == 'GOOD'
                            ? AppColors.statusDone
                            : AppColors.statusLocked),
                  if (log.locationDetail?.isNotEmpty ?? false)
                    _chip(Icons.place_outlined, log.locationDetail!,
                        color: const Color(0xFF5B8EFF)),
                ]),
                if (log.notes != null &&
                    _cleanNotes(log.notes!).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Catatan: ${_cleanNotes(log.notes!)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (log.photoUrls != null && log.photoUrls!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PhotoStrip(photoUrls: log.photoUrls!),
                ],
                if (log.approvalHistory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ApprovalTimeline(steps: log.approvalHistory),
                ],
              ],
            )),
        // ── Action buttons ──────────────────────────────────────
        if (_showActions(isApprover)) _buildActions(context),
      ]),
    );
  }

  bool get _canApproveThis {
    if (!isApprover) return false;
    final r = currentRole.toUpperCase();
    if (r == 'ADMIN' || r == 'MIS') return log.isAnyPending;
    if (r == 'KD' || r == 'KETUA_DIVISI') return log.isPendingKd;
    if (r == 'KEPALA_GUDANG' || r == 'ADMIN_GUDANG' || r == 'GUDANG') return log.isPendingWh;
    if (r == 'PPIC' || r == 'PPC') return log.isPendingPpic;
    return false;
  }

  bool _showActions(bool approver) {
    return _canApproveThis ||
        _canReady ||
        _canLocate ||
        _canStore ||
        _canRelease ||
        _canInstall ||
        _canReturn;
  }

  Widget _buildActions(BuildContext context) => Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
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
            if (_canReady)
              _actionBtn(
                context,
                'Siapkan',
                Icons.inventory_rounded,
                const Color(0xFF13B8A6),
                () => _doReady(context),
              ),
            if (_canRelease)
              _actionBtn(
                context,
                'Konfirmasi Ambil',
                Icons.north_east_rounded,
                const Color(0xFF13B8A6),
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
            if (_canStore)
              _actionBtn(
                context,
                'Simpan Lagi',
                Icons.archive_rounded,
                const Color(0xFF5B8EFF),
                () => _doStore(context),
              ),
            if (_canLocate)
              _actionBtn(
                context,
                log.needsLocate ? 'Tentukan Lokasi' : 'Ubah Lokasi',
                Icons.place_outlined,
                const Color(0xFF5B8EFF),
                () => _doLocate(context),
                outlined: !log.needsLocate,
              ),
          ],
        ),
      );

  Widget _chip(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.textMuted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: c)),
    ]);
  }

  Widget _actionBtn(BuildContext ctx, String label, IconData icon, Color color,
      VoidCallback onTap,
      {bool outlined = false}) {
    return outlined
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          )
        : FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
  }

  // ─ action impl ───────────────────────────────────────────────
  Future<void> _doInstall(BuildContext ctx) async {
    try {
      await repo.installItem(logId: log.id);
      if (ctx.mounted) {
        AppNotification.showSuccess(
            ctx, '${log.itemName} berhasil ditandai terpasang');
        onDone();
      }
    } catch (e) {
      if (ctx.mounted) AppNotification.showError(ctx, 'Gagal install: $e');
    }
  }

  Future<void> _doReady(BuildContext ctx) async {
    final ok = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseFlowSheet(
        title: 'Siapkan Barang',
        subtitle: 'Perbarui status barang dan lokasi penyimpanan bila perlu.',
        actionLabel: 'Simpan',
        accentColor: const Color(0xFF13B8A6),
        icon: Icons.inventory_rounded,
        showLocationPicker: true,
        enablePhotoCapture: true,
        photoSlot: 'warehouse_ready',
        photoLabel: 'Foto Barang Gudang',
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
          '${log.itemName} berhasil dikonfirmasi',
        );
        onDone();
      }
    } catch (e) {
      if (ctx.mounted) {
        AppNotification.showError(ctx, 'Gagal konfirmasi pengambilan: $e');
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
        title: 'Simpan Kembali Tools',
        subtitle: 'Perbarui lokasi bila tools sudah masuk kembali.',
        actionLabel: 'Simpan',
        accentColor: const Color(0xFF5B8EFF),
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
        accentColor: const Color(0xFF5B8EFF),
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
        separatorBuilder: (context, index) => const SizedBox(width: 8),
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
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.textMuted, size: 20),
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
        return 'Gudang';
      case 'PENDING_PPIC':
        return 'PPIC';
      default:
        return stage.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Persetujuan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...steps.map((step) {
            final approved = step.action.toUpperCase() == 'APPROVED';
            final color =
                approved ? AppColors.statusDone : AppColors.statusLocked;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_label(step.stage)} · ${approved ? "Disetujui" : "Ditolak"}',
                          style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (step.notes?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              step.notes!.trim(),
                              style: const TextStyle(
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

typedef _WarehouseSheetSubmit = Future<void> Function({
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
    this.enablePhotoCapture = false,
    this.photoSlot = 'warehouse',
    this.photoLabel = 'Ambil Foto',
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
  final bool enablePhotoCapture;
  final String photoSlot;
  final String photoLabel;
  final String? initialLocationDetail;

  @override
  State<_WarehouseFlowSheet> createState() => _WarehouseFlowSheetState();
}

class _WarehouseFlowSheetState extends State<_WarehouseFlowSheet> {
  final _notesCtrl = TextEditingController();
  final _locationDetailCtrl = TextEditingController();
  List<Map<String, dynamic>> _locations = [];
  final List<String> _photoPaths = [];
  final List<String> _photoUrls = [];
  int? _storageLocationId;
  bool _isLoadingLocations = false;
  bool _isUploadingPhoto = false;
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(widget.icon, size: 18, color: widget.accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
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
                const SizedBox(height: 18),
                const Text(
                  'Lokasi Penyimpanan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingLocations)
                  const Padding(
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    isExpanded: true,
                    decoration: const InputDecoration(
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
                const SizedBox(height: 12),
                TextField(
                  controller: _locationDetailCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Detail lokasi (opsional)',
                    prefixIcon: Icon(
                      Icons.place_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
              if (widget.enablePhotoCapture) ...[
                const SizedBox(height: 16),
                const Text(
                  'Foto Barang',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _photoPicker(),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 3,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Catatan (opsional)',
                  prefixIcon: Icon(
                    Icons.notes_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
        photoUrls: _photoUrls.isEmpty ? null : _photoUrls,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppNotification.showSuccess(context, 'Perubahan berhasil disimpan.');
    } catch (e) {
      if (mounted) AppNotification.showError(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _photoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isUploadingPhoto ? null : _captureAndUploadPhoto,
          icon: _isUploadingPhoto
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(
            _isUploadingPhoto ? 'Mengupload...' : 'Ambil Foto',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_photoPaths.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoPaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photoPaths[index]),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _photoPaths.removeAt(index);
                          _photoUrls.removeAt(index);
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _captureAndUploadPhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => InAppCameraPage(
          slot: widget.photoSlot,
          label: widget.photoLabel,
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || path == null) {
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final session = sl<SessionManager>();
      final photoUrl = await widget.repo.uploadPhoto(
        userId: session.userId ?? session.employeeId ?? '',
        filePath: path,
      );
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception('Upload foto gagal');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _photoPaths.add(path);
        _photoUrls.add(photoUrl);
      });
    } catch (e) {
      if (mounted) {
        AppNotification.showError(context, 'Upload foto gagal: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              const SizedBox(height: 16),
              Text(
                widget.approved ? 'Persetujuan Barang' : 'Tolak Pengajuan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.log.itemName,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              _summaryRow(Icons.swap_horiz_rounded,
                  '${_warehouseTrxLabel(widget.log.transactionType)} · ${_warehouseCategoryLabel(widget.log.itemCategory)}'),
              _summaryRow(Icons.numbers_outlined,
                  '${widget.log.qty % 1 == 0 ? widget.log.qty.toInt() : widget.log.qty} ${widget.log.uom}'),
              if (widget.log.unitName != null)
                _summaryRow(
                    Icons.directions_car_outlined, widget.log.unitName!),
              if (widget.log.itemCondition != null)
                _summaryRow(Icons.info_outline,
                    'Kondisi: ${widget.log.itemCondition!}'),
              if (widget.log.photoUrls != null &&
                  widget.log.photoUrls!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PhotoStrip(photoUrls: widget.log.photoUrls!),
              ],
              if (_needsStorageLocation) ...[
                const SizedBox(height: 16),
                const Text(
                  'Lokasi Simpan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingLocations)
                  const Padding(
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    isExpanded: true,
                    decoration: const InputDecoration(
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
                const SizedBox(height: 12),
                TextField(
                  controller: _locationDetailCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Detail tambahan lokasi (opsional)',
                    prefixIcon: Icon(Icons.place_outlined,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 3,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.approved
                      ? 'Catatan persetujuan (opsional)'
                      : 'Alasan penolakan (opsional)',
                  prefixIcon: const Icon(Icons.notes_outlined,
                      color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(widget.approved
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined),
                label: Text(
                  _isSaving
                      ? 'Menyimpan...'
                      : widget.approved
                          ? 'Setujui'
                          : 'Tolak',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.approved
                      ? AppColors.statusDone
                      : AppColors.statusLocked,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
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
      if (mounted) AppNotification.showError(context, 'Gagal: $e');
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
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Kembalikan Barang',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(widget.log.itemName,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 20),
              if (!_isBahan) ...[
                const Text('Kondisi Barang',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 8),
                _conditionRow(),
                const SizedBox(height: 14),
              ] else ...[
                const Text('Qty Sisa (dikembalikan)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Qty asli: ${widget.log.qty} ${widget.log.uom}',
                    prefixIcon: const Icon(Icons.numbers_outlined,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 3,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Catatan pengembalian (opsional)',
                  prefixIcon: Icon(Icons.notes_outlined,
                      color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.assignment_return_outlined, size: 18),
                label: Text(
                    _isSaving ? 'Menyimpan...' : 'Konfirmasi Pengembalian',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _conditionRow() {
    const opts = ['GOOD', 'DAMAGED', 'SCRAP'];
    const labels = ['Baik', 'Rusak', 'Scrap'];
    const colors = [
      AppColors.statusDone,
      AppColors.statusInProgress,
      AppColors.statusLocked
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
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? colors[i].withValues(alpha: 0.15)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? colors[i] : AppColors.border),
            ),
            child: Text(labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? colors[i] : AppColors.textMuted)),
          ),
        ),
      ));
    }));
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
        notes:
            _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        itemCondition: _isBahan ? null : _condition,
        qtyReturned: qty,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        AppNotification.showSuccess(
            context, '${widget.log.itemName} berhasil dikembalikan');
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(context, 'Gagal mengembalikan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
