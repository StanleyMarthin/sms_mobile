/*
Tujuan: RBAC mobile untuk role legacy dan permission backend.
Caller: HomePage, RoleGuard, dan fitur yang hide/show action berbasis permission.
Dependensi: GetIt injection dan SessionManager.
Main Functions: UserRole, Permission, hasPermission(), getPermissions().
Side Effects: Membaca session aktif dari service locator.
*/

import '../di/injection.dart';
import '../session/session_manager.dart';

/// Canonical role buckets for legacy guard compatibility.
enum UserRole {
  op,
  kd,
  adv,
  pm;

  static UserRole? fromString(String? value) {
    if (value == null) return null;
    return switch (_normalizeRole(value)) {
      'op' || 'team_lapangan' || 'field' => UserRole.op,
      'kd' || 'ketua_divisi' || 'kepala_divisi' => UserRole.kd,
      'adv' || 'advisor' => UserRole.adv,
      'kp' ||
      'pm' ||
      'mp' ||
      'global' ||
      'manager_produksi' ||
      'kepala_produksi' ||
      'manager_operational' ||
      'admin' ||
      'mis' => UserRole.pm,
      _ => null,
    };
  }

  static UserRole? fromSession(SessionManager session) {
    final bucket = (session.accessBucket ?? '').trim().toUpperCase();
    switch (bucket) {
      case 'FIELD':
        return UserRole.op;
      case 'KD':
        return UserRole.kd;
      case 'ADV':
        return UserRole.adv;
      case 'KP':
      case 'GLOBAL':
        return UserRole.pm;
      default:
        return fromString(session.rawRoleName ?? session.role);
    }
  }
}

enum Permission {
  jobPlanCreate,
  jobPlanReview,
  jobPlanUpdate,
  woCreate,
  woApproveAdvisor,
  woApprovePm,
  woReject,
  woExtensionRequest,
  woExtensionApprove,
  woView,
  qcView,
  qcSubmit,
  qcValidate,
  unitsView,
  countdownView,
  countdownDetailView,
  countdownSubmitApproval,
  countdownMarkQcReady,
  countdownRequestRevision,
  monitoringView,
  prView,
  prCreate,
  prApprove,
  prReject,
  wovView,
  wovCreate,
  wovApprove,
  wovReject,
  wovUpdate,
  taskExecute,
  taskView,
  taskAssign,
  taskCheckpoint,
  warehouseRequest,
  warehouseApprove,
  warehouseLogsView,
  profileView,
  notificationsView,
  unitCatalogView,
  unitCatalogSurvey,
  unitCatalogPromote,
  unitCatalogManage,
  unitCatalogCreateJobdesc,
  dashboardKd,
  dashboardMechanic,
}

