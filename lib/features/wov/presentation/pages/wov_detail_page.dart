// Halaman detail WOV — mengikuti pola wo_detail_page.dart.
// Struktur: _ApprovalStatusBar + _HeaderCard + _StatusCard + _ActionArea

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/datasources/remote_wov_datasource.dart';
import '../../data/models/wov_order.dart';

class WovDetailPage extends StatefulWidget {
  final String reqId;
  const WovDetailPage({super.key, required this.reqId});
  @override
  State<WovDetailPage> createState() => _WovDetailPageState();
}

class _WovDetailPageState extends State<WovDetailPage> {
  late final RemoteWovDataSource _ds;
  WOVOrder? _wov;
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _ds = RemoteWovDataSource(apiClient: sl(), sessionManager: sl());
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final d = await _ds.getWovDetail(widget.reqId);
      if (mounted) setState(() => _wov = d);
    } catch (e) {
      if (mounted) {
        _snack(friendlyMessage(e, fallback: 'Gagal memuat WOV'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppColors.statusLocked
            : AppColors.statusDone,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _canApprove() {
    final acc = _wov?.accTracking;
    if (acc == null || acc == 'APPROVED') return false;
    final session = sl<SessionManager>();
    if (!hasPermission(session.role, Permission.wovApprove)) {
      return false;
    }
    return switch (acc) {
      'PENDING_ADV' => session.isAdvisorAccess,
      'PENDING_KP' => session.isKpAccess,
      'PENDING_PM' => session.isGlobalAccess,
      _ => false,
    };
  }

  bool _canUpdateStatus() {
    final session = sl<SessionManager>();
    return hasPermission(session.role, Permission.wovUpdate) &&
        _wov?.accTracking == 'APPROVED' &&
        !['RECEIVED'].contains(_wov?.status);
  }

  bool _canFinalize() {
    final session = sl<SessionManager>();
    return hasPermission(session.role, Permission.wovUpdate) &&
        (_wov?.status == 'DONE_VENDOR' || _wov?.status == 'RECEIVED');
  }

  Future<void> _approve() async {
    if (!await _confirmDialog('Setujui WOV ini?')) return;
    setState(() => _isActing = true);
    try {
      await _ds.approveWov(widget.reqId);
      if (mounted) _snack('WOV berhasil di-approve');
      _load();
    } catch (e) {
      if (mounted) {
        _snack(
          friendlyMessage(e, fallback: 'Gagal approve WOV'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    final notes = await _notesDialog('Alasan Penolakan');
    if (notes == null) return;
    setState(() => _isActing = true);
    try {
      await _ds.rejectWov(widget.reqId, notes: notes.isNotEmpty ? notes : null);
      if (mounted) _snack('WOV ditolak');
      _load();
    } catch (e) {
      if (mounted) {
        _snack(
          friendlyMessage(e, fallback: 'Gagal menolak WOV'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isActing = true);
    try {
      await _ds.updateStatus(widget.reqId, newStatus);
      if (mounted) _snack('Status diperbarui ke $newStatus');
      _load();
    } catch (e) {
      if (mounted) {
        _snack(
          friendlyMessage(e, fallback: 'Gagal perbarui status'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _finalize() async {
    final route = await _routeDialog();
    if (route == null) return;
    setState(() => _isActing = true);
    try {
      await _ds.finalizeWov(reqId: widget.reqId, route: route);
      if (mounted) _snack('WOV berhasil difinalisasi');
      _load();
    } catch (e) {
      if (mounted) {
        _snack(
          friendlyMessage(e, fallback: 'Gagal finalisasi WOV'),
          isError: true,
        );
      }
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
          title: Text(
            msg,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(
                'Batal',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () => Navigator.pop(c, true),
              child: Text(
                'Ya, Setujui',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _notesDialog(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          title,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tulis alasan...',
            hintStyle: TextStyle(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surfaceInput,
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
              borderSide: BorderSide(color: AppColors.statusLocked),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusLocked,
            ),
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(
              'Tolak WOV',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _routeDialog() async => showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      title: Text(
        'Finalisasi WOV',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      content: Text(
        'Kirim barang ke mana setelah diterima?',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: BorderSide(color: AppColors.gold),
          ),
          onPressed: () => Navigator.pop(c, 'TO_JOBDESC'),
          icon: Icon(Icons.engineering_outlined, size: 16),
          label: Text('Job Desc'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.background,
          ),
          onPressed: () => Navigator.pop(c, 'TO_WAREHOUSE'),
          icon: Icon(Icons.warehouse_outlined, size: 16),
          label: Text('Warehouse'),
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
        leading: BackButton(color: AppColors.textMuted),
        title: Text(
          _wov?.wovNumber ?? 'Detail WOV',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        actions: [
          if (_wov != null)
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: AppColors.textMuted,
              ),
              onPressed: _load,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : _wov == null
          ? Center(
              child: Text(
                'WOV tidak ditemukan',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.gold,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 110),
                    children: [
                      _ApprovalStatusBar(accTracking: _wov!.accTracking),
                      SizedBox(height: 16),
                      _HeaderCard(wov: _wov!),
                      SizedBox(height: 16),
                      _StatusCard(wov: _wov!),
                      if (_canUpdateStatus()) ...[
                        SizedBox(height: 16),
                        _StatusActions(
                          wov: _wov!,
                          isActing: _isActing,
                          onUpdate: _updateStatus,
                        ),
                      ],
                      if (_canFinalize()) ...[
                        SizedBox(height: 12),
                        _FinalizeStrip(
                          isActing: _isActing,
                          onFinalize: _finalize,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_canApprove())
                  _ApprovalBar(
                    isActing: _isActing,
                    onApprove: _approve,
                    onReject: _reject,
                  ),
                if (_isActing)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Approval Status Bar ────────────────────────────────────────

class _ApprovalStatusBar extends StatelessWidget {
  const _ApprovalStatusBar({required this.accTracking});
  final String? accTracking;

  static final _steps = [
    ('ADV', 'PENDING_ADV'),
    ('KP', 'PENDING_KP'),
    ('PM', 'PENDING_PM'),
    ('✓', 'APPROVED'),
  ];

  @override
  Widget build(BuildContext context) {
    final curIdx = _steps.indexWhere((s) => s.$2 == accTracking);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
          final color = isDone
              ? AppColors.statusDone
              : isCurrent
              ? AppColors.gold
              : AppColors.textDisabled;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone || isCurrent
                              ? color
                              : AppColors.surfaceInput,
                          border: Border.all(
                            color: isDone || isCurrent
                                ? color
                                : AppColors.border,
                          ),
                        ),
                        child: isDone
                            ? Icon(
                                Icons.check,
                                size: 8,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(height: 6),
                      Text(
                        _steps[i].$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.only(bottom: 16),
                      color: isDone ? AppColors.statusDone : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Header Card ────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.wov});
  final WOVOrder wov;

  @override
  Widget build(BuildContext context) {
    final (stageLabel, stageColor) = _stageInfo(wov.accTracking, wov.status);

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wov.itemName ?? '-',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${wov.vendorName ?? '-'}${wov.picVendor != null ? ' • ${wov.picVendor}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StageBadge(label: stageLabel, color: stageColor),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (wov.carName != null)
                _chip(Icons.directions_car_outlined, wov.carName!),
              if (wov.quantity != null)
                _chip(
                  Icons.inventory_2_outlined,
                  '${wov.quantity} ${wov.uom ?? ''}',
                ),
              if (wov.estimatedCost != null && wov.estimatedCost! > 0)
                _chip(
                  Icons.attach_money_rounded,
                  'Est. Rp ${_fmt(wov.estimatedCost!)}',
                ),
              if (wov.targetDateReturn != null)
                _chip(
                  Icons.event_rounded,
                  'Target ${_fmtDate(wov.targetDateReturn)}',
                ),
            ],
          ),
          if (wov.goodsConditionOut != null) ...[
            SizedBox(height: 8),
            Divider(color: AppColors.borderSubtle, height: 1),
            SizedBox(height: 8),
            _infoRow('Kondisi keluar', wov.goodsConditionOut!),
          ],
          if (wov.remarks != null && wov.remarks!.isNotEmpty) ...[
            SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wov.remarks!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _infoRow(String l, String v) => Padding(
    padding: EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            l,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  String _fmt(double v) => v >= 1000
      ? NumberFormat('#,###', 'id_ID').format(v)
      : v.toStringAsFixed(0);
  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat('d MMM yy', 'id_ID').format(d.toLocal());

  (String, Color) _stageInfo(String? acc, String? status) => switch (acc) {
    'PENDING_ADV' => ('MENUNGGU QA', AppColors.orange),
    'PENDING_KP' => ('MENUNGGU KP', AppColors.gold),
    'PENDING_PM' => ('MENUNGGU PM', Color(0xFF9C27B0)),
    'APPROVED' => switch (status) {
      'SENT' => ('TERKIRIM', Color(0xFF2196F3)),
      'PROSES_VENDOR' => ('DI VENDOR', AppColors.orange),
      'DONE_VENDOR' => ('SELESAI VENDOR', AppColors.statusDone),
      'REWORK_VENDOR' => ('REWORK', AppColors.statusLocked),
      'RECEIVED' => ('DITERIMA', AppColors.statusDone),
      _ => ('OPEN', AppColors.statusInProgress),
    },
    _ => ('DRAFT', AppColors.textMuted),
  };
}

// ── Status Card ───────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.wov});
  final WOVOrder wov;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          _row('No. WOV', wov.wovNumber ?? '-'),
          _row('Approval', wov.accTracking ?? '-'),
          if (wov.status != null) _row('Status', wov.status!),
          if (wov.dateOut != null) _row('Keluar', _fmtDate(wov.dateOut)),
          if (wov.targetDateReturn != null)
            _row('Target Kembali', _fmtDate(wov.targetDateReturn)),
          if (wov.dateIn != null) _row('Diterima', _fmtDate(wov.dateIn)),
          if (wov.goodsConditionIn != null)
            _row('Kondisi Masuk', wov.goodsConditionIn!),
          if (wov.actualCost != null)
            _row(
              'Biaya Aktual',
              'Rp ${NumberFormat('#,###', 'id_ID').format(wov.actualCost!)}',
            ),
          if (wov.qcStatus != null) _row('QC', wov.qcStatus!),
        ],
      ),
    );
  }

  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat('d MMM yyyy', 'id_ID').format(d.toLocal());

  Widget _row(String l, String v) => Padding(
    padding: EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            l,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Status Action Buttons ──────────────────────────────────────

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.wov,
    required this.isActing,
    required this.onUpdate,
  });
  final WOVOrder wov;
  final bool isActing;
  final void Function(String) onUpdate;

  @override
  Widget build(BuildContext context) {
    final current = wov.status ?? 'OPEN';
    final nexts = switch (current) {
      'OPEN' => ['SENT'],
      'SENT' => ['PROSES_VENDOR'],
      'PROSES_VENDOR' => ['DONE_VENDOR', 'REWORK_VENDOR'],
      'REWORK_VENDOR' => ['DONE_VENDOR'],
      'DONE_VENDOR' => ['RECEIVED'],
      _ => <String>[],
    };

    if (nexts.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update_rounded, color: AppColors.gold, size: 16),
              SizedBox(width: 8),
              Text(
                'Update Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: nexts.map((s) {
              final label = switch (s) {
                'SENT' => 'Dikirim ke Vendor',
                'PROSES_VENDOR' => 'Proses di Vendor',
                'DONE_VENDOR' => 'Selesai di Vendor',
                'REWORK_VENDOR' => 'Rework',
                'RECEIVED' => 'Barang Diterima',
                _ => s,
              };
              return FilledButton(
                onPressed: isActing ? null : () => onUpdate(s),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.background,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Finalize Strip ─────────────────────────────────────────────

class _FinalizeStrip extends StatelessWidget {
  const _FinalizeStrip({required this.isActing, required this.onFinalize});
  final bool isActing;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: isActing ? null : onFinalize,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.statusDone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusDone.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: AppColors.statusDone,
          ),
          SizedBox(width: 8),
          Text(
            'Finalisasi WOV',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.statusDone,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Approval Bar ───────────────────────────────────────────────

class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({
    required this.isActing,
    required this.onApprove,
    required this.onReject,
  });
  final bool isActing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isActing ? null : onReject,
              icon: Icon(Icons.close_rounded, size: 16),
              label: Text(
                'Tolak',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusLocked,
                side: BorderSide(color: AppColors.statusLocked),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: isActing ? null : onApprove,
              icon: Icon(Icons.check_rounded, size: 16),
              label: Text(
                'Setujui',
                style: TextStyle(fontWeight: FontWeight.w700),
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
          ),
        ],
      ),
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
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
