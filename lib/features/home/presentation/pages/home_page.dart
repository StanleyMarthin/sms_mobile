import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/notification_inbox_service.dart';
import '../../../../core/session/session_manager.dart';

/// Grid-style home menu page — first screen after login.
///
/// Shows a greeting, role badge, and a 3-column grid of menu items.
/// Menu items are role-specific:
/// - **Mechanic**: task-execution focused menus
/// - **KD/ADV/PM**: supervisory / management menus
///
/// Layout modelled after PowerOperation-style dashboard.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final menus = _buildMenusForRole(session.role);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header Bar ─────────────────────────────────
              _buildHeader(context),

              // ── Body ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      _buildGreeting(session),
                      const SizedBox(height: 24),

                      // Menu Utama label
                      const Text(
                        'Menu Utama',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3-column menu grid
                      _buildGrid(context, menus),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Keluar Aplikasi?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text('Apakah Anda yakin ingin keluar?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Use SystemNavigator to properly exit
              // ignore: avoid_classes_with_only_static_members
              SystemNavigator.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusLocked,
            ),
            child: const Text('Keluar',
                style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ── Top header bar ──────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1608), Color(0xFF131008)],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // App logo / icon
          ClipOval(
            child: Image.asset(
              'assets/images/sm.jpeg',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Stanley Marthin System',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const _NotificationBell(),
        ],
      ),
    );
  }

  // ── Greeting card ───────────────────────────────────────
  Widget _buildGreeting(SessionManager session) {
    final name = session.fullName ?? 'User';
    // Use jabatan from BE login response; fallback to role-based label.
    final role = session.jabatan ??
        switch (session.role) {
          'kd' => 'Kepala Divisi',
          'pm' => 'Project Manager',
          'adv' => 'Advisor',
          _ => 'Operator / Lapangan',
        };
    final div = session.divisionName ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang, $name',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _roleBadge(role),
                if (div.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    div,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Logout
          Builder(
            builder: (ctx) => InkWell(
              onTap: () {
                sl<SessionManager>().logout();
                GoRouter.of(ctx).go('/login');
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.statusLocked.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusLocked,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
        ),
      ),
    );
  }

  // ── 3-column grid ───────────────────────────────────────
  Widget _buildGrid(BuildContext context, List<_MenuItem> menus) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final item = menus[index];
        return _MenuTile(item: item);
      },
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell>
    with WidgetsBindingObserver {
  late final NotificationInboxService _inbox;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inbox = sl<NotificationInboxService>();
    _inbox.ensureLoaded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inbox.ensureLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _inbox,
      builder: (context, _) {
        final unreadCount = _inbox.unreadCount;
        return IconButton(
          onPressed: () async {
            await _inbox.markAllRead();
            if (!context.mounted) return;
            context.push('/notifications');
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AppColors.gold,
                size: 22,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusLocked,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.background,
                        width: 1.2,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.gold.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Menu Tile Widget
// ═══════════════════════════════════════════════════════════════
class _MenuTile extends StatelessWidget {
  final _MenuItem item;

  const _MenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.route != null) {
            context.push(item.route!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.label} — Coming soon'),
                backgroundColor: AppColors.surfaceCard,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: item.color.withValues(alpha: 0.25)),
                ),
                child: Icon(item.icon, size: 22, color: item.color),
              ),
              const SizedBox(height: 8),
              // Label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Menu Item Model
// ═══════════════════════════════════════════════════════════════
class _MenuItem {
  final IconData icon;
  final String label;
  final String? route;
  final Color color;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.route,
    this.color = AppColors.gold,
  });
}

// ═══════════════════════════════════════════════════════════════
// RBAC-driven menu builder
// ═══════════════════════════════════════════════════════════════
List<_MenuItem> _buildMenusForRole(String? role) {
  final perms = getPermissions(role);
  final menus = <_MenuItem>[];

  Color alt() => (menus.length % 2 == 0) ? AppColors.gold : AppColors.orange;

  // ══════════════════════════════════════════════════════════
  // Lapangan / Mechanic: menus map to 5-tab bottom-nav layout
  // ══════════════════════════════════════════════════════════
  if (perms.contains(Permission.dashboardMechanic)) {
    menus.add(_MenuItem(
      icon: Icons.assignment,
      label: 'Tugas',
      route: '/tasks',
      color: alt(),
    ));
    menus.add(_MenuItem(
      icon: Icons.more_time_outlined,
      label: 'Lembur',
      route: '/overtime',
      color: alt(),
    ));
    menus.add(_MenuItem(
      icon: Icons.inventory_2_outlined,
      label: 'Warehouse',
      route: '/warehouse',
      color: alt(),
    ));
    menus.add(_MenuItem(
      icon: Icons.person_outline_rounded,
      label: 'Profil',
      route: '/profile',
      color: alt(),
    ));

    return menus;
  }

  // ══════════════════════════════════════════════════════════
  // KD / Advisor / PM: feature menus directly from Home
  // ══════════════════════════════════════════════════════════

  if (perms.contains(Permission.taskView)) {
    menus.add(_MenuItem(
      icon: Icons.checklist_outlined,
      label: 'Tugas',
      route: '/tasks',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.taskView)) {
    menus.add(_MenuItem(
      icon: Icons.more_time_outlined,
      label: 'Lembur',
      route: '/overtime',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.jobPlanCreate) ||
      perms.contains(Permission.jobPlanReview) ||
      perms.contains(Permission.jobPlanUpdate)) {
    menus.add(_MenuItem(
      icon: Icons.event_note_outlined,
      label: 'Plan',
      route: '/plans',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.unitsView) ||
      perms.contains(Permission.countdownView)) {
    menus.add(_MenuItem(
      icon: Icons.directions_car_outlined,
      label: 'Countdown',
      route: '/countdown',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.monitoringView)) {
    menus.add(_MenuItem(
      icon: Icons.monitor_outlined,
      label: 'Monitoring',
      route: '/monitoring',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.qcSubmit) ||
      perms.contains(Permission.qcValidate) ||
      perms.contains(Permission.qcView)) {
    menus.add(_MenuItem(
      icon: Icons.verified_outlined,
      label: 'QC',
      route: '/qc',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.woCreate) ||
      perms.contains(Permission.woView)) {
    menus.add(_MenuItem(
      icon: Icons.assignment_outlined,
      label: 'Work\nOrder',
      route: '/work-orders',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.warehouseApprove) ||
      perms.contains(Permission.warehouseRequest) ||
      perms.contains(Permission.warehouseLogsView)) {
    menus.add(_MenuItem(
      icon: Icons.inventory_2_outlined,
      label: 'Warehouse',
      route: '/warehouse',
      color: alt(),
    ));
  }

  if (perms.contains(Permission.prView)) {
    menus.add(_MenuItem(
      icon: Icons.shopping_cart_outlined,
      label: 'Purchase\nRequest',
      route: '/pr',
      color: alt(),
    ));
  }

  // ── Profil (PROFILE_VIEW) ──
  if (perms.contains(Permission.profileView)) {
    menus.add(_MenuItem(
      icon: Icons.person_outline_rounded,
      label: 'Profil',
      route: '/profile',
      color: alt(),
    ));
  }

  return menus;
}
