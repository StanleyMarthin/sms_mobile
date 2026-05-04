import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../bloc/work_order_bloc.dart';
import '../bloc/work_order_event.dart';
import '../bloc/work_order_state.dart';
import 'wo_detail_page.dart';
import 'wo_create_page.dart';
import '../widgets/wo_card.dart';

class WorkOrderPage extends StatefulWidget {
  const WorkOrderPage({super.key, this.focusWoId});
  final String? focusWoId;

  @override
  State<WorkOrderPage> createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late WorkOrderBloc _bloc;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _bloc = sl<WorkOrderBloc>()..add(const LoadWorkOrders(view: 'ACTIVE'));
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _bloc.add(LoadWorkOrders(view: _tabCtrl.index == 0 ? 'ACTIVE' : 'DONE'));
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
    final role = session.role ?? '';
    final canCreate = ['KD', 'KETUA_DIVISI', 'ADMIN'].contains(role.toUpperCase());

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            'Work Order',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
              onPressed: () => _bloc.add(const RefreshWorkOrders()),
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.gold,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Aktif'),
              Tab(text: 'Selesai'),
            ],
          ),
        ),
        body: BlocConsumer<WorkOrderBloc, WorkOrderState>(
          listener: (ctx, state) {
            if (state is WorkOrderActionSuccess) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.statusDone,
                behavior: SnackBarBehavior.floating,
              ));
            }
            if (state is WorkOrderError) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.statusLocked,
                behavior: SnackBarBehavior.floating,
              ));
            }
          },
          builder: (ctx, state) {
            if (state is WorkOrderLoading || state is WorkOrderInitial) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (state is WorkOrderError) {
              return _ErrorView(message: state.message, onRetry: () => _bloc.add(const RefreshWorkOrders()));
            }

            final wos = state is WorkOrderLoaded
                ? state.workOrders
                : state is WorkOrderActionSuccess
                    ? state.workOrders
                    : <dynamic>[];

            if (wos.isEmpty) return _EmptyView(canCreate: canCreate, onTap: () => _openCreate(context));

            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: () async => _bloc.add(const RefreshWorkOrders()),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: wos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final wo = wos[i];
                  return WoCard(
                    wo: wo,
                    isHighlighted: wo.id == widget.focusWoId,
                    onTap: () => _openDetail(context, wo.id),
                  );
                },
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
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat WO', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            : null,
      ),
    );
  }

  void _openDetail(BuildContext context, String woId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(
      value: _bloc,
      child: WoDetailPage(woId: woId),
    )));
  }

  void _openCreate(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BlocProvider.value(
      value: _bloc,
      child: const WoCreatePage(),
    )));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.statusLocked),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold, side: const BorderSide(color: AppColors.gold)),
          ),
        ]),
      );
}

class _EmptyView extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onTap;
  const _EmptyView({required this.canCreate, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, size: 56, color: AppColors.gold),
          ),
          const SizedBox(height: 16),
          const Text('Belum ada Work Order', style: TextStyle(fontSize: 15, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          if (canCreate) ...[
            const SizedBox(height: 8),
            const Text('Tekan tombol di bawah untuk membuat WO baru',
                style: TextStyle(fontSize: 12, color: AppColors.textDisabled), textAlign: TextAlign.center),
          ],
        ]),
      );
}
