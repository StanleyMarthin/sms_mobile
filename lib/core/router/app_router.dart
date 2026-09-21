/*
Tujuan: Routing utama aplikasi mobile.
Caller: App bootstrap dan navigasi internal/notification.
Dependensi: GoRouter, SessionManager, FeatureShellPage, halaman fitur.
Main Functions: createRouter.
Side Effects: Menginisialisasi global appRouter.
*/

import 'package:flutter/widgets.dart';
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
import '../../features/qc/presentation/pages/qc_v2_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/job_plan/presentation/pages/job_plan_detail_page.dart';
import '../../features/job_plan/presentation/pages/job_plan_page.dart';
import '../../features/job_plan/presentation/utils/job_plan_navigation.dart';
import '../../features/job_plan/presentation/pages/job_plan_monitoring_page.dart';
import '../../features/job_plan/presentation/pages/job_plan_validation_page.dart';
import '../../features/job_plan/presentation/utils/job_plan_access.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/pr/presentation/pages/pr_page.dart';
import '../../features/wov/presentation/pages/wov_page.dart';
import '../../features/task_execution/presentation/pages/task_section_page.dart';
import '../../features/task_execution/presentation/pages/alarm_page.dart';
import '../../features/warehouse_request/presentation/pages/warehouse_request_page.dart';
import '../../features/work_order/presentation/pages/work_order_page.dart';
import '../../features/unit_preparation/presentation/pages/unit_preparation_page.dart';

/// Top-level GoRouter instance — diakses oleh FCMService untuk navigasi dari notifikasi.
late GoRouter appRouter;

/// Creates and assigns the GoRouter instance for declarative navigation.
GoRouter createRouter() {
  appRouter = GoRouter(
    initialLocation: '/splash',
    refreshListenable: sl<SessionManager>(),
    redirect: (context, state) {
      final session = sl<SessionManager>();
      final isLoggedIn = session.isLoggedIn;
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;

      if (!isLoggedIn) {
        // Jika belum login dan tidak punya tempToken, wajib ke splash dulu
        if (session.tempToken == null) return '/splash';

        // Jika sudah punya tempToken tapi bukan di halaman login, arahkan ke login
        if (loc != '/login') return '/login';
      } else {
        // Jika sudah login tapi mencoba ke halaman login atau splash, arahkan ke home
        if (loc == '/login' || loc == '/splash') return '/home';
      }

      final jobPlanRedirect = JobPlanNavigation.redirect(state.uri);
      if (jobPlanRedirect != null) return jobPlanRedirect;
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => HomePage()),
      GoRoute(path: '/dashboard', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/job-plans/v2',
        redirect: (_, state) => JobPlanNavigation.redirect(state.uri),
      ),
      GoRoute(
        path: '/job-plans/v2/:section',
        redirect: (_, state) => JobPlanNavigation.redirect(state.uri),
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
        builder: (context, state) => _jobPlanShell(
          route: '/plans',
          title: 'Job Plan',
          child: JobPlanPage(
            initialTab: state.uri.queryParameters['tab'],
            initialDate: _parseDate(state.uri.queryParameters['date']),
            initialSourceType:
                state.uri.queryParameters['source'] ??
                (state.uri.queryParameters['coreId'] == null
                    ? null
                    : 'COUNTDOWN'),
            initialSourceRefId:
                state.uri.queryParameters['sourceRefId'] ??
                state.uri.queryParameters['coreId'],
            divisionId: state.uri.queryParameters['divisionId'],
            unitId: state.uri.queryParameters['unitId'],
            employeeId: state.uri.queryParameters['employeeId'],
            approvalState: state.uri.queryParameters['approvalState'],
            executionState: state.uri.queryParameters['executionState'],
            autoOpenCreate: state.uri.queryParameters['autoOpenCreate'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/plans/create',
        redirect: (context, state) => Uri(
          path: '/plans',
          queryParameters: {
            ...state.uri.queryParameters,
            'autoOpenCreate': '1',
          },
        ).toString(),
      ),
      GoRoute(
        path: '/plans/approval',
        redirect: (context, state) => '/plans?tab=approval',
      ),
      GoRoute(
        path: '/plans/monitoring',
        builder: (context, state) => _jobPlanShell(
          route: '/plans/monitoring',
          title: 'Job Monitoring',
          child: const JobPlanMonitoringPage(),
        ),
      ),
      GoRoute(
        path: '/plans/validation',
        builder: (context, state) => _jobPlanShell(
          route: '/plans/validation',
          title: 'Final Validation',
          child: const JobPlanValidationPage(),
        ),
      ),
      GoRoute(
        path: '/job-plan/:id',
        builder: (context, state) => FeatureShellPage(
          title: 'Job Plan',
          child: JobPlanDetailPage(planId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/countdown',
        builder: (context, state) => FeatureShellPage(
          title: 'Countdown',
          child: CountdownPage(focusCarId: state.uri.queryParameters['carId']),
        ),
      ),
      GoRoute(
        path: '/unit-preparation',
        builder: (context, state) => FeatureShellPage(
          title: 'Persiapan Unit',
          child: UnitPreparationPage(
            initialUnitId: state.uri.queryParameters['unitId'],
            initialUnitName: state.uri.queryParameters['unitName'],
            initialCustomerName: state.uri.queryParameters['customerName'],
          ),
        ),
      ),
      GoRoute(
        path: '/monitoring',
        builder: (context, state) => FeatureShellPage(
          title: 'Monitoring',
          child: MonitoringPage(focusCarId: state.uri.queryParameters['carId']),
        ),
      ),
      GoRoute(
        path: '/qc',
        builder: (context, state) => FeatureShellPage(
          title: 'QC',
          child: QcTab(focusCoreId: state.uri.queryParameters['qcId']),
        ),
      ),
      GoRoute(
        path: '/qc/v2',
        builder: (context, state) =>
            const FeatureShellPage(title: 'QC V2', child: QcV2QueuePage()),
      ),
      GoRoute(
        path: '/work-orders',
        builder: (context, state) => FeatureShellPage(
          title: 'Work Order',
          child: WorkOrderPage(focusWoId: state.uri.queryParameters['woId']),
        ),
      ),
      GoRoute(
        path: '/warehouse',
        builder: (context, state) =>
            FeatureShellPage(title: 'Warehouse', child: WarehouseRequestPage()),
      ),
      GoRoute(
        path: '/pr',
        builder: (context, state) => FeatureShellPage(
          title: 'Purchase Request',
          child: PrPage(focusReqId: state.uri.queryParameters['reqId']),
        ),
      ),
      GoRoute(
        path: '/wov',
        builder: (context, state) => FeatureShellPage(
          title: 'Work Order Vendor',
          child: WovPage(focusReqId: state.uri.queryParameters['reqId']),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            FeatureShellPage(title: 'Notifikasi', child: NotificationsPage()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            FeatureShellPage(title: 'Profil', child: ProfilePage()),
      ),
      GoRoute(
        path: '/alarm',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AlarmPage(
            title: extra['title'] ?? 'Alarm',
            message: extra['message'] ?? '',
            isCritical: extra['isCritical'] == true,
          );
        },
      ),
    ],
  );
  return appRouter;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

FeatureShellPage _jobPlanShell({
  required String route,
  required String title,
  required Widget child,
}) {
  final session = sl<SessionManager>();
  return FeatureShellPage(
    title: title,
    child: JobPlanAccess.canOpenRoute(session, route)
        ? child
        : const Center(child: Text('Akses Job Plan tidak tersedia')),
  );
}
