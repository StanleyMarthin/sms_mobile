/*
Tujuan: Helper akses menu dan route Job Plan berbasis permission backend.
Caller: HomePage, app_router, dan unit test.
Dependensi: SessionManager dan Perms.
Main Functions: JobPlanAccess.
Side Effects: Tidak ada.
*/
library;

import 'package:sm_system/core/session/session_manager.dart';
import 'job_plan_navigation.dart';

abstract class JobPlanAccess {
  static bool canCreate(SessionManager session) =>
      _enabled(session) && session.hasPerm(Perms.jobPlanCreate);

  static bool canApprove(SessionManager session) =>
      _enabled(session) && session.hasPerm(Perms.jobPlanReview);

  static bool canTrack(SessionManager session) =>
      _enabled(session) &&
      session.hasAnyPerm([
        Perms.jobPlanCreate,
        Perms.jobPlanReview,
        Perms.jobPlanUpdate,
        Perms.taskView,
      ]);

  static bool canMonitor(SessionManager session) =>
      _enabled(session) &&
      session.hasAnyPerm([Perms.monitoringView, Perms.monitoringDetail]);

  static bool canExecute(SessionManager session) =>
      _enabled(session) &&
      session.hasAnyPerm([
        Perms.taskExecute,
        Perms.taskSubmit,
        Perms.taskPending,
      ]);

  static bool canOpenAny(SessionManager session) =>
      canCreate(session) ||
      canApprove(session) ||
      canTrack(session) ||
      canMonitor(session);

  static bool canOpenRoute(SessionManager session, String route) {
    if (!_enabled(session)) return false;
    final uri = Uri.parse(route);
    final canonical = Uri.parse(JobPlanNavigation.redirect(uri) ?? route).path;
    return switch (canonical) {
      '/plans/create' => canCreate(session),
      '/plans/approval' => canApprove(session),
      '/plans/monitoring' || '/plans/validation' => canMonitor(session),
      '/plans' => canOpenAny(session),
      _ => false,
    };
  }

  static bool _enabled(SessionManager session) => session.mobileEnabled;
}