Map<String, Set<Permission>> rolePermissions = {
  'pm': {
    Permission.jobPlanCreate,
    Permission.jobPlanReview,
    Permission.jobPlanUpdate,
    Permission.woApprovePm,
    Permission.woReject,
    Permission.woExtensionApprove,
    Permission.woView,
    Permission.qcView,
    Permission.qcSubmit,
    Permission.qcValidate,
    Permission.taskView,
    Permission.taskAssign,
    Permission.taskCheckpoint,
    Permission.unitsView,
    Permission.countdownView,
    Permission.countdownDetailView,
    Permission.countdownSubmitApproval,
    Permission.monitoringView,
    Permission.notificationsView,
    Permission.prView,
    Permission.prApprove,
    Permission.prReject,
    Permission.wovView,
    Permission.wovApprove,
    Permission.wovReject,
    Permission.wovUpdate,
    Permission.profileView,
    Permission.unitCatalogView,
    Permission.unitCatalogSurvey,
    Permission.unitCatalogPromote,
    Permission.unitCatalogManage,
    Permission.unitCatalogCreateJobdesc,
    Permission.dashboardKd,
  },
  'adv': {
    Permission.jobPlanReview,
    Permission.woApproveAdvisor,
    Permission.woReject,
    Permission.woView,
    Permission.qcView,
    Permission.qcSubmit,
    Permission.qcValidate,
    Permission.taskView,
    Permission.taskCheckpoint,
    Permission.monitoringView,
    Permission.notificationsView,
    Permission.prView,
    Permission.prApprove,
    Permission.prReject,
    Permission.wovView,
    Permission.wovApprove,
    Permission.wovReject,
    Permission.profileView,
    Permission.dashboardKd,
  },
  'kd': {
    Permission.jobPlanCreate,
    Permission.jobPlanUpdate,
    Permission.woCreate,
    Permission.woExtensionRequest,
    Permission.woView,
    Permission.qcView,
    Permission.qcSubmit,
    Permission.taskView,
    Permission.taskAssign,
    Permission.taskCheckpoint,
    Permission.unitsView,
    Permission.countdownView,
    Permission.countdownDetailView,
    Permission.countdownMarkQcReady,
    Permission.countdownRequestRevision,
    Permission.warehouseApprove,
    Permission.warehouseLogsView,
    Permission.notificationsView,
    Permission.prView,
    Permission.prCreate,
    Permission.wovView,
    Permission.wovCreate,
    Permission.profileView,
    Permission.unitCatalogView,
    Permission.unitCatalogSurvey,
    Permission.unitCatalogPromote,
    Permission.unitCatalogManage,
    Permission.unitCatalogCreateJobdesc,
    Permission.dashboardKd,
  },
  'warehouse': {
    Permission.warehouseApprove,
    Permission.warehouseLogsView,
    Permission.notificationsView,
    Permission.profileView,
    Permission.dashboardKd,
  },
  'warehouse_staff': {
    Permission.warehouseLogsView,
    Permission.notificationsView,
    Permission.profileView,
    Permission.dashboardKd,
  },
  'ppic': {
    Permission.warehouseApprove,
    Permission.warehouseLogsView,
    Permission.notificationsView,
    Permission.profileView,
    Permission.dashboardKd,
  },
  'op': {
    Permission.taskExecute,
    Permission.taskView,
    Permission.taskCheckpoint,
    Permission.warehouseRequest,
    Permission.warehouseLogsView,
    Permission.notificationsView,
    Permission.profileView,
    Permission.unitCatalogView,
    Permission.unitCatalogSurvey,
    Permission.dashboardMechanic,
  },
};

Map<Permission, List<String>> _permissionCodeMap = {
  Permission.jobPlanCreate: [Perms.jobPlanCreate],
  Permission.jobPlanReview: [Perms.jobPlanReview],
  Permission.jobPlanUpdate: [Perms.jobPlanUpdate],
  Permission.woCreate: [Perms.woCreate],
  Permission.woApproveAdvisor: [Perms.woApproveAdvisor, Perms.woApprove],
  Permission.woApprovePm: [Perms.woApprovePm, Perms.woApprove],
  Permission.woReject: [Perms.woReject],
  Permission.woExtensionRequest: [Perms.woExtensionRequest],
  Permission.woExtensionApprove: [Perms.woExtensionApprove],
  Permission.woView: [Perms.woView, Perms.woCreate, Perms.woApprove],
  Permission.qcView: [Perms.qcView, Perms.qcSubmit, Perms.qcValidate],
  Permission.qcSubmit: [Perms.qcSubmit],
  Permission.qcValidate: [Perms.qcValidate],
  Permission.unitsView: [Perms.unitsView],
  Permission.countdownView: [Perms.countdownView],
  Permission.countdownDetailView: [
    Perms.countdownDetailView,
    Perms.monitoringDetail,
  ],
  Permission.countdownSubmitApproval: [Perms.countdownSubmitApproval],
  Permission.countdownMarkQcReady: [Perms.countdownMarkQcReady],
  Permission.countdownRequestRevision: [Perms.countdownRequestRevision],
  Permission.monitoringView: [Perms.monitoringView],
  Permission.prView: [Perms.prView, Perms.prCreate, Perms.prApprove],
  Permission.prCreate: [Perms.prCreate],
  Permission.prApprove: [Perms.prApprove],
  Permission.prReject: [Perms.prApprove],
  Permission.wovView: [Perms.vendorView, Perms.wovCreate, Perms.vendorApprove],
  Permission.wovCreate: [Perms.wovCreate, Perms.vendorCreate],
  Permission.wovApprove: [Perms.vendorApprove],
  Permission.wovReject: [Perms.vendorApprove],
  Permission.wovUpdate: [
    Perms.wovUpdate,
    Perms.vendorUpdateStatus,
    Perms.vendorReceive,
  ],
  Permission.taskExecute: [
    Perms.taskExecute,
    Perms.taskSubmit,
    Perms.taskPending,
    Perms.taskBreak,
    Perms.uploadTicket,
  ],
  Permission.taskView: [Perms.taskView],
  Permission.taskAssign: [Perms.taskAssign],
  Permission.taskCheckpoint: [Perms.taskCheckpoint],
  Permission.warehouseRequest: [Perms.warehouseRequest],
  Permission.warehouseApprove: [
    Perms.warehouseApprove,
    Perms.warehouseReady,
    Perms.warehouseIssue,
    Perms.warehouseReturn,
  ],
  Permission.warehouseLogsView: [
    Perms.warehouseView,
    Perms.warehouseStockCardView,
    Perms.warehouseApprove,
    Perms.warehouseRequest,
  ],
  Permission.profileView: [Perms.profileView],
  Permission.notificationsView: [Perms.notificationsView],
  Permission.unitCatalogView: [Perms.unitCatalogView],
  Permission.unitCatalogSurvey: [Perms.unitCatalogSurvey],
  Permission.unitCatalogPromote: [
    Perms.unitCatalogPromote,
    Perms.unitCatalogManage,
  ],
  Permission.unitCatalogManage: [Perms.unitCatalogManage],
  Permission.unitCatalogCreateJobdesc: [Perms.unitCatalogCreateJobdesc],
};

