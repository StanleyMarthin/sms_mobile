import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../countdown/domain/repositories/countdown_repository.dart';
import '../../../warehouse_request/domain/repositories/warehouse_repository.dart';
import '../../../work_order/domain/repositories/work_order_repository.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  late final CountdownRepository _countdownRepository;
  late final WarehouseRepository _warehouseRepository;
  late final WorkOrderRepository _workOrderRepository;

  late Future<_ApprovalSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _countdownRepository = sl<CountdownRepository>();
    _warehouseRepository = sl<WarehouseRepository>();
    _workOrderRepository = sl<WorkOrderRepository>();
    _summaryFuture = _loadSummary();
  }

  Future<_ApprovalSummary> _loadSummary() async {
    try {
      final revisionRequests = await _countdownRepository.getRevisionRequests();
      final revisionPending = revisionRequests
          .where(
            (item) =>
                (item.revisionRequestStatus ?? '').toUpperCase() == 'REQUESTED',
          )
          .length;

      final warehouseLogs = await _warehouseRepository.getLogs();
      final warehousePending = warehouseLogs
          .where((log) => log.isAnyPending)
          .length;

      final woEither = await _workOrderRepository.getWorkOrders(view: 'ACTIVE');
      final woPending = woEither.fold(
        (_) => 0,
        (items) => items.where((wo) => wo.isActive).length,
      );

      return _ApprovalSummary(
        countdownRevisionPending: revisionPending,
        warehousePending: warehousePending,
        workOrderPending: woPending,
      );
    } catch (e) {
      if (mounted) {
        AppNotification.showError(
          context,
          friendlyMessage(e, fallback: 'Gagal memuat data approval'),
        );
      }
      return _ApprovalSummary(
        countdownRevisionPending: 0,
        warehousePending: 0,
        workOrderPending: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ApprovalSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }

        final summary = snapshot.data!;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            setState(() => _summaryFuture = _loadSummary());
            await _summaryFuture;
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(
                'Approval Center',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Pantau antrean approval lintas modul dan buka halaman detailnya.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              SizedBox(height: 14),
              _ApprovalCard(
                title: 'Revisi Countdown',
                subtitle: 'Permintaan tambahan jam/deadline dari KD',
                pendingCount: summary.countdownRevisionPending,
                icon: Icons.timer_outlined,
                onTap: () => context.push('/countdown'),
              ),
              SizedBox(height: 10),
              _ApprovalCard(
                title: 'Work Order',
                subtitle: 'WO yang menunggu tahap approval',
                pendingCount: summary.workOrderPending,
                icon: Icons.assignment_outlined,
                onTap: () => context.push('/work-orders'),
              ),
              SizedBox(height: 10),
              _ApprovalCard(
                title: 'Warehouse',
                subtitle: 'Pengajuan barang/alat menunggu persetujuan',
                pendingCount: summary.warehousePending,
                icon: Icons.inventory_2_outlined,
                onTap: () => context.push('/warehouse'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalSummary {
  _ApprovalSummary({
    required this.countdownRevisionPending,
    required this.warehousePending,
    required this.workOrderPending,
  });

  final int countdownRevisionPending;
  final int warehousePending;
  final int workOrderPending;
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.pendingCount,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int pendingCount;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    final badgeColor = hasPending ? AppColors.orange : AppColors.statusDone;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.gold),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$pendingCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
