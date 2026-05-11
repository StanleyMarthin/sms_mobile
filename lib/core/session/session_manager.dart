import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../security/app_secure_storage.dart';

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
  SessionManager({this.storage = AppSecureStorage.instance});

  static const keyTempToken = 'session_tempToken';
  static const keyDeviceId = 'session_deviceId';
  static const keyToken = 'session_token';
  static const keyRefreshToken = 'session_refreshToken';
  static const keyUserId = 'session_userId';
  static const keyEmployeeId = 'session_employeeId';
  static const keyFullName = 'session_fullName';
  static const keyRole = 'session_role';
  static const keyDivisionName = 'session_divisionName';
  static const keyJabatan = 'session_jabatan';
  static const keyDivisionId = 'session_divisionId';
  static const keyPermissions = 'session_permissions';

  final dynamic storage;

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
    _tempToken = await _read(keyTempToken);
    _token = await _read(keyToken);
    _refreshToken = await _read(keyRefreshToken);
    _deviceId = await _read(keyDeviceId);
    _userId = await _read(keyUserId);
    _employeeId = await _read(keyEmployeeId);
    _fullName = await _read(keyFullName);
    _role = await _read(keyRole);
    _divisionName = await _read(keyDivisionName);
    _jabatan = await _read(keyJabatan);
    _divisionId = int.tryParse(await _read(keyDivisionId) ?? '');

    final permsStr = await _read(keyPermissions);
    if (permsStr != null) {
      try {
        final decoded = jsonDecode(permsStr);
        if (decoded is List) {
          _permissions = decoded.cast<String>();
        }
      } catch (_) {
        _permissions = [];
      }
    }
    notifyListeners();
  }

  /// Store temp token from device attestation (splash screen).
  /// This token is ONLY valid for calling POST /auth/login.
  Future<void> setDeviceAttestation({
    required String tempToken,
    required String deviceId,
  }) async {
    _tempToken = tempToken;
    _deviceId = deviceId;

    await Future.wait([
      _write(keyTempToken, tempToken),
      _write(keyDeviceId, deviceId),
    ]);
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

    await Future.wait([
      _delete(keyTempToken),
      _write(keyToken, token),
      _write(keyRefreshToken, refreshToken),
      _write(keyUserId, userId),
      _write(keyEmployeeId, employeeId),
      _write(keyFullName, fullName),
      _write(keyRole, role),
      _write(keyDivisionName, divisionName),
      _write(keyJabatan, jabatan),
      _write(keyDivisionId, '$divisionId'),
      _write(keyPermissions, jsonEncode(_permissions)),
    ]);

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

    await Future.wait([
      _delete(keyTempToken),
      _delete(keyToken),
      _delete(keyRefreshToken),
      _delete(keyUserId),
      _delete(keyEmployeeId),
      _delete(keyFullName),
      _delete(keyRole),
      _delete(keyDivisionName),
      _delete(keyJabatan),
      _delete(keyDivisionId),
      _delete(keyPermissions),
    ]);

    notifyListeners();
  }

  Future<String?> _read(String key) {
    return storage.read(key: key);
  }

  Future<void> _write(String key, String value) {
    return storage.write(key: key, value: value);
  }

  Future<void> _delete(String key) {
    return storage.delete(key: key);
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
