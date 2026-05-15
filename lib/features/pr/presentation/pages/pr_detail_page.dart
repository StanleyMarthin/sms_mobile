// Halaman detail Purchase Request — mengikuti pola wo_detail_page.dart.
// Struktur: _ApprovalStatusBar + _HeaderCard + _ItemsSection + _ActionArea

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/datasources/remote_pr_datasource.dart';
import '../../data/models/pr_header.dart';
import '../../data/models/pr_item.dart';

class PrDetailPage extends StatefulWidget {
  final String reqId;
  const PrDetailPage({super.key, required this.reqId});
  @override
  State<PrDetailPage> createState() => _PrDetailPageState();
}

class _PrDetailPageState extends State<PrDetailPage> {
  late final RemotePrDataSource _ds;
  PRHeader? _header;
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _ds = RemotePrDataSource(apiClient: sl(), sessionManager: sl());
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final d = await _ds.getPrDetail(widget.reqId);
      if (mounted) setState(() => _header = d);
    } catch (e) {
      if (mounted) _snack('Gagal memuat PR: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.statusLocked : AppColors.statusDone,
      behavior: SnackBarBehavior.floating,
    ));
  }

  bool _canApprove() {
    final acc = _header?.accTracking;
    if (acc == null || acc == 'APPROVED') return false;
    final r = (sl<SessionManager>().role ?? '').toUpperCase();
    return switch (acc) {
      'PENDING_ADV' => r == 'ADV' || r == 'ADVISOR',
      'PENDING_KP'  => r == 'KP' || r == 'KEPALA_PRODUKSI',
      'PENDING_MP'  => r == 'MP' || r == 'PM' || r == 'MANAGER_PRODUKSI' || r == 'MANAGER_OPERATIONAL',
      'PENDING_PUR' => r == 'PUR' || r == 'ADMIN' || r == 'MIS',
      _ => false,
    };
  }

  Future<void> _approve() async {
    if (!await _confirmDialog('Setujui PR ini?')) return;
    setState(() => _isActing = true);
    try {
      await _ds.approvePr(widget.reqId);
      if (mounted) _snack('PR berhasil di-approve');
      _load();
    } catch (e) {
      if (mounted) _snack('Gagal approve: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    final notes = await _notesDialog('Alasan Penolakan');
    if (notes == null) return;
    setState(() => _isActing = true);
    try {
      await _ds.rejectPr(widget.reqId, notes: notes.isNotEmpty ? notes : null);
      if (mounted) _snack('PR ditolak');
      _load();
    } catch (e) {
      if (mounted) _snack('Gagal reject: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _finalizeItem(PRItem item) async {
    final route = await _routeDialog();
    if (route == null) return;
    setState(() => _isActing = true);
    try {
      await _ds.finalizeItem(reqId: widget.reqId, itemId: item.id, route: route);
      if (mounted) _snack('"${item.itemName}" berhasil difinalisasi');
      _load();
    } catch (e) {
      if (mounted) _snack('Gagal finalize: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────

  Future<bool> _confirmDialog(String msg) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Text(msg, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ya, Setujui', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ) ?? false;

  Future<String?> _notesDialog(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: TextField(
          controller: ctrl, maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tulis alasan penolakan...',
            hintStyle: const TextStyle(color: AppColors.textDisabled),
            filled: true, fillColor: AppColors.surfaceInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.statusLocked)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusLocked),
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('Tolak PR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<String?> _routeDialog() async =>
      showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('Finalisasi Item', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          content: const Text('Kirim barang ini ke mana setelah tiba?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold, side: const BorderSide(color: AppColors.gold)),
              onPressed: () => Navigator.pop(c, 'TO_JOBDESC'),
              icon: const Icon(Icons.engineering_outlined, size: 16),
              label: const Text('Job Desc'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.background),
              onPressed: () => Navigator.pop(c, 'TO_WAREHOUSE'),
              icon: const Icon(Icons.warehouse_outlined, size: 16),
              label: const Text('Warehouse'),
            ),
          ],
        ),
      );

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textMuted),
        title: Text(
          _header?.prNumber ?? 'Detail PR',
          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        actions: [
          if (_header != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
              onPressed: _load,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _header == null
              ? const Center(child: Text('PR tidak ditemukan', style: TextStyle(color: AppColors.textMuted)))
              : Stack(children: [
                  RefreshIndicator(
                    onRefresh: _load, color: AppColors.gold,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      children: [
                        _ApprovalStatusBar(accTracking: _header!.accTracking),
                        const SizedBox(height: 16),
                        _HeaderCard(header: _header!),
                        const SizedBox(height: 16),
                        _ItemsSection(
                          header: _header!,
                          isActing: _isActing,
                          onFinalize: _finalizeItem,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  if (_canApprove()) _ActionArea(
                    isActing: _isActing,
                    onApprove: _approve,
                    onReject: _reject,
                  ),
                  if (_isActing)
                    Container(color: Colors.black54,
                      child: const Center(child: CircularProgressIndicator(color: AppColors.gold))),
                ]),
    );
  }
}

// ── Approval Status Bar ────────────────────────────────────────

class _ApprovalStatusBar extends StatelessWidget {
  const _ApprovalStatusBar({required this.accTracking});
  final String? accTracking;

  static const _steps = [
    ('ADV',  'PENDING_ADV'),
    ('KP',   'PENDING_KP'),
    ('MP',   'PENDING_MP'),
    ('PUR',  'PENDING_PUR'),
    ('✓',    'APPROVED'),
  ];

  @override
  Widget build(BuildContext context) {
    final curIdx = _steps.indexWhere((s) => s.$2 == accTracking);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_steps.length, (i) {
          final isDone = curIdx > i;
          final isCurrent = curIdx == i;
          final color = isDone ? AppColors.statusDone : isCurrent ? AppColors.gold : AppColors.textDisabled;

          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isCurrent ? color : AppColors.surfaceInput,
                  border: Border.all(color: isDone || isCurrent ? color : AppColors.border),
                ),
                child: isDone ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
              ),
              const SizedBox(height: 6),
              Text(_steps[i].$1, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
            ])),
            if (i < _steps.length - 1)
              Expanded(child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: isDone ? AppColors.statusDone : AppColors.border,
              )),
          ]));
        }),
      ),
    );
  }
}

