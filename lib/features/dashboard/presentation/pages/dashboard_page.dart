import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/rbac.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../countdown/presentation/pages/countdown_page.dart';
import '../../../job_plan/presentation/pages/job_plan_page.dart';
import '../../../monitoring/presentation/pages/monitoring_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../qc/presentation/pages/qc_page.dart';
import '../../../warehouse_request/presentation/pages/warehouse_request_page.dart';
import '../../../work_order/presentation/pages/work_order_page.dart';
import '../../../task_execution/presentation/pages/tasks_page.dart';
import 'operator_dashboard_overview_page.dart';

/// Unified dashboard page — role-adaptive via RBAC.
///
/// For KD/Advisor/PM → top TabBar with contract-aligned feature tabs.
/// For Operator/Lapangan → bottom navigation with dashboard, tasks,
/// warehouse, notifications, and profile.
class DashboardPage extends StatefulWidget {
  final int initialTab;
  const DashboardPage({super.key, this.initialTab = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final SessionManager _session;
  late final List<_DashTab> _tabs;

  // KD-style uses TabController; mechanic uses bottom nav index
  TabController? _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _session = sl<SessionManager>();
    _tabs = _buildTabs();

    if (_useTopTabs) {
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, _tabs.length - 1),
      );
    } else {
      _currentIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Roles with dashboardKd use top tabs; mechanic uses bottom nav.
  bool get _useTopTabs => hasPermission(_session.role, Permission.dashboardKd);

  /// Build the list of tabs based on the user's role permissions.
  List<_DashTab> _buildTabs() {
    final role = _session.role;

    // ══════════════════════════════════════════════════════
    // Lapangan / Mechanic: 5 fixed bottom-nav tabs
    // ══════════════════════════════════════════════════════
    if (hasPermission(role, Permission.dashboardMechanic)) {
      return _buildLapanganTabs();
    }

    // ══════════════════════════════════════════════════════
    // KD / Advisor / PM: dynamic top-tab dashboard
    // ══════════════════════════════════════════════════════
    return _buildManagementTabs(role);
  }

  /// Build the 5 Lapangan bottom-nav tabs.
  ///
  /// 1. Tugas — today's normal tasks (isOvertime=false)
  /// 2. Lembur — overtime tasks (isOvertime=true)
  /// 3. Peminjaman — warehouse tool/material request & return
  /// 4. Laporan — work report / logbook history
  /// 5. Profil — user info, permissions, logout
  List<_DashTab> _buildLapanganTabs() {
    return [
      _DashTab(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        builder: () => const OperatorDashboardOverviewPage(),
      ),
      _DashTab(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'Tugas',
        builder: () => const TasksPage(),
      ),
      _DashTab(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'Gudang',
        builder: () => const WarehouseRequestPage(),
      ),
      _DashTab(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'Notif',
        builder: () => const NotificationsPage(),
      ),
      _DashTab(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        builder: () => const ProfilePage(),
      ),
    ];
  }

  /// Build dynamic management (KD/Advisor/PM) tabs.
  List<_DashTab> _buildManagementTabs(String? role) {
    final tabs = <_DashTab>[];

    if (hasPermission(role, Permission.monitoringView)) {
      tabs.add(_DashTab(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        builder: () => const MonitoringPage(),
      ));
    }

    if (hasPermission(role, Permission.unitsView) ||
        hasPermission(role, Permission.countdownView)) {
      tabs.add(_DashTab(
        icon: Icons.directions_car_outlined,
        activeIcon: Icons.directions_car,
        label: 'Units',
        builder: () => const CountdownPage(),
      ));
    }

    if (hasPermission(role, Permission.taskView)) {
      tabs.add(_DashTab(
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist,
        label: 'Tasks',
        builder: () => const TasksPage(),
      ));
    }

    if (hasPermission(role, Permission.jobPlanCreate) ||
        hasPermission(role, Permission.jobPlanReview) ||
        hasPermission(role, Permission.jobPlanUpdate)) {
      tabs.add(_DashTab(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note,
        label: 'Job Plan',
        builder: () => const JobPlanPage(),
      ));
    }

    if (hasPermission(role, Permission.qcSubmit) ||
        hasPermission(role, Permission.qcValidate) ||
        hasPermission(role, Permission.qcView)) {
      tabs.add(_DashTab(
        icon: Icons.verified_outlined,
        activeIcon: Icons.verified,
        label: 'QC',
        builder: () => const QcTab(),
      ));
    }

    if (hasPermission(role, Permission.woCreate) ||
        hasPermission(role, Permission.woView)) {
      tabs.add(_DashTab(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        label: 'WO',
        builder: () => const WorkOrderPage(),
      ));
    }

    if (hasPermission(role, Permission.warehouseApprove) ||
        hasPermission(role, Permission.warehouseRequest) ||
        hasPermission(role, Permission.warehouseLogsView)) {
      tabs.add(_DashTab(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'Warehouse',
        builder: () => const WarehouseRequestPage(),
      ));
    }

    if (hasPermission(role, Permission.notificationsView)) {
      tabs.add(_DashTab(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'Notif',
        builder: () => const NotificationsPage(),
      ));
    }

    // ── Profil (PROFILE_VIEW) ──
    if (hasPermission(role, Permission.profileView)) {
      tabs.add(_DashTab(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        builder: () => const ProfilePage(),
      ));
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _useTopTabs ? _buildTopTabBody() : _buildBottomNavBody(),
      bottomNavigationBar: _useTopTabs ? null : _buildBottomNav(),
    );
  }

  // ── App Bar ──────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    // Use jabatan from BE login response; fallback to role-based label.
    final roleName = _session.jabatan ?? switch (_session.role) {
      'kd' => 'Kepala Divisi',
      'pm' => 'Project Manager',
      'adv' => 'Advisor',
      _ => 'Operator / Lapangan',
    };

    return AppBar(
      backgroundColor: AppColors.surfaceCard,
      title: Column(
        children: [
          Text(
            _session.fullName ?? roleName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
          Text(
            roleName,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          Text(
            _session.divisionName ?? '',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: AppColors.gold),
        tooltip: 'Kembali ke Home',
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded,
              color: AppColors.textSecondary, size: 22),
          tooltip: 'Logout',
          onPressed: () {
            _session.logout();
            context.go('/login');
          },
        ),
      ],
      bottom: _useTopTabs ? _buildTabBar() : _buildDivider(),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(49),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AppColors.border),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.gold,
            indicatorWeight: 2,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textDisabled,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            tabAlignment: TabAlignment.start,
            tabs: _tabs
                .map((t) => Tab(
                      height: 40,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon, size: 16),
                          const SizedBox(width: 4),
                          Text(t.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDivider() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppColors.border),
    );
  }

  // ── Top Tab Body (KD/Advisor/PM) ─────────────────────────
  Widget _buildTopTabBody() {
    return TabBarView(
              key: const PageStorageKey("dashboardTab"),
      controller: _tabController,
      children: _tabs.map((t) => t.builder()).toList(),
    );
  }

  // ── Bottom Nav Body (Mechanic) ───────────────────────────
  Widget _buildBottomNavBody() {
    return IndexedStack(
      index: _currentIndex,
      children: _tabs.map((t) => t.builder()).toList(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceNav,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _tabs.length,
              (i) => _navItem(i, _tabs[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, _DashTab tab) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? tab.activeIcon : tab.icon,
              size: 24,
              color: isActive ? AppColors.gold : AppColors.textDisabled,
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppColors.gold : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal tab descriptor with lazy builder to avoid constructing
/// widgets before they are displayed.
class _DashTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget Function() builder;

  const _DashTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.builder,
  });
}
