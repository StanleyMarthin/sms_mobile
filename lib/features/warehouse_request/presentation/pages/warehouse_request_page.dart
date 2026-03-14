import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/warehouse_log.dart';
import '../../domain/repositories/warehouse_repository.dart';

/// Peminjaman / Pengembalian page for Lapangan (field worker).
///
/// Displays a list of tool & material requests (borrowed items) and
/// allows the mechanic to:
/// - View current borrowed items
/// - Request new tools/spare parts (POST /warehouse/req)
/// - Return items
///
/// MVP uses dummy data; production will call warehouse endpoints.
class WarehouseRequestPage extends StatefulWidget {
  const WarehouseRequestPage({super.key});

  @override
  State<WarehouseRequestPage> createState() => _WarehouseRequestPageState();
}

class _WarehouseRequestPageState extends State<WarehouseRequestPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final SessionManager _session;
  late final WarehouseRepository _repository;
  List<WarehouseLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _session = sl<SessionManager>();
    _repository = sl<WarehouseRepository>();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final logs = await _repository.getLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  bool get _canRequest => _session.role == 'op';
  bool get _canApprove => _session.role == 'kd';

    List<WarehouseLog> get _myActiveLogs => _logs.where((log) {
      return log.requester == (_session.fullName ?? '-') &&
      log.itemStatus != 'RETURNED' &&
      log.approvalStatus != 'REJECTED';
      }).toList();

    List<WarehouseLog> get _myHistoryLogs => _logs.where((log) {
      return log.requester == (_session.fullName ?? '-') &&
      (log.itemStatus == 'RETURNED' || log.approvalStatus == 'REJECTED');
      }).toList();

    List<WarehouseLog> get _pendingApprovals => _logs.where((log) {
      return log.division == (_session.divisionName ?? '') &&
      log.approvalStatus == 'PENDING_KD';
      }).toList();

    List<WarehouseLog> get _divisionLogs => _logs.where((log) {
      return log.division == (_session.divisionName ?? '');
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab Bar ──────────────────────────────────────────
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
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            dividerHeight: 0,
            tabs: [
              Tab(text: _canRequest ? 'Transaksi Saya' : 'Approval KD'),
              Tab(text: _canRequest ? 'Riwayat' : 'Logs Divisi'),
            ],
          ),
        ),

        // ── Tab Body ─────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPrimaryTab(),
                    _buildSecondaryTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPrimaryTab() {
    final items = _canRequest ? _myActiveLogs : _pendingApprovals;
    return Stack(
      children: [
        if (items.isEmpty)
          Center(
            child: Text(
              _canRequest ? 'Tidak ada transaksi aktif' : 'Tidak ada approval menunggu',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildLoanCard(items[i]),
          ),
        if (_canRequest)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'warehouse_fab',
              onPressed: () => _showRequestSheet(context),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Transaksi',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryTab() {
    final items = _canRequest ? _myHistoryLogs : _divisionLogs;
    if (items.isEmpty) {
      return const Center(
        child: Text('Belum ada data', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildLoanCard(items[i]),
    );
  }

  Widget _buildLoanCard(WarehouseLog loan) {
    final itemStatus = loan.itemStatus;
    final approvalStatus = loan.approvalStatus;
    final isPending = approvalStatus == 'PENDING_KD';
    final isReturned = itemStatus == 'RETURNED';
    final df = DateFormat('d MMM yyyy', 'id_ID');

    Color statusColor;
    IconData statusIcon;
    if (isPending) {
      statusColor = AppColors.statusInProgress;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isReturned) {
      statusColor = AppColors.statusDone;
      statusIcon = Icons.check_circle_outline;
    } else {
      statusColor = AppColors.gold;
      statusIcon = Icons.inventory_2_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${loan.transactionType} • ${loan.itemCategory} • Qty: ${loan.qty} ${loan.uom}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending ? approvalStatus : itemStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Date info
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Request: ${df.format(loan.requestDate)}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              if (loan.returnDate != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.event_available_outlined,
                    size: 13, color: AppColors.statusDone),
                const SizedBox(width: 4),
                Text(
                  'Kembali: ${df.format(loan.returnDate!)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.statusDone),
                ),
              ],
            ],
          ),

          // Return button
          const SizedBox(height: 8),
          Text(
            'Requester: ${loan.requester} • Divisi ${loan.division}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (loan.notes != null && loan.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Catatan: ${loan.notes}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (_canRequest && !isPending && !isReturned) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReturn(context, loan),
                icon:
                    const Icon(Icons.assignment_return_outlined, size: 16),
                label: const Text('Kembalikan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (_canApprove && isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setApprovalStatus(context, loan, approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusLocked,
                      side: const BorderSide(color: AppColors.statusLocked),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _setApprovalStatus(context, loan, approved: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.statusDone,
                      foregroundColor: AppColors.background,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Request Sheet ─────────────────────────────────────────
  void _showRequestSheet(BuildContext context) {
    String selectedType = 'TOOLS';
    String transactionType = 'PEMINJAMAN';
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
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
              const Text(
                'Ajukan Peminjaman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Type toggle
              Row(
                children: [
                  _typeChip('TOOLS', 'Tools', selectedType, (v) {
                    setSheetState(() => selectedType = v);
                  }),
                  const SizedBox(width: 10),
                  _typeChip('SPARE_PART', 'Part/Bahan', selectedType, (v) {
                    setSheetState(() => selectedType = v);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _typeChip('PEMINJAMAN', 'Pinjam', transactionType, (v) {
                    setSheetState(() => transactionType = v);
                  }),
                  const SizedBox(width: 10),
                  _typeChip('PENGAMBILAN', 'Ambil', transactionType, (v) {
                    setSheetState(() => transactionType = v);
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Item name
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                  hintText: 'cth: Spray Gun HVLP',
                  prefixIcon:
                      Icon(Icons.inventory_outlined, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),

              // Quantity
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  prefixIcon: Icon(Icons.numbers_outlined,
                      color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                minLines: 2,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  prefixIcon: Icon(Icons.notes_outlined, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final needsApproval = selectedType != 'TOOLS';
                  await _repository.createTransaction(
                    transactionType: transactionType,
                    itemCategory: selectedType,
                    itemName: nameCtrl.text.trim(),
                    qty: int.tryParse(qtyCtrl.text) ?? 1,
                    requester: _session.fullName ?? '-',
                    division: _session.divisionName ?? '-',
                    divisionId: _session.divisionId ?? 0,
                    employeeId: _session.userId ?? '-',
                    notes: notesCtrl.text.trim(),
                  );
                  if (!context.mounted) return;
                  setState(() => _isLoading = true);
                  await _loadLogs();
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(needsApproval
                          ? 'Request ${nameCtrl.text.trim()} menunggu persetujuan KD'
                          : '${nameCtrl.text.trim()} langsung masuk transaksi aktif'),
                      backgroundColor: AppColors.surfaceCard,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Ajukan',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(
      String value, String label, String selected, ValueChanged<String> onTap) {
    final isActive = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.gold.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.gold
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppColors.gold : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Confirm Return ────────────────────────────────────────
  void _confirmReturn(BuildContext context, WarehouseLog loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Kembalikan Barang?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(
          'Kembalikan ${loan.itemName}?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repository.returnItem(logId: loan.id);
              if (!context.mounted) return;
              setState(() => _isLoading = true);
              await _loadLogs();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${loan.itemName} berhasil dikembalikan'),
                  backgroundColor: AppColors.surfaceCard,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Kembalikan'),
          ),
        ],
      ),
    );
  }

  Future<void> _setApprovalStatus(BuildContext context, WarehouseLog loan,
      {required bool approved}) async {
    await _repository.setApprovalStatus(logId: loan.id, approved: approved);
    if (!context.mounted) return;
    setState(() => _isLoading = true);
    await _loadLogs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approved
            ? '${loan.itemName} disetujui KD'
            : '${loan.itemName} ditolak KD'),
        backgroundColor: AppColors.surfaceCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
