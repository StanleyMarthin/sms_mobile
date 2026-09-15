/*
Tujuan: Helper akses menu dan route Job Plan V2 berbasis permission backend.
Caller: HomePage, app_router, dan unit test.
Dependensi: SessionManager dan Perms.
Main Functions: JobPlanV2Access.
Side Effects: Tidak ada.
*/
library;

import 'package:sm_system/core/session/session_manager.dart';

abstract class JobPlanV2Access {
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

  static bool canOpenAny(SessionManager session) =>
      canCreate(session) ||
      canApprove(session) ||
      canTrack(session) ||
      canMonitor(session);

  static bool canOpenRoute(SessionManager session, String route) {
    if (!_enabled(session)) return false;
    return switch (route) {
      '/job-plans/v2/create' => canCreate(session),
      '/job-plans/v2/approval' => canApprove(session),
      '/job-plans/v2/monitoring' ||
      '/job-plans/v2/validation' => canMonitor(session),
      '/job-plans/v2' ||
      '/job-plans/v2/calendar' ||
      '/job-plans/v2/approval-tracking' => canOpenAny(session),
      _ => true,
    };
  }

  static bool _enabled(SessionManager session) => session.mobileEnabled;
}
