// Role-Based Access Control (RBAC) definitions for SM Workshop.
//
// Dual-mode permission system:
// 1. **BE-driven (production)**: Permissions come from login response as
//    string codes (e.g. 'TASK_VIEW'). See `Perms` class in session_manager.
//    Frontend checks via `SessionManager.hasPerm('TASK_VIEW')`.
// 2. **Enum-based (guard widgets)**: Used by `RoleGuard` widget and static role maps.
//
// Roles (match sm_role table):
// - pm (15): Project Manager — full oversight, final WO approval
// - adv (16): Advisor — mid-level approval, monitoring
// - kd (17): Kepala Divisi — division management, WO creation, planning
// - op (18): Operator / Lapangan — task execution, peminjaman, laporan

/// Role enum matching backend `roleName` values.
enum UserRole {
  op,
  kd,
  adv,
  pm;

  /// Parse from backend `roleName` string (case-insensitive).
  static UserRole? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toLowerCase()) {
      'op' || 'team_lapangan' => UserRole.op,
      'kd' || 'ketua_divisi' => UserRole.kd,
      'adv' || 'advisor' => UserRole.adv,
      'kepala_gudang' ||
      'gudang' ||
      'admin_gudang' ||
      'gudang_tools' ||
      'gudang_sparepart' ||
      'gudang_bahan' => UserRole.kd,
      'ppic' || 'ppc' || 'manager_gudang' => UserRole.kd,
      'pm' ||
      'mp' ||
      'manager_produksi' ||
      'admin' ||
      'kepala_produksi' ||
      'manager_operational' ||
      'mis' => UserRole.pm,
      _ => null,
    };
  }
}

/// All granular permissions in the system (enum for guard widgets).
enum Permission {
  // ── Job Plan ───────────────────────────────────────────
  jobPlanCreate,
  jobPlanReview,
  jobPlanUpdate,

  // ── Work Order ─────────────────────────────────────────
  woCreate, // Create new WO/WOV
  woApproveAdvisor, // Approve as advisor (PENDING_ADVISOR → PENDING_PM)
  woApprovePm, // Approve as PM (PENDING_PM → APPROVED)
  woReject, // Reject a WO
  woExtendDeadline, // Extend deadline (only requesting KD)
  woView, // View work orders
  // ── QC ─────────────────────────────────────────────────
  qcView, // View QC checks
  qcSubmit,
  qcValidate,
  unitsView,
  countdownView,
  countdownDetailView,
  monitoringView,

  // ── Purchase Request (PR) ──────────────────────────────
  prView,
  prCreate,
  prApprove,
  prReject,

  // ── Work Order Vendor (WOV) ────────────────────────────
  wovView,
  wovCreate,
  wovApprove,
  wovReject,

  // ── Task Execution ─────────────────────────────────────
  taskExecute, // Start/finish jobs (mechanic only)
  taskView, // View own task list
  taskAssign,
  taskCheckpoint,

  // ── Warehouse / Peminjaman ─────────────────────────────
  warehouseRequest, // Request/return tools & spareparts
  warehouseApprove, // Approve warehouse requests
  warehouseLogsView,

  // ── Profile ────────────────────────────────────────────
  profileView, // View own profile
  notificationsView,

  // ── Dashboard ──────────────────────────────────────────
  dashboardKd, // Access KD-style tabbed dashboard
  dashboardMechanic, // Access mechanic bottom-nav dashboard (lapangan)
}

/// Maps each role to its set of permissions.
///
/// Usage:
/// ```dart
/// final perms = rolePermissions['kd']!;
/// if (perms.contains(Permission.woCreate)) { ... }
/// ```
const Map<String, Set<Permission>> rolePermissions = {
  'pm': {
    Permission.jobPlanCreate,
    Permission.jobPlanReview,
    Permission.jobPlanUpdate,
    Permission.woApprovePm,
    Permission.woReject,
    Permission.woView,
    Permission.qcView,
    Permission.qcSubmit, // MO/MP/Admin bisa submit QC secara independen
    Permission.qcValidate,
    Permission.taskView,
    Permission.taskAssign,
    Permission.taskCheckpoint,
    Permission.unitsView,
    Permission.countdownView,
    Permission.countdownDetailView,
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
  'adv': {
    Permission.jobPlanReview,
    Permission.woApproveAdvisor,
    Permission.woReject,
    Permission.woView,
    Permission.qcView,
    Permission.qcSubmit, // ADV bisa submit QC secara independen
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
    Permission.woView,
    Permission.qcView,
    Permission.qcSubmit,
    Permission.taskView,
    Permission.taskAssign,
    Permission.taskCheckpoint,
    Permission.unitsView,
    Permission.countdownView,
    Permission.countdownDetailView,
    Permission.warehouseApprove,
    Permission.warehouseLogsView,
    Permission.notificationsView,
    Permission.prView,
    Permission.prCreate,
    Permission.wovView,
    Permission.wovCreate,
    Permission.profileView,
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
    Permission.dashboardMechanic,
  },
};

/// Checks if the given [role] has the specified [permission].
bool hasPermission(String? role, Permission permission) {
  if (role == null) return false;
  return getPermissions(role).contains(permission);
}

/// Returns all permissions for a given [role].
Set<Permission> getPermissions(String? role) {
  if (role == null) return {};
  final normalized = role.toLowerCase();

  // Alias new BE roles to legacy FE roles to maintain UI mappings
  if (normalized == 'admin') {
    return {...?rolePermissions['pm'], ...?rolePermissions['warehouse']};
  } else if (normalized == 'manager_produksi' ||
      normalized == 'mp' ||
      normalized == 'kepala_produksi' ||
      normalized == 'manager_operational' ||
      normalized == 'mis') {
    return rolePermissions['pm'] ?? {};
  } else if (normalized == 'ketua_divisi') {
    return rolePermissions['kd'] ?? {};
  } else if (normalized == 'advisor') {
    return rolePermissions['adv'] ?? {};
  } else if (normalized == 'team_lapangan') {
    return rolePermissions['op'] ?? {};
  } else if (normalized == 'kepala_gudang' ||
      normalized == 'gudang' ||
      normalized == 'admin_gudang') {
    return rolePermissions['warehouse'] ?? {};
  } else if (normalized == 'gudang_tools' ||
      normalized == 'gudang_sparepart' ||
      normalized == 'gudang_bahan') {
    return rolePermissions['warehouse_staff'] ?? {};
  } else if (normalized == 'ppic' ||
      normalized == 'ppc' ||
      normalized == 'manager_gudang') {
    return rolePermissions['ppic'] ?? {};
  }

  return rolePermissions[normalized] ?? {};
}
