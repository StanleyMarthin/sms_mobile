import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/notification_inbox_service.dart';
import '../../domain/entities/notification_item.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationInboxService _inbox;

  @override
  void initState() {
    super.initState();
    _inbox = sl<NotificationInboxService>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _inbox.ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _inbox,
      builder: (context, _) {
        final items = _inbox.items;

        if (items.isEmpty) {
          return const _EmptyNotifications();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderBar(
              count: items.length,
              onClear: () => _handleClearAll(context),
            ),
            const SizedBox(height: 14),
            ...items.map(_buildItemCard),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(NotificationItem item) {
    final isRead = item.isRead;
    final meta = _metaFor(item.targetRoute);

    return InkWell(
      onTap: () => context.push(item.targetRoute),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isRead
                ? [AppColors.borderSubtle, AppColors.borderSubtle]
                : [
                    meta.color.withValues(alpha: 0.55),
                    meta.color.withValues(alpha: 0.15),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!isRead)
              BoxShadow(
                color: meta.color.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : meta.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: isRead ? 0.10 : 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  meta.icon,
                  size: 20,
                  color: isRead
                      ? meta.color.withValues(alpha: 0.75)
                      : meta.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatShortTime(item.createdAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isRead ? AppColors.textMuted : meta.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            meta.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: meta.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatCreatedAt(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Hapus Riwayat Notifikasi?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Semua notifikasi yang tersimpan di perangkat ini akan dihapus.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusLocked,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _inbox.clearAll();
    }
  }

  String _formatCreatedAt(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  String _formatShortTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$hh:$min';
  }

  _NotifMeta _metaFor(String route) {
    final value = route.toLowerCase();
    if (value.contains('/warehouse')) {
      return const _NotifMeta(
        label: 'Warehouse',
        icon: Icons.inventory_2_outlined,
        color: Color(0xFF13B8A6),
      );
    }
    if (value.contains('/work-orders')) {
      return const _NotifMeta(
        label: 'WO',
        icon: Icons.assignment_outlined,
        color: AppColors.orange,
      );
    }
    if (value.contains('/qc')) {
      return const _NotifMeta(
        label: 'QC',
        icon: Icons.verified_outlined,
        color: Color(0xFF5B8EFF),
      );
    }
    if (value.contains('/tasks') || value.contains('/plans')) {
      return const _NotifMeta(
        label: 'Task',
        icon: Icons.event_note_outlined,
        color: AppColors.gold,
      );
    }
    if (value.contains('/countdown')) {
      return const _NotifMeta(
        label: 'Countdown',
        icon: Icons.timelapse_rounded,
        color: Color(0xFFB67BFF),
      );
    }
    if (value.contains('/pr')) {
      return const _NotifMeta(
        label: 'PR',
        icon: Icons.shopping_cart_outlined,
        color: Color(0xFF4CAF50),
      );
    }
    return const _NotifMeta(
      label: 'Notif',
      icon: Icons.notifications_outlined,
      color: AppColors.gold,
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$count item',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClear,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.statusLocked.withValues(alpha: 0.12),
              side: BorderSide(
                color: AppColors.statusLocked.withValues(alpha: 0.35),
              ),
            ),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.statusLocked,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifMeta {
  const _NotifMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 36,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum ada notifikasi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
