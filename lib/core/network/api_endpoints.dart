/*
Tujuan: Definisi terpusat endpoint API mobile untuk gateway HTTPS dan legacy port mode.
Caller: ApiClient dan seluruh remote datasource feature.
Dependensi: AppConfig.
Main Functions: ApiEndpoints URL getters per service.
Side Effects: Tidak ada.
*/

import '../config/app_config.dart';

abstract class ApiEndpoints {
  // ── Service Base URLs ──────────────────────────────────────
  static final String _splashBase = AppConfig.serviceOrigin(8080);
  static final String _loginBase = AppConfig.serviceOrigin(8085);
  static final String _tasksBase = '${AppConfig.serviceOrigin(8086)}/sm';
  static final String _jobPlanBase = '${AppConfig.serviceOrigin(8083)}/sm';
  static final String _qcBase = '${AppConfig.serviceOrigin(8088)}/sm';
  static final String _woBase = '${AppConfig.serviceOrigin(8093)}/sm';
  static final String _prBase = '${AppConfig.serviceOrigin(8096)}/sm';
  static final String _countdownBase = '${AppConfig.serviceOrigin(8090)}/sm';
  static final String _warehouseBase = '${AppConfig.serviceOrigin(8091)}/sm';
  static final String _systemApiBase = '${AppConfig.serviceOrigin(8085)}/api';

  /// Used by ApiClient only if it needs a single baseUrl (kept for compat).
  static String get baseUrl => _loginBase;

  // ── Auth ──────────────────────────────────────────────────
  static String get deviceInit => '$_splashBase/sm/auth/device-init';

  /// NOTE: login endpoint uses /api/v1 prefix (different from other services).
  static String get login => '$_loginBase/api/v1/auth/login';
  static String get refresh => '$_loginBase/api/v1/auth/refresh';

  // ── Tasks (sm_tasks) ─────────────────────────────────────
  static String get tasks => '$_tasksBase/tasks';
  static String get taskStart => '$_tasksBase/tasks';
  static String get taskSubmit => '$_tasksBase/tasks';
  static String get taskAssign => '$_tasksBase/tasks';
  static String get taskCheckpoint => '$_tasksBase/tasks';
  static String get tasksUploadTicket => '$_tasksBase/tasks/upload-ticket';

  // ── Job Plans (sm_job_plan) ──────────────────────────────
  static String get jobPlans => '$_jobPlanBase/job-plans';
  static String get jobPlanDropdowns => '$_jobPlanBase/job-plans/dropdowns';
  static String get jobPlanDropdownUsers =>
      '$_jobPlanBase/job-plans/dropdowns/users';

  // ── QC (sm_job_QC) ───────────────────────────────────────
  static String get qc => '$_qcBase/qc';
  static String get qcMonitoring => '$_qcBase/qc/monitoring';
  static String get qcUploadTicket => '$_qcBase/qc/upload-ticket';

  // ── Work Orders (sm_wo) ──────────────────────────────────
  // POST action=create|approve|reject
  static String get workOrders => '$_woBase/wo';
  // POST action=request-dl|approve-dl|reject-dl|request-hours|...
  static String get workOrderExtensions => '$_woBase/wo/extensions';
  // GET detail by ID
  static String workOrderById(String id) => '$_woBase/wo/$id';

  // ── PR (sm_pr) ────────────────────────────────────────────
  static String get pr => '$_prBase/pr';
  static String prDetail(String reqId) => '$_prBase/pr/$reqId';

  // ── WOV (sm_pr service, separate route) ───────────────────
  static String get wov => '$_prBase/wov';
  static String wovDetail(String reqId) => '$_prBase/wov/$reqId';

  // ── Countdown (sm_countdown) ─────────────────────────────
  static String get countdown => '$_countdownBase/countdown';
  static String get countdownAction => '$_countdownBase/countdown/action';
  static String get countdownRevision => '$_countdownBase/countdown/revision';
  static String unitCatalog(String unitId) =>
      '$_countdownBase/units/$unitId/catalog';
  static String unitCatalogReference(String unitId, int referenceId) =>
      '$_countdownBase/units/$unitId/catalog/$referenceId';
  static String unitCatalogReferenceMedia(String unitId, int referenceId) =>
      '$_countdownBase/units/$unitId/catalog/$referenceId/media';
  static String unitCatalogItem(String unitId, int itemId) =>
      '$_countdownBase/units/$unitId/catalog/items/$itemId';
  static String unitCatalogItemSurvey(String unitId, int itemId) =>
      '$_countdownBase/units/$unitId/catalog/items/$itemId/survey';
  static String unitCatalogItemSurveyConfirm(String unitId, int itemId) =>
      '$_countdownBase/units/$unitId/catalog/items/$itemId/survey/confirm';
  static String unitCatalogItemMedia(String unitId, int itemId) =>
      '$_countdownBase/units/$unitId/catalog/items/$itemId/media';
  static String unitCatalogItemMediaDetail(
    String unitId,
    int itemId,
    int mediaId,
  ) => '$_countdownBase/units/$unitId/catalog/items/$itemId/media/$mediaId';
  static String unitCatalogItemPromote(String unitId, int itemId) =>
      '$_countdownBase/units/$unitId/catalog/items/$itemId/promote';
  static String get catalogComponents => '$_systemApiBase/catalog/components';
  static String unitCatalogOpenPanel(String unitId) =>
      '$_systemApiBase/units/$unitId/catalog';
  static String unitCatalogPanelItemsBatch(String unitId, int panelId) =>
      '$_systemApiBase/units/$unitId/catalog/$panelId/items';
  static String unitCatalogPanelMedia(String unitId, int panelId) =>
      '$_systemApiBase/units/$unitId/catalog/$panelId/media';
  static String unitMasterPanel(String unitId, int panelId) =>
      '$_countdownBase/units/$unitId/master-panels/$panelId';
  static String unitMasterPanelJobdescs(String unitId, int panelId) =>
      '$_countdownBase/units/$unitId/master-panels/$panelId/jobdescs';

  // ── Warehouse (sm_warehouse) ─────────────────────────────
  static String get warehouse => '$_warehouseBase/warehouse';
  static String get warehouseLogs => '$_warehouseBase/warehouse/logs';
  static String get warehouseMyItems => '$_warehouseBase/warehouse/my-items';
  static String get warehousePendingApproval =>
      '$_warehouseBase/warehouse/pending-approval';
  static String get warehouseStockCard =>
      '$_warehouseBase/warehouse/stock-card';
  static String get warehouseStorageLocations =>
      '$_warehouseBase/warehouse/storage-locations';
  static String get warehouseItemsSearch =>
      '$_warehouseBase/warehouse/items/search';
  static String get warehouseMatchItem =>
      '$_warehouseBase/warehouse/match-item';
  static String get warehouseUploadTicket =>
      '$_warehouseBase/warehouse/upload-ticket';

  // ── Monitoring ────────────────────────────────────────────
  /// Monitoring data comes from QC service.
  static String get monitoringCars => '$_qcBase/qc/monitoring';
  static String monitoringCarDivisions(String carId) =>
      '$_qcBase/qc/monitoring/$carId/divisions';

  // ── Notifications & Profile ───────────────────────────────
  static String get notifications => '$_loginBase/api/v1/notifications';
  static String get userProfile => '$_loginBase/api/v1/users/profile';
  static String get notifySend => '$_loginBase/sm/notify/send';
}
