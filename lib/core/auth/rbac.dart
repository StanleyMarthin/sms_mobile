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
      'op' => UserRole.op,
      'kd' => UserRole.kd,
      'adv' => UserRole.adv,
      'pm' => UserRole.pm,
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
    Permission.qcValidate,
    Permission.taskView,
    Permission.taskAssign,
    Permission.taskCheckpoint,
    Permission.unitsView,
    Permission.countdownView,
    Permission.countdownDetailView,
    Permission.monitoringView,
    Permission.notificationsView,
    Permission.profileView,
    Permission.dashboardKd,
  },
  'adv': {
    Permission.jobPlanReview,
    Permission.woApproveAdvisor,
    Permission.woReject,
    Permission.woView,
    Permission.qcView,
    Permission.qcValidate,
    Permission.taskView,
    Permission.taskCheckpoint,
    Permission.monitoringView,
    Permission.notificationsView,
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
    Permission.profileView,
    Permission.dashboardKd,
  },
  'op': {
    Permission.taskExecute,
    Permission.taskView,
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
  return rolePermissions[role]?.contains(permission) ?? false;
}

/// Returns all permissions for a given [role].
Set<Permission> getPermissions(String? role) {
  if (role == null) return {};
  return rolePermissions[role] ?? {};
}
