import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/dummy_data.dart';

/// Manages the authenticated user's session state.
///
/// Stores the Redis session token, refresh token, user profile,
/// and BE-driven permissions.
/// The splash screen first obtains a [tempToken] via device attestation
/// (POST /auth/device-init) which is only valid for the login endpoint.
/// After login, the backend returns the full session payload:
/// session token, refresh token, divisionName, jabatan (position),
/// and permissions[].
class SessionManager extends ChangeNotifier {
  // ── Device attestation ─────────────────────────────────
  String? _tempToken;
  String? _deviceId;

  // ── Auth ───────────────────────────────────────────────
  String? _token; // Redis session token from sm_login
  String? _refreshToken;
  String? _userId;
  String? _employeeId;
  String? _fullName;
  String? _role; // roleName from BE (e.g. op, kd, adv, pm)
  String? _divisionName;
  String? _jabatan; // human-readable position title from BE
  int? _divisionId;
  List<String> _permissions = []; // BE-driven permission codes

  // ── Getters ────────────────────────────────────────────
  bool get isLoggedIn => _token != null;
  String? get tempToken => _tempToken;
  String? get deviceId => _deviceId;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get employeeId => _employeeId;
  String? get fullName => _fullName;
  String? get role => _role;
  String? get divisionName => _divisionName;
  String? get jabatan => _jabatan;
  int? get divisionId => _divisionId;
  List<String> get permissions => List.unmodifiable(_permissions);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('session_token');
    _refreshToken = prefs.getString('session_refreshToken');
    _deviceId = prefs.getString('session_deviceId');   // restored on cold start
    _userId = prefs.getString('session_userId');
    _employeeId = prefs.getString('session_employeeId');
    _fullName = prefs.getString('session_fullName');
    _role = prefs.getString('session_role');
    _divisionName = prefs.getString('session_divisionName');
    _jabatan = prefs.getString('session_jabatan');
    _divisionId = prefs.getInt('session_divisionId');

    final permsStr = prefs.getString('session_permissions');
    if (permsStr != null) {
      try {
        final decoded = jsonDecode(permsStr);
        if (decoded is List) {
          _permissions = decoded.cast<String>();
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Store temp token from device attestation (splash screen).
  /// This token is ONLY valid for calling POST /auth/login.
  void setDeviceAttestation({
    required String tempToken,
    required String deviceId,
  }) {
    _tempToken = tempToken;
    _deviceId = deviceId;
    // Persist so auto-refresh works after cold start
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('session_deviceId', deviceId),
    );
    notifyListeners();
  }

  /// Store full session from login response.
  ///
  /// [token] Redis session token for all authenticated API calls.
  /// [permissions] BE-driven permission codes like
  ///   'TASK_VIEW', 'TASK_SUBMIT', 'WAREHOUSE_REQUEST', etc.
  Future<void> login({
    required String token,
    required String refreshToken,
    required String userId,
    required String employeeId,
    required String fullName,
    required String role,
    required String divisionName,
    required String jabatan,
    required int divisionId,
    required List<String> permissions,
  }) async {
    _token = token;
    _refreshToken = refreshToken;
    _userId = userId;
    _employeeId = employeeId;
    _fullName = fullName;
    _role = role;
    _divisionName = divisionName;
    _jabatan = jabatan;
    _divisionId = divisionId;
    _permissions = List<String>.from(permissions);
    // Clear temp token after successful login
    _tempToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
    await prefs.setString('session_refreshToken', refreshToken);
    await prefs.setString('session_userId', userId);
    await prefs.setString('session_employeeId', employeeId);
    await prefs.setString('session_fullName', fullName);
    await prefs.setString('session_role', role);
    await prefs.setString('session_divisionName', divisionName);
    await prefs.setString('session_jabatan', jabatan);
    await prefs.setInt('session_divisionId', divisionId);
    await prefs.setString('session_permissions', jsonEncode(_permissions));

    notifyListeners();
  }

  /// Check if the user has a specific BE permission code.
  bool hasPerm(String permissionCode) {
    return _permissions.contains(permissionCode);
  }

  /// Check if the user has ANY of the given permission codes.
  bool hasAnyPerm(List<String> codes) {
    return codes.any((c) => _permissions.contains(c));
  }

  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    // Do NOT clear _tempToken and _deviceId here so the user can login again
    // _tempToken = null;
    _userId = null;
    _employeeId = null;
    _fullName = null;
    _role = null;
    _divisionName = null;
    _jabatan = null;
    _divisionId = null;
    _permissions = [];

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    await prefs.remove('session_refreshToken');
    await prefs.remove('session_userId');
    await prefs.remove('session_employeeId');
    await prefs.remove('session_fullName');
    await prefs.remove('session_role');
    await prefs.remove('session_divisionName');
    await prefs.remove('session_jabatan');
    await prefs.remove('session_divisionId');
    await prefs.remove('session_permissions');

    notifyListeners();
  }
}

/// BE-driven permission code constants.
///
/// These mirror the `sys_permissions` table in the backend database.
/// Frontend uses these to conditionally render UI elements.
abstract class Perms {
  // ── Task ───────────────────────────────────────────────
  static const taskView = 'TASK_VIEW';
  static const taskAssign = 'TASK_ASSIGN';
  static const taskSubmit = 'TASK_SUBMIT';
  static const taskCheckpoint = 'TASK_CHECKPOINT';
  static const jobPlanCreate = 'CREATE_TASK';
  static const jobPlanReview = 'REVIEW_TASK';
  static const jobPlanUpdate = 'UPDATE_PLAN';
  static const unitsView = 'VIEW_UNITS';
  static const countdownView = 'VIEW_COUNTDOWN';
  static const countdownDetailView = 'VIEW_COUNTDOWN_DETAIL';

