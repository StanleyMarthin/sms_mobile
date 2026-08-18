/*
Tujuan: Halaman daftar Work Order aktif/selesai dengan tab, refresh, dan aksi buka detail/create.
Caller: FeatureShellPage route `/work-orders`.
Dependensi: WorkOrderBloc, SessionManager, WoCard, WoDetailPage, WoCreatePage.
Main Functions: WorkOrderPage, _openDetail, _openCreate.
Side Effects: HTTP load/refresh daftar WO dan navigasi ke detail/create.
*/
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/work_order.dart';
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_event.dart';
import '../bloc/work_order_state.dart';
import '../../../task_execution/presentation/widgets/date_filter_bar.dart';
import 'wo_detail_page.dart';
import 'wo_create_page.dart';
import '../widgets/wo_card.dart';

class WorkOrderPage extends StatefulWidget {
  const WorkOrderPage({super.key, this.focusWoId});
  final String? focusWoId;

  @override
  State<WorkOrderPage> createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late WorkOrderBloc _bloc;
  DateTime _historyDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _bloc = sl<WorkOrderBloc>()..add(LoadWorkOrders(view: 'ACTIVE'));
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {});
        _bloc.add(
          LoadWorkOrders(view: _tabCtrl.index == 0 ? 'ACTIVE' : 'DONE'),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final canCreate = session.isKdAccess && session.hasPerm(Perms.woCreate);

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            'Work Order',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: AppColors.textMuted,
              ),
              onPressed: () => _bloc.add(RefreshWorkOrders()),
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.gold,
            indicatorWeight: 2.5,
            tabs: [
              Tab(text: 'Aktif'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: BlocConsumer<WorkOrderBloc, WorkOrderState>(
          listener: (ctx, state) {
            if (state is WorkOrderActionSuccess) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.statusDone,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            if (state is WorkOrderError) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.statusLocked,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (ctx, state) {
            if (state is WorkOrderLoading || state is WorkOrderInitial) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (state is WorkOrderError) {
              return _ErrorView(
                message: state.message,
                onRetry: () => _bloc.add(RefreshWorkOrders()),
              );
            }

            final rawWos = state is WorkOrderLoaded
                ? state.workOrders
                : state is WorkOrderActionSuccess
                ? state.workOrders
                : <WorkOrder>[];
            final wos = _visibleWorkOrders(rawWos);

            if (wos.isEmpty) {
              return Column(
                children: [
                  if (_tabCtrl.index == 1)
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: DateFilterBar(
                        selectedDate: _historyDate,
                        onDateChanged: (date) =>
                            setState(() => _historyDate = date),
                        label: 'Riwayat tanggal',
                      ),
                    ),
                  Expanded(
                    child: _EmptyView(
                      canCreate: canCreate && _tabCtrl.index == 0,
                      onTap: () => _openCreate(context),
                    ),
                  ),
                ],
              );
            }

            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: () async => _bloc.add(RefreshWorkOrders()),
              child: Column(
                children: [
                  if (_tabCtrl.index == 1)
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: DateFilterBar(
                        selectedDate: _historyDate,
                        onDateChanged: (date) =>
                            setState(() => _historyDate = date),
                        label: 'Riwayat tanggal',
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 96),
                      itemCount: wos.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final wo = wos[i];
                        return WoCard(
                          wo: wo,
                          isHighlighted: wo.id == widget.focusWoId,
                          onTap: () => _openDetail(context, wo.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                heroTag: 'wo_fab',
                onPressed: () => _openCreate(context),
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                icon: Icon(Icons.add_rounded),
                label: Text(
                  'Buat WO',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
      ),
    );
  }

  void _openDetail(BuildContext context, String woId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _bloc,
          child: WoDetailPage(woId: woId),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: _bloc, child: WoCreatePage()),
      ),
    );
  }

  List<WorkOrder> _visibleWorkOrders(List<WorkOrder> workOrders) {
    if (_tabCtrl.index == 0) {
      return workOrders.where((wo) => wo.isActive).toList();
    }

    return workOrders
        .where((wo) => wo.isTerminal && _isSameHistoryDate(wo, _historyDate))
        .toList();
  }

  bool _isSameHistoryDate(WorkOrder wo, DateTime date) {
    final rawDate = wo.approvalDate ?? wo.requestDate;
    if (rawDate == null || rawDate.length < 10) return false;
    final parsed = DateTime.tryParse(rawDate.substring(0, 10));
    if (parsed == null) return false;
    return parsed.year == date.year &&
        parsed.month == date.month &&
        parsed.day == date.day;
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: AppColors.statusLocked,
        ),
        SizedBox(height: 12),
        Text(
          message,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: Icon(Icons.refresh),
          label: Text('Coba Lagi'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: BorderSide(color: AppColors.gold),
          ),
        ),
      ],
    ),
  );
}

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
            Icons.assignment_outlined,
            size: 56,
            color: AppColors.gold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Belum ada Work Order',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (canCreate) ...[
          SizedBox(height: 8),
          Text(
            'Tekan tombol di bawah untuk membuat WO baru',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}
