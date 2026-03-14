/// Centralized API endpoint definitions.
///
/// All endpoint paths are relative to [baseUrl].
/// Usage: `ApiEndpoints.baseUrl + ApiEndpoints.login`
abstract class ApiEndpoints {
  static const baseUrl = 'https://{host}/api/v1';

  // ── Auth ──────────────────────────────────────────────────
  static const deviceInit = '/auth/device-init';
  static const login = '/auth/login';

  // ── Tasks ─────────────────────────────────────────────────
  static const tasks = '/tasks';
  static const taskStart = '/tasks/start';
  static const taskSubmit = '/tasks/submit';
  static const taskAssign = '/tasks/assign';
  static const taskCheckpoint = '/tasks/checkpoint';

  // ── Job Plans ─────────────────────────────────────────────
  static const jobPlans = '/job-plans';
  static String jobPlanReview(String planId) => '/job-plans/$planId/review';
  static String jobPlanUpdate(String id) => '/job-plans/$id';

  // ── Countdown / Unit Progress ─────────────────────────────
  static const unitsInProgress = '/units/in-progress';
  static const countdown = '/countdown';
  static String countdownDetail(String sectionId) => '/countdown/$sectionId/detail';

  // ── QC ────────────────────────────────────────────────────
  static const qc = '/qc';
  static String qcValidate(String qcId) => '/qc/$qcId/validate';

  // ── Work Orders ───────────────────────────────────────────
  static const workOrders = '/work-orders';
  static String woApproveAdvisor(String reqId) => '/work-orders/$reqId/approve-advisor';
  static String woApprovePm(String reqId) => '/work-orders/$reqId/approve-pm';

  // ── Warehouse ─────────────────────────────────────────────
  static const warehouse = '/warehouse';
  static String warehouseApprove(String logId) => '/warehouse/$logId/approve';

  // ── Monitoring ────────────────────────────────────────────
  static const monitoringCars = '/monitoring/cars';
  static String monitoringCarDivisions(String carId) => '/monitoring/cars/$carId/divisions';

  // ── Notifications & Profile ───────────────────────────────
  static const notifications = '/notifications';
  static const userProfile = '/users/profile';
}