  // ── Work Order ─────────────────────────────────────────
  static const woCreate = 'WO_CREATE';
  static const woApprove = 'WO_APPROVE';
  static const woApproveAdvisor = 'APPROVE_WO_ADVISOR';
  static const woApprovePm = 'APPROVE_WO_PM';
  static const woView = 'WO_VIEW';

  // ── QC ─────────────────────────────────────────────────
  static const qcSubmit = 'QC_SUBMIT';
  static const qcValidate = 'QC_VALIDATE';

  // ── Warehouse / Peminjaman ─────────────────────────────
  static const warehouseRequest = 'WAREHOUSE_REQUEST';
  static const warehouseApprove = 'WAREHOUSE_APPROVE';
  static const warehouseLogs = 'LIST_LOGS';

  // ── Monitoring ─────────────────────────────────────────
  static const monitoringView = 'LIST_CAR_PROGRESS';
  static const monitoringDetail = 'CAR_PROGRESS_DETAIL';

  // ── Profile ────────────────────────────────────────────
  static const notificationsView = 'LIST_NOTIFICATIONS';
  static const profileView = 'PROFILE_VIEW';
}

/// Demo user accounts derived from [DummyEmployees].
///
/// Simulates the full login response from BE including JWT,
/// jabatan (grade from DB), and dynamic permissions array.
/// Login uses `employee_id` (short name) as the login ID.
class DemoAccounts {
  DemoAccounts._();

  /// Permission sets per role (simulates BE role_permission join).
  static const _rolePerms = <String, List<String>>{
    'pm': [
      Perms.taskView,
      Perms.taskAssign,
      Perms.taskCheckpoint,
      Perms.jobPlanCreate,
      Perms.jobPlanReview,
      Perms.jobPlanUpdate,
      Perms.unitsView,
      Perms.countdownView,
      Perms.countdownDetailView,
      Perms.woApprove,
      Perms.woApprovePm,
      Perms.woView,
      Perms.qcValidate,
      Perms.monitoringView,
      Perms.monitoringDetail,
      Perms.notificationsView,
      Perms.profileView,
    ],
    'adv': [
      Perms.taskView,
      Perms.taskCheckpoint,
      Perms.jobPlanReview,
      Perms.woApprove,
      Perms.woApproveAdvisor,
      Perms.woView,
      Perms.qcValidate,
      Perms.monitoringView,
      Perms.monitoringDetail,
      Perms.notificationsView,
      Perms.profileView,
    ],
    'kd': [
      Perms.taskView,
      Perms.taskAssign,
      Perms.taskCheckpoint,
      Perms.jobPlanCreate,
      Perms.jobPlanUpdate,
      Perms.unitsView,
      Perms.countdownView,
      Perms.countdownDetailView,
      Perms.woCreate,
      Perms.woView,
      Perms.qcSubmit,
      Perms.warehouseApprove,
      Perms.warehouseLogs,
      Perms.notificationsView,
      Perms.profileView,
    ],
    'op': [
      Perms.taskView,
      Perms.taskSubmit,
      Perms.warehouseRequest,
      Perms.warehouseLogs,
      Perms.notificationsView,
      Perms.profileView,
    ],
  };

  /// All demo-login-capable users (built from DummyEmployees.all).
  /// Simulates the full POST /auth/login response payload.
  /// Login ID is `employee_id` (short name like ADAM, KANDI, YUDHA).
  static final List<Map<String, dynamic>> users = DummyEmployees.all.map((e) {
    final role = e['role'] as String;
    return {
      'token': 'demo-jwt-${e['id']}', // simulated JWT
      'userId': e['id'] as String,
      'employeeId': e['employee_id'] as String,
      'fullName': e['full_name'] as String,
      'password': e['password'] as String,
      'role': role,
      'divisionName': e['division'] as String,
      'jabatan': (e['grade'] as String?) ?? role.toUpperCase(),
      'divisionId': e['divisionId'] as int,
      'permissions': _rolePerms[role] ?? <String>[],
    };
  }).toList();
}