// ── Header Card ────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.header});
  final PRHeader header;

  @override
  Widget build(BuildContext context) {
    final (stageLabel, stageColor) = _stageInfo(header.accTracking, header.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(header.carName ?? '-',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gold)),
            const SizedBox(height: 2),
            Text(header.divisionName ?? '-',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ])),
          _StageBadge(label: stageLabel, color: stageColor),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip(Icons.person_outline, header.requestedByName ?? '-'),
          _chip(Icons.shopping_cart_outlined, '${header.totalItems} item'),
          if (header.createdAt != null)
            _chip(Icons.calendar_today_outlined,
                DateFormat('d MMM yyyy', 'id_ID').format(header.createdAt!.toLocal())),
          if (header.targetDate != null)
            _chip(Icons.flag_outlined,
                'Target: ${DateFormat('d MMM yyyy', 'id_ID').format(header.targetDate!.toLocal())}'),
          if (header.priority == 'URGENT')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.orange),
                SizedBox(width: 5),
                Text('URGENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange)),
              ]),
            ),
        ]),
        if (header.notes != null && header.notes!.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(header.notes!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic))),
          ]),
        ],
      ]),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.background, borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textMuted),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    ]),
  );

  (String, Color) _stageInfo(String? acc, String? status) => switch (acc) {
    'PENDING_ADV' => ('MENUNGGU ADV', AppColors.orange),
    'PENDING_KP'  => ('MENUNGGU KP', AppColors.gold),
    'PENDING_MP'  => ('MENUNGGU MP', const Color(0xFF9C27B0)),
    'PENDING_PUR' => ('MENUNGGU PUR', const Color(0xFF2196F3)),
    'APPROVED'    => switch (status) {
      'DONE'     => ('SELESAI', AppColors.statusDone),
      'REJECTED' => ('DITOLAK', AppColors.statusLocked),
      _          => ('OPEN', AppColors.statusDone),
    },
    _ => ('DRAFT', AppColors.textMuted),
  };
}