SessionManager? _trySession() {
  if (!sl.isRegistered<SessionManager>()) return null;
  try {
    return sl<SessionManager>();
  } catch (_) {
    return null;
  }
}

String _normalizeRole(String value) {
  return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
}

String _canonicalLegacyRole(String? role) {
  return switch (_normalizeRole(role ?? '')) {
    'admin' ||
    'mis' ||
    'manager_produksi' ||
    'manager_operational' ||
    'mp' ||
    'pm' => 'pm',
    'kp' || 'kepala_produksi' || 'kepala_project' => 'pm',
    'adv' || 'advisor' => 'adv',
    'kd' || 'ketua_divisi' || 'kepala_divisi' => 'kd',
    'team_lapangan' || 'op' => 'op',
    'kepala_gudang' || 'admin_gudang' || 'gudang' => 'warehouse',
    'gudang_tools' || 'gudang_sparepart' || 'gudang_bahan' => 'warehouse_staff',
    'ppic' || 'ppc' || 'manager_gudang' => 'ppic',
    _ => _normalizeRole(role ?? ''),
  };
}

bool _sessionHasPermission(SessionManager session, Permission permission) {
  if (!session.mobileEnabled) {
    return false;
  }

  switch (permission) {
    case Permission.dashboardMechanic:
      return session.isFieldExecution;
    case Permission.dashboardKd:
      return !session.isFieldExecution &&
          session.mobileEnabled &&
          (session.permissions.isNotEmpty ||
              session.isGlobalAccess ||
              session.isDivisionAccess ||
              session.isUnitAccess ||
              session.isWarehouseAccess);
    case Permission.woApproveAdvisor:
      return session.isAdvisorAccess &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.woApprovePm:
      return (session.isKpAccess || session.isGlobalAccess) &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.woCreate:
      return session.isKdAccess &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.woExtensionRequest:
      return session.isKdAccess &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.woExtensionApprove:
      return (session.isKpAccess || session.isGlobalAccess) &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.countdownSubmitApproval:
      return (session.isKpAccess || session.isGlobalAccess) &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.countdownMarkQcReady:
    case Permission.countdownRequestRevision:
      return session.isKdAccess &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.prApprove:
    case Permission.prReject:
      return !session.isFieldExecution &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    case Permission.wovApprove:
    case Permission.wovReject:
    case Permission.wovUpdate:
      return !session.isFieldExecution &&
          session.hasAnyPerm(_permissionCodeMap[permission] ?? []);
    default:
      final codes = _permissionCodeMap[permission];
      if (codes == null || codes.isEmpty) return false;
      return session.hasAnyPerm(codes);
  }
}

bool _legacyHasPermission(String? role, Permission permission) {
  return _legacyPermissionsForRole(role).contains(permission);
}

Set<Permission> _legacyPermissionsForRole(String? role) {
  if (role == null || role.trim().isEmpty) return {};
  final normalized = _canonicalLegacyRole(role);
  return rolePermissions[normalized] ?? {};
}

bool hasPermission(String? role, Permission permission) {
  final session = _trySession();
  if (session != null) {
    return _sessionHasPermission(session, permission);
  }
  return _legacyHasPermission(role, permission);
}

Set<Permission> getPermissions(String? role) {
  final session = _trySession();
  if (session != null) {
    return Permission.values
        .where((permission) => _sessionHasPermission(session, permission))
        .toSet();
  }
  return _legacyPermissionsForRole(role);
}
