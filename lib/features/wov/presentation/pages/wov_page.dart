// Halaman daftar WOV — mengikuti pola WO list page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';
import '../../data/datasources/remote_wov_datasource.dart';
import '../../data/models/wov_order.dart';
import 'wov_detail_page.dart';
import 'wov_form_page.dart';

class WovPage extends StatefulWidget {
  final String? focusReqId;
  const WovPage({super.key, this.focusReqId});
  @override
  State<WovPage> createState() => _WovPageState();
}

class _WovPageState extends State<WovPage> with SingleTickerProviderStateMixin {
  late final RemoteWovDataSource _ds;
  late final TabController _tabCtrl;

  List<WOVOrder> _wovs = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ds = RemoteWovDataSource(apiClient: sl(), sessionManager: sl());
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _fetch();
    });
    _fetch();

    if (widget.focusReqId != null && widget.focusReqId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openDetail(widget.focusReqId!),
      );
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final items = switch (_tabCtrl.index) {
        1 => await _ds.getWovs(accTracking: 'APPROVED', limit: 100),
        _ => await _ds.getWovs(accTracking: 'ALL', limit: 100),
      };
      if (mounted) setState(() => _wovs = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyMessage(e, fallback: 'Gagal memuat WOV')),
            backgroundColor: AppColors.statusLocked,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDetail(String reqId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WovDetailPage(reqId: reqId)),
    ).then((_) => _fetch());
  }

  void _openForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WovFormPage()),
    ).then((result) {
      if (result == true) _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = hasPermission(
      sl<SessionManager>().role,
      Permission.wovCreate,
    );
    final visibleWovs = _visibleWovs;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Work Order Vendor',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            onPressed: _fetch,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.gold,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'Approval'),
            Tab(text: 'Proses'),
            Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : visibleWovs.isEmpty
          ? Column(
              children: [
                if (_tabCtrl.index == 2) _dateFilterBar(),
                Expanded(child: _EmptyView()),
              ],
            )
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _fetch,
              child: Column(
                children: [
                  if (_tabCtrl.index == 2) _dateFilterBar(),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 32),
                      itemCount: visibleWovs.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) => _WovCard(
                        wov: visibleWovs[i],
                        isHighlighted:
                            visibleWovs[i].reqId == widget.focusReqId,
                        onTap: () => _openDetail(visibleWovs[i].reqId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'wov_fab',
              onPressed: _openForm,
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              icon: Icon(Icons.add_rounded),
              label: Text(
                'Buat WOV',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  List<WOVOrder> get _visibleWovs {
    return switch (_tabCtrl.index) {
      0 =>
        _wovs
            .where((wov) => !_isApprovedWov(wov) && !_isTerminalWov(wov))
            .toList(),
      1 =>
        _wovs
            .where((wov) => _isApprovedWov(wov) && !_isTerminalWov(wov))
            .toList(),
      _ =>
        _wovs
            .where(
              (wov) =>
                  _isTerminalWov(wov) &&
                  _isSameDate(wov.dateIn ?? wov.createdAt, _selectedDate),
            )
            .toList(),
    };
  }

  Widget _dateFilterBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: DateFilterBar(
        selectedDate: _selectedDate,
        onDateChanged: (date) => setState(() => _selectedDate = date),
        label: 'Riwayat tanggal',
      ),
    );
  }

  bool _isTerminalWov(WOVOrder wov) {
    final terminalStatuses = {
      'RECEIVED',
      'DONE',
      'CLOSED',
      'REJECTED',
      'CANCEL',
      'CANCELLED',
      'CANCELED',
    };
    final status = wov.status?.trim().toUpperCase();
    final accTracking = wov.accTracking?.trim().toUpperCase();
    return terminalStatuses.contains(status) ||
        terminalStatuses.contains(accTracking);
  }

  bool _isApprovedWov(WOVOrder wov) {
    return wov.accTracking?.trim().toUpperCase() == 'APPROVED';
  }

  bool _isSameDate(DateTime? source, DateTime selected) {
    if (source == null) return false;
    final local = source.toLocal();
    return local.year == selected.year &&
        local.month == selected.month &&
        local.day == selected.day;
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            size: 56,
            color: AppColors.gold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Belum ada Work Order Vendor',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ── WOV Card ───────────────────────────────────────────────────

class _WovCard extends StatelessWidget {
  const _WovCard({
    required this.wov,
    required this.onTap,
    this.isHighlighted = false,
  });
  final WOVOrder wov;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _stageInfo(wov.accTracking, wov.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? AppColors.gold
                : color.withValues(alpha: 0.22),
            width: isHighlighted ? 1.2 : 0.9,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 52,
                margin: EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            wov.wovNumber ?? wov.reqId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        _Badge(label: label, color: color),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${wov.itemName ?? '-'} • ${wov.vendorName ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${wov.carName ?? '-'} • ${_fmtDate(wov.createdAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('d MMM yyyy', 'id_ID').format(d.toLocal());
  }

  (String, Color) _stageInfo(String? acc, String? status) {
    final normalizedStatus = status?.trim().toUpperCase();
    final terminal = switch (normalizedStatus) {
      'RECEIVED' || 'DONE' => ('DITERIMA', AppColors.statusDone),
      'REJECTED' => ('DITOLAK', AppColors.statusLocked),
      'CANCEL' ||
      'CANCELLED' ||
      'CANCELED' => ('DIBATALKAN', AppColors.statusLocked),
      _ => null,
    };
    if (terminal != null) return terminal;

    return switch (acc) {
      'PENDING_ADV' => ('MENUNGGU QA', AppColors.orange),
      'PENDING_KP' => ('MENUNGGU KP', AppColors.gold),
      'PENDING_PM' => ('MENUNGGU PM', Color(0xFF9C27B0)),
      'APPROVED' => switch (normalizedStatus) {
        'SENT' => ('TERKIRIM', Color(0xFF2196F3)),
        'PROSES_VENDOR' => ('DI VENDOR', AppColors.orange),
        'DONE_VENDOR' => ('SELESAI VENDOR', AppColors.statusDone),
        'REWORK_VENDOR' => ('REWORK', AppColors.statusLocked),
        _ => ('OPEN', AppColors.statusInProgress),
      },
      _ => ('DRAFT', AppColors.textMuted),
    };
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
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
