import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';

class OperatorDashboardOverviewPage extends StatelessWidget {
  const OperatorDashboardOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final stats = <Map<String, dynamic>>[
      {'label': 'Task Hari Ini', 'value': '6', 'color': AppColors.gold, 'icon': Icons.assignment_outlined},
      {'label': 'Sedang Proses', 'value': '2', 'color': AppColors.orange, 'icon': Icons.play_circle_outline},
      {'label': 'Menunggu Gudang', 'value': '1', 'color': AppColors.statusLocked, 'icon': Icons.inventory_2_outlined},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.14),
                AppColors.surfaceCard,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard ${session.divisionName ?? 'Workshop'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ringkasan aktivitas operator untuk hari ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...stats.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
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
                      color: (item['color'] as Color).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'] as IconData, color: item['color'] as Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['label'] as String,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    item['value'] as String,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: item['color'] as Color,
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checklist Hari Ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 10),
              _OverviewBullet(text: 'Mulai task dengan foto awal sebelum pekerjaan dimulai'),
              _OverviewBullet(text: 'Ajukan barang gudang untuk tools, spare part, atau bahan'),
              _OverviewBullet(text: 'Lihat notifikasi approval agar tidak ada pekerjaan tertahan'),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewBullet extends StatelessWidget {
  final String text;
  const _OverviewBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}