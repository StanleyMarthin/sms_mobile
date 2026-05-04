/// Centralized API endpoint definitions matching the Mobile API Contract.
///
/// Each micro-service runs on its own IP:port on the VPS.
/// All constants return full absolute URLs so ApiClient doesn't need a baseUrl.
abstract class ApiEndpoints {
  static const _host = '108.136.189.225';

  // ── Service Base URLs ──────────────────────────────────────
  static const _splashBase = 'http://$_host:8080';
  static const _loginBase = 'http://$_host:8085';
  static const _tasksBase = 'http://$_host:8086/sm';
  static const _jobPlanBase = 'http://$_host:8083/sm';
  static const _qcBase = 'http://$_host:8088/sm';
  static const _woBase = 'http://$_host:8093/sm';
  static const _prBase = 'http://$_host:8096/sm';
  static const _countdownBase = 'http://$_host:8090/sm';
  static const _warehouseBase = 'http://$_host:8091/sm';

  /// Used by ApiClient only if it needs a single baseUrl (kept for compat).
  static const baseUrl = _loginBase;

  // ── Auth ──────────────────────────────────────────────────
  static const deviceInit = '$_splashBase/sm/auth/device-init';

  /// NOTE: login endpoint uses /api/v1 prefix (different from other services).
  static const login = '$_loginBase/api/v1/auth/login';
  static const refresh = '$_loginBase/api/v1/auth/refresh';

  // ── Tasks (sm_tasks) ─────────────────────────────────────
  static const tasks = '$_tasksBase/tasks';
  static const taskStart = '$_tasksBase/tasks'; // action=start POST
  static const taskSubmit = '$_tasksBase/tasks'; // action=submit PUT
  static const taskAssign = '$_tasksBase/tasks';
  static const taskCheckpoint = '$_tasksBase/tasks';
  static const tasksUploadTicket = '$_tasksBase/tasks/upload-ticket';

  // ── Job Plans (sm_job_plan) ──────────────────────────────
  static const jobPlans = '$_jobPlanBase/job-plans';
  static const jobPlanDropdowns = '$_jobPlanBase/job-plans/dropdowns';
  static const jobPlanDropdownUsers = '$_jobPlanBase/job-plans/dropdowns/users';

  // ── QC (sm_job_QC) ───────────────────────────────────────
  static const qc = '$_qcBase/qc';
  static const qcMonitoring = '$_qcBase/qc/monitoring';
  static const qcUploadTicket = '$_qcBase/qc/upload-ticket';

  // ── Work Orders (sm_wo) ──────────────────────────────────
  // POST action=create|approve|reject
  static const workOrders = '$_woBase/wo';
  // POST action=request-dl|approve-dl|reject-dl|request-hours|...
  static const workOrderExtensions = '$_woBase/wo/extensions';
  // GET detail by ID
  static String workOrderById(String id) => '$_woBase/wo/$id';

  // ── PR (sm_pr) ────────────────────────────────────────────
  static const pr = '$_prBase/pr';
  static String prFinalize(String reqId) => '$_prBase/pr/$reqId/finalize';

  // ── WOV (sm_pr service, separate route) ───────────────────
  static const wov = '$_prBase/wov';
  static String wovFinalize(String reqId) => '$_prBase/wov/$reqId/finalize';

  // ── Countdown (sm_countdown) ─────────────────────────────
  static const countdown = '$_countdownBase/countdown';
  static const countdownAction = '$_countdownBase/countdown/action';
  static const countdownRevision = '$_countdownBase/countdown/revision';

  // ── Warehouse (sm_warehouse) ─────────────────────────────
  static const warehouse = '$_warehouseBase/warehouse';
  static const warehouseLogs = '$_warehouseBase/warehouse/logs';
  static const warehouseMyItems = '$_warehouseBase/warehouse/my-items';
  static const warehousePendingApproval =
      '$_warehouseBase/warehouse/pending-approval';
  static const warehouseStockCard = '$_warehouseBase/warehouse/stock-card';
  static const warehouseStorageLocations =
      '$_warehouseBase/warehouse/storage-locations';
  static const warehouseItemsSearch = '$_warehouseBase/warehouse/items/search';
  static const warehouseUploadTicket =
      '$_warehouseBase/warehouse/upload-ticket';

  // ── Monitoring ────────────────────────────────────────────
  /// Monitoring data comes from QC service.
  static const monitoringCars = '$_qcBase/qc/monitoring';
  static String monitoringCarDivisions(String carId) =>
      '$_qcBase/qc/monitoring/$carId/divisions';

  // ── Notifications & Profile ───────────────────────────────
  static const notifications = '$_loginBase/api/v1/notifications';
  static const userProfile = '$_loginBase/api/v1/users/profile';
}
