// Halaman daftar Purchase Request — mengikuti pola WO list page.
// Caller: FeatureShellPage route /pr

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';
import '../../data/datasources/remote_pr_datasource.dart';
import '../../data/models/pr_header.dart';
import 'pr_detail_page.dart';
import 'pr_form_page.dart';

class PrPage extends StatefulWidget {
  final String? focusReqId;
  const PrPage({super.key, this.focusReqId});
  @override
  State<PrPage> createState() => _PrPageState();
}

class _PrPageState extends State<PrPage> with SingleTickerProviderStateMixin {
  late final RemotePrDataSource _ds;
  late final TabController _tabCtrl;

  List<PRHeader> _prs = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ds = RemotePrDataSource(apiClient: sl(), sessionManager: sl());
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
      final prs = switch (_tabCtrl.index) {
        1 => await _ds.getPrs(accTracking: 'APPROVED', limit: 100),
        _ => await _ds.getPrs(accTracking: 'ALL', limit: 100),
      };
      if (mounted) {
        setState(() => _prs = prs);
      }
    } catch (e) {
      if (mounted) {
        _snack(friendlyMessage(e, fallback: 'Gagal memuat PR'), isError: true);
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

  void _openDetail(String reqId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrDetailPage(reqId: reqId)),
    ).then((_) => _fetch());
  }

  void _openForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrFormPage()),
    ).then((result) {
      if (result == true) _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = hasPermission(
      sl<SessionManager>().role,
      Permission.prCreate,
    );
    final visiblePrs = _visiblePrs;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Purchase Request',
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
            Tab(text: 'Hunting'),
            Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : visiblePrs.isEmpty
          ? Column(
              children: [
                if (_tabCtrl.index == 2) _dateFilterBar(),
                Expanded(
                  child: _EmptyView(
                    canCreate: canCreate && _tabCtrl.index != 2,
                    onTap: _openForm,
                  ),
                ),
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
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 96),
                      itemCount: visiblePrs.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) => _PrCard(
                        pr: visiblePrs[i],
                        isHighlighted: visiblePrs[i].reqId == widget.focusReqId,
                        onTap: () => _openDetail(visiblePrs[i].reqId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'pr_fab',
              onPressed: _openForm,
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              icon: Icon(Icons.add_rounded),
              label: Text(
                'Buat PR',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  List<PRHeader> get _visiblePrs {
    return switch (_tabCtrl.index) {
      0 =>
        _prs.where((pr) => !_isApprovedPr(pr) && !_isTerminalPr(pr)).toList(),
      1 => _prs.where((pr) => _isApprovedPr(pr) && !_isTerminalPr(pr)).toList(),
      _ =>
        _prs
            .where(
              (pr) =>
                  _isTerminalPr(pr) && _isSameDate(pr.createdAt, _selectedDate),
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

  bool _isTerminalPr(PRHeader pr) {
    final terminalStatuses = {
      'DONE',
      'CLOSED',
      'REJECTED',
      'CANCEL',
      'CANCELLED',
      'CANCELED',
      'ARRIVED',
      'RECEIVED',
      'NOT_FOUND',
    };
    final status = pr.status?.trim().toUpperCase();
    final accTracking = pr.accTracking?.trim().toUpperCase();
    return terminalStatuses.contains(status) ||
        terminalStatuses.contains(accTracking);
  }

  bool _isApprovedPr(PRHeader pr) {
    return pr.accTracking?.trim().toUpperCase() == 'APPROVED';
  }

  bool _isSameDate(DateTime? source, DateTime selected) {
    if (source == null) return false;
    final local = source.toLocal();
    return local.year == selected.year &&
        local.month == selected.month &&
        local.day == selected.day;
  }
}

// ── PR Card ────────────────────────────────────────────────────

class _PrCard extends StatelessWidget {
  const _PrCard({
    required this.pr,
    required this.onTap,
    this.isHighlighted = false,
  });
  final PRHeader pr;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _stageInfo(pr.accTracking, pr.status);

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
              // Colored left accent bar
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
                            pr.prNumber ?? pr.reqId,
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
                      '${pr.carName ?? '-'} • ${pr.divisionName ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    _ItemProgressRow(pr: pr),
                    SizedBox(height: 3),
                    Text(
                      '${pr.requestedByName ?? '-'} • ${_fmtDate(pr.createdAt)}',
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
      'DONE' || 'ARRIVED' || 'RECEIVED' => ('SELESAI', AppColors.statusDone),
      'REJECTED' => ('DITOLAK', AppColors.statusLocked),
      'CANCEL' ||
      'CANCELLED' ||
      'CANCELED' => ('DIBATALKAN', AppColors.statusLocked),
      'NOT_FOUND' => ('TIDAK ADA', AppColors.statusLocked),
      _ => null,
    };
    if (terminal != null) return terminal;

    return switch (acc) {
      'PENDING_ADV' => ('MENUNGGU QA', AppColors.orange),
      'PENDING_KP' => ('MENUNGGU KP', AppColors.gold),
      'PENDING_MP' => ('MENUNGGU MP', Color(0xFF9C27B0)),
      'PENDING_PUR' => ('MENUNGGU PUR', Color(0xFF2196F3)),
      'APPROVED' => ('HUNTING', AppColors.statusInProgress),
      _ => ('DRAFT', AppColors.textMuted),
    };
  }
}

class _ItemProgressRow extends StatelessWidget {
  const _ItemProgressRow({required this.pr});
  final PRHeader pr;

  @override
  Widget build(BuildContext context) {
    if (pr.totalItems == 0) return SizedBox.shrink();
    return Row(
      children: [
        Text(
          '${pr.totalItems} item',
          style: TextStyle(fontSize: 10, color: AppColors.textDisabled),
        ),
        if (pr.arrivedItems > 0)
          _mini('  ${pr.arrivedItems}✓', AppColors.statusDone),
        if (pr.huntingItems > 0)
          _mini('  ${pr.huntingItems} hunting', AppColors.gold),
        if (pr.orderedItems > 0)
          _mini('  ${pr.orderedItems} ordered', AppColors.orange),
      ],
    );
  }

  Widget _mini(String t, Color c) => Text(
    t,
    style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600),
  );
}

// ── Shared Badge ───────────────────────────────────────────────

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

// ── Empty state ────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onTap;
  const _EmptyView({required this.canCreate, required this.onTap});

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
            Icons.shopping_cart_outlined,
            size: 56,
            color: AppColors.gold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Belum ada Purchase Request',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (canCreate) ...[
          SizedBox(height: 8),
          Text(
            'Tekan tombol di bawah untuk membuat PR baru',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}