// ── Items Section ──────────────────────────────────────────────

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.header, required this.isActing, required this.onFinalize});
  final PRHeader header;
  final bool isActing;
  final void Function(PRItem) onFinalize;

  @override
  Widget build(BuildContext context) {
    if (header.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle)),
        child: const Center(child: Text('Belum ada item', style: TextStyle(color: AppColors.textDisabled))),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Row(children: [
          const Text('Daftar Item', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          if (header.arrivedItems > 0) _mini('${header.arrivedItems}✓', AppColors.statusDone),
          if (header.huntingItems > 0) _mini('  ${header.huntingItems} hunting', AppColors.gold),
          if (header.orderedItems > 0) _mini('  ${header.orderedItems} ordered', AppColors.orange),
        ]),
      ),
      ...header.items.map((item) => _ItemCard(item: item, isActing: isActing, onFinalize: onFinalize)),
    ]);
  }

  Widget _mini(String t, Color c) =>
      Text(t, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600));
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.isActing, required this.onFinalize});
  final PRItem item;
  final bool isActing;
  final void Function(PRItem) onFinalize;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _itemStatus(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.itemName ?? '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
              const SizedBox(width: 8),
              _StageBadge(label: statusLabel, color: statusColor),
            ]),
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (item.qty != null) _chip('${item.qty} ${item.uom ?? ''}'),
              if (item.originType != null) _chip(item.originType!),
              if (item.vendorName != null) _chip('Vendor: ${item.vendorName}'),
              if (item.actualPrice != null && item.actualPrice! > 0)
                _chip('Rp ${_fmt(item.actualPrice!)}')
              else if (item.estimatedPrice != null && item.estimatedPrice! > 0)
                _chip('≈ Rp ${_fmt(item.estimatedPrice!)}'),
            ]),
            if (item.photoUrl != null && item.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _showPhoto(context, item.photoUrl!),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                    image: DecorationImage(
                      image: NetworkImage(item.photoUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
        // Finalize strip — only for ARRIVED items
        if (item.status == 'ARRIVED')
          InkWell(
            onTap: isActing ? null : () => onFinalize(item),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusDone.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.statusDone),
                const SizedBox(width: 6),
                const Text('Finalisasi Item', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.statusDone)),
              ]),
            ),
          ),
      ]),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _fmt(double v) => v >= 1000
      ? NumberFormat('#,###', 'id_ID').format(v)
      : v.toStringAsFixed(0);

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border)),
    child: Text(text, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  );

  (String, Color) _itemStatus(String? s) => switch (s) {
    'ARRIVED'   => ('TIBA', AppColors.statusDone),
    'HUNTING'   => ('HUNTING', AppColors.gold),
    'ORDERED'   => ('DIPESAN', AppColors.orange),
    'NOT_FOUND' => ('TDK DITEMUKAN', AppColors.statusLocked),
    'CANCELLED' => ('DIBATALKAN', AppColors.textDisabled),
    _ => ('PENDING', AppColors.textMuted),
  };
}

// ── Action Area (approve/reject bar) ──────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.isActing, required this.onApprove, required this.onReject});
  final bool isActing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0, right: 0, bottom: 0,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: isActing ? null : onReject,
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.statusLocked,
            side: const BorderSide(color: AppColors.statusLocked),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: FilledButton.icon(
          onPressed: isActing ? null : onApprove,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold, foregroundColor: AppColors.background,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
      ]),
    ),
  );
}

// ── Stage Badge ────────────────────────────────────────────────

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
  );
}
