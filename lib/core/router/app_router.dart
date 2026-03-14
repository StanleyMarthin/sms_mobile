import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../presentation/feature_shell_page.dart';
import '../session/session_manager.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/countdown/presentation/pages/countdown_page.dart';
import '../../features/monitoring/presentation/pages/monitoring_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/qc/presentation/pages/qc_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/task_execution/presentation/pages/task_section_page.dart';
import '../../features/warehouse_request/presentation/pages/warehouse_request_page.dart';
import '../../features/work_order/presentation/pages/work_order_page.dart';

/// Creates the GoRouter instance for declarative navigation.
///
/// Routes:
/// - /splash       → Splash screen
/// - /login        → Login page
/// - /home         → Grid home menu (role-adaptive via RBAC)
/// Flow: splash → login → /home → tap menu → direct feature page
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = sl<SessionManager>();
      final isLoggedIn = session.isLoggedIn;
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;

      final isLoginRoute = loc == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, state) => FeatureShellPage(
          title: 'Tugas',
          child: TaskSectionPage(
            kind: TaskSectionKind.tasks,
            focusTaskId: state.uri.queryParameters['taskId'],
            initialDate: _parseDate(state.uri.queryParameters['date']),
          ),
        ),
      ),
      GoRoute(
        path: '/overtime',
        builder: (context, state) => FeatureShellPage(
          title: 'Lembur',
          child: TaskSectionPage(
            kind: TaskSectionKind.overtime,
            focusTaskId: state.uri.queryParameters['taskId'],
            initialDate: _parseDate(state.uri.queryParameters['date']),
          ),
        ),
      ),
      GoRoute(
        path: '/plans',
        builder: (context, state) => FeatureShellPage(
          title: 'Plan',
          child: TaskSectionPage(
            kind: TaskSectionKind.plan,
            initialDate: _parseDate(state.uri.queryParameters['date']),
            planSourceType: state.uri.queryParameters['source'],
            planSourceRefId: state.uri.queryParameters['sourceRefId'],
            planAutoOpenCreate: state.uri.queryParameters['autoOpenCreate'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/countdown',
        builder: (context, state) => FeatureShellPage(
          title: 'Countdown',
          child: CountdownPage(
            focusCarId: state.uri.queryParameters['carId'],
          ),
        ),
      ),
      GoRoute(
        path: '/monitoring',
        builder: (context, state) => FeatureShellPage(
          title: 'Monitoring',
          child: MonitoringPage(
            focusCarId: state.uri.queryParameters['carId'],
          ),
        ),
      ),
      GoRoute(
        path: '/qc',
        builder: (context, state) => FeatureShellPage(
          title: 'QC',
          child: QcTab(
            focusQcId: state.uri.queryParameters['qcId'],
            initialDate: _parseDate(state.uri.queryParameters['date']),
          ),
        ),
      ),
      GoRoute(
        path: '/work-orders',
        builder: (context, state) => FeatureShellPage(
          title: 'Work Order',
          child: WorkOrderPage(
            focusWorkOrderId: state.uri.queryParameters['woId'],
          ),
        ),
      ),
      GoRoute(
        path: '/warehouse',
        builder: (context, state) => const FeatureShellPage(
          title: 'Warehouse',
          child: WarehouseRequestPage(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const FeatureShellPage(
          title: 'Notifikasi',
          child: NotificationsPage(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const FeatureShellPage(
          title: 'Profil',
          child: ProfilePage(),
        ),
      ),
    ],
  );
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
