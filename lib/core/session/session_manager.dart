/*
Tujuan: Manajemen session, token, role profile, dan permission backend mobile.
Caller: ApiClient, router redirect, RBAC, dan halaman fitur.
Dependensi: AppSecureStorage, ChangeNotifier.
Main Functions: SessionManager, Perms constants.
Side Effects: Read/write secure local storage dan notifyListeners().
*/

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../security/app_secure_storage.dart';

/// Manages the authenticated user's session state.
///
/// Stores the Redis session token, refresh token, user profile,
/// role profile, scope context, and BE-driven permissions.
class SessionManager extends ChangeNotifier {
  SessionManager({this.storage = AppSecureStorage.instance});

  static final keyTempToken = 'session_tempToken';
  static final keyDeviceId = 'session_deviceId';
  static final keyToken = 'session_token';
  static final keyRefreshToken = 'session_refreshToken';
  static final keyUserId = 'session_userId';
  static final keyEmployeeId = 'session_employeeId';
  static final keyFullName = 'session_fullName';
  static final keyRole = 'session_role';
  static final keyDivisionName = 'session_divisionName';
  static final keyJabatan = 'session_jabatan';
  static final keyDivisionId = 'session_divisionId';
  static final keyPermissions = 'session_permissions';
  static final keyAccessBucket = 'session_accessBucket';
  static final keyRoleLevel = 'session_roleLevel';
  static final keyScopeBasis = 'session_scopeBasis';
  static final keyWebEnabled = 'session_webEnabled';
  static final keyMobileEnabled = 'session_mobileEnabled';
  static final keyApprovalRank = 'session_approvalRank';
  static final keyCanViewAllUnits = 'session_canViewAllUnits';
  static final keyCanViewAssignedUnits = 'session_canViewAssignedUnits';
  static final keyManagedDivisionIds = 'session_managedDivisionIds';
  static final keyManagedUnitIds = 'session_managedUnitIds';

  final dynamic storage;

  // ── Device attestation ─────────────────────────────────
  String? _tempToken;
  String? _deviceId;

  // ── Auth ───────────────────────────────────────────────
  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _employeeId;
  String? _fullName;
  String? _role; // raw role name from backend
  String? _divisionName;
  String? _jabatan;
  int? _divisionId;
  List<String> _permissions = [];
  String? _accessBucket;
  int? _roleLevel;
  String? _scopeBasis;
  bool? _webEnabled;
  bool? _mobileEnabled;
  int? _approvalRank;
  bool _canViewAllUnits = false;
  bool _canViewAssignedUnits = false;
  List<int> _managedDivisionIds = [];
  List<String> _managedUnitIds = [];

  // ── Getters ────────────────────────────────────────────
  bool get isLoggedIn => _token != null;
  String? get tempToken => _tempToken;
  String? get deviceId => _deviceId;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get employeeId => _employeeId;
  String? get fullName => _fullName;
  String? get rawRoleName => _role;
  String? get role => _deriveLegacyRole(_role, accessBucket, _permissions);
  String? get divisionName => _divisionName;
  String? get jabatan => _jabatan;
  int? get divisionId => _divisionId;
  List<String> get permissions => List.unmodifiable(_permissions);
  String? get accessBucket =>
      _accessBucket ?? _deriveAccessBucket(_role, _permissions);
  int? get roleLevel => _roleLevel;
  String get scopeBasis =>
      _scopeBasis ?? _deriveScopeBasis(accessBucket, _permissions);
  bool get webEnabled => _webEnabled ?? true;
  bool get mobileEnabled => _mobileEnabled ?? true;
  int? get approvalRank => _approvalRank;
  bool get canViewAllUnits =>
      _canViewAllUnits ||
      _permissions.contains(Perms.viewAllUnits) ||
      accessBucket == 'GLOBAL';
  bool get canViewAssignedUnits =>
      canViewAllUnits ||
      _canViewAssignedUnits ||
      _permissions.contains(Perms.viewAssignedUnits) ||
      {'KD', 'ADV', 'KP'}.contains(accessBucket);
  List<int> get managedDivisionIds => List.unmodifiable(_managedDivisionIds);
  List<String> get managedUnitIds => List.unmodifiable(_managedUnitIds);
  bool get isGlobalAccess => accessBucket == 'GLOBAL';
  bool get isDivisionAccess => accessBucket == 'KD' || accessBucket == 'ADV';
  bool get isUnitAccess => accessBucket == 'KP';
  bool get isFieldExecution => accessBucket == 'FIELD';
  bool get isWarehouseAccess => accessBucket == 'WAREHOUSE';
  bool get isKdAccess => accessBucket == 'KD';
  bool get isAdvisorAccess => accessBucket == 'ADV';
  bool get isKpAccess => accessBucket == 'KP';
  bool get isManagementAccess =>
      isGlobalAccess || isDivisionAccess || isUnitAccess;

  String get roleLabel {
    if (_normalizeRole(_role) == 'mis') return 'Super Admin';
    final title = _jabatan?.trim();
    if (title != null && title.isNotEmpty) return title;
    return switch (accessBucket) {
      'GLOBAL' => 'Manajemen',
      'KP' => 'Penanggung Jawab Unit',
      'ADV' => 'Advisor',
      'KD' => 'Kepala Divisi',
      'FIELD' => 'Tim Eksekusi',
      'WAREHOUSE' => 'Gudang',
      _ => _humanizeRole(_role),
    };
  }

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
    _accessBucket = _emptyToNull(await _read(keyAccessBucket));
    _roleLevel = int.tryParse(await _read(keyRoleLevel) ?? '');
    _scopeBasis = _emptyToNull(await _read(keyScopeBasis))?.toUpperCase();
    _webEnabled = _decodeBool(await _read(keyWebEnabled));
    _mobileEnabled = _decodeBool(await _read(keyMobileEnabled));
    _approvalRank = int.tryParse(await _read(keyApprovalRank) ?? '');
    _canViewAllUnits = _decodeBool(await _read(keyCanViewAllUnits)) ?? false;
    _canViewAssignedUnits =
        _decodeBool(await _read(keyCanViewAssignedUnits)) ?? false;
    _managedDivisionIds = _decodeIntList(await _read(keyManagedDivisionIds));
    _managedUnitIds = _decodeStringList(await _read(keyManagedUnitIds));

    final permsStr = await _read(keyPermissions);
    if (permsStr != null) {
      try {
        final decoded = jsonDecode(permsStr);
        if (decoded is List) {
          _permissions = decoded.map((item) => '$item').toList();
        }
      } catch (_) {
        _permissions = [];
      }
    }

    _normalizeLoadedScope();
    notifyListeners();
  }

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
    String? accessBucket,
    int? roleLevel,
    String? scopeBasis,
    bool? webEnabled,
    bool? mobileEnabled,
    int? approvalRank,
    bool? canViewAllUnits,
    bool? canViewAssignedUnits,
    List<int> managedDivisionIds = const [],
    List<String> managedUnitIds = const [],
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
    _accessBucket =
        _emptyToNull(accessBucket)?.toUpperCase() ??
        _deriveAccessBucket(role, _permissions);
    _roleLevel = roleLevel;
    _scopeBasis = _emptyToNull(scopeBasis)?.toUpperCase();
    _webEnabled = webEnabled;
    _mobileEnabled = mobileEnabled;
    _approvalRank = approvalRank;
    _canViewAllUnits = canViewAllUnits ?? false;
    _canViewAssignedUnits = canViewAssignedUnits ?? false;
    _managedDivisionIds = _normalizeDivisionIds(managedDivisionIds, divisionId);
    _managedUnitIds = _normalizeStringList(managedUnitIds);
    _tempToken = null;

    _normalizeLoadedScope();

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
      _write(keyAccessBucket, _accessBucket ?? ''),
      _write(keyRoleLevel, _roleLevel?.toString() ?? ''),
      _write(keyScopeBasis, _scopeBasis ?? ''),
      _write(keyWebEnabled, (_webEnabled ?? true).toString()),
      _write(keyMobileEnabled, (_mobileEnabled ?? true).toString()),
      _write(keyApprovalRank, _approvalRank?.toString() ?? ''),
      _write(keyCanViewAllUnits, _canViewAllUnits.toString()),
      _write(keyCanViewAssignedUnits, _canViewAssignedUnits.toString()),
      _write(keyManagedDivisionIds, jsonEncode(_managedDivisionIds)),
      _write(keyManagedUnitIds, jsonEncode(_managedUnitIds)),
    ]);

    notifyListeners();
  }

  bool hasPerm(String permissionCode) {
    return _permissions.contains(permissionCode);
  }

  bool hasAnyPerm(List<String> codes) {
    return codes.any((c) => _permissions.contains(c));
  }

  bool matchesAccessBucket(String bucket) {
    return accessBucket == bucket.trim().toUpperCase();
  }

  bool hasApprovalRankAtLeast(int rank) {
    final currentRank = approvalRank;
    return currentRank != null && currentRank >= rank;
  }

  bool canAccessDivision(String? divisionId) {
    if (divisionId == null || divisionId.isEmpty) return false;
    if (canViewAllUnits) return true;
    final parsed = int.tryParse(divisionId);
    if (parsed == null) return false;
    return _managedDivisionIds.contains(parsed) || _divisionId == parsed;
  }

  bool canAccessUnit(String? unitId) {
    if (unitId == null || unitId.isEmpty) return false;
    if (canViewAllUnits) return true;
    return _managedUnitIds.contains(unitId);
  }

  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    _userId = null;
    _employeeId = null;
    _fullName = null;
    _role = null;
    _divisionName = null;
    _jabatan = null;
    _divisionId = null;
    _permissions = [];
    _accessBucket = null;
    _roleLevel = null;
    _scopeBasis = null;
    _webEnabled = null;
    _mobileEnabled = null;
    _approvalRank = null;
    _canViewAllUnits = false;
    _canViewAssignedUnits = false;
    _managedDivisionIds = [];
    _managedUnitIds = [];

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
      _delete(keyAccessBucket),
      _delete(keyRoleLevel),
      _delete(keyScopeBasis),
      _delete(keyWebEnabled),
      _delete(keyMobileEnabled),
      _delete(keyApprovalRank),
      _delete(keyCanViewAllUnits),
      _delete(keyCanViewAssignedUnits),
      _delete(keyManagedDivisionIds),
      _delete(keyManagedUnitIds),
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

  void _normalizeLoadedScope() {
    _accessBucket ??= _deriveAccessBucket(_role, _permissions);
    _scopeBasis ??= _deriveScopeBasis(_accessBucket, _permissions);
    _managedDivisionIds = _normalizeDivisionIds(
      _managedDivisionIds,
      _divisionId,
    );
    _managedUnitIds = _normalizeStringList(_managedUnitIds);
  }

  String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool? _decodeBool(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  List<int> _decodeIntList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((item) => int.tryParse('$item'))
          .whereType<int>()
          .toSet()
          .toList()
        ..sort();
    } catch (_) {
      return [];
    }
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return _normalizeStringList(decoded.map((item) => '$item').toList());
    } catch (_) {
      return [];
    }
  }

  List<int> _normalizeDivisionIds(List<int> values, int? fallbackDivisionId) {
    final normalized = <int>{
      ...values.where((item) => item > 0),
      if (values.isEmpty &&
          fallbackDivisionId != null &&
          fallbackDivisionId > 0)
        fallbackDivisionId,
    }.toList()..sort();
    return normalized;
  }

  List<String> _normalizeStringList(List<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String _deriveLegacyRole(
    String? rawRole,
    String? bucket,
    List<String> permissions,
  ) {
    final normalizedRaw = _normalizeRole(rawRole);
    switch ((bucket ?? '').toUpperCase()) {
      case 'GLOBAL':
        return 'pm';
      case 'KP':
        return 'kp';
      case 'ADV':
        return 'adv';
      case 'KD':
        return 'kd';
      case 'FIELD':
        return 'op';
      case 'WAREHOUSE':
        return _warehouseLegacyRole(normalizedRaw) ?? 'kepala_gudang';
      default:
        return _normalizeRoleByPermission(normalizedRaw, permissions);
    }
  }

  String _deriveAccessBucket(String? rawRole, List<String> permissions) {
    final normalized = _normalizeRole(rawRole);
    final normalizedPerms = permissions
        .map((item) => item.toUpperCase())
        .toSet();
    final hasGlobalScope =
        permissions.contains(Perms.viewAllUnits) ||
        normalizedPerms.contains('VIEW_ALL_UNITS');
    final hasKpApproval = normalizedPerms.any(
      (code) => {
        'WO_APPROVE_PM',
        'APPROVE_WO_PM',
        'WO_APPROVE',
        'PR_APPROVE',
        'VENDOR_APPROVE',
        'QC_VALIDATE',
      }.contains(code),
    );
    final hasAdvisorApproval = normalizedPerms.any(
      (code) => {
        'REVIEW_TASK',
        'WO_APPROVE_ADVISOR',
        'APPROVE_WO_ADVISOR',
      }.contains(code),
    );
    final hasKdPlanning = normalizedPerms.any(
      (code) => {
        'CREATE_TASK',
        'UPDATE_PLAN',
        'WO_CREATE',
        'VIEW_COUNTDOWN',
        'VIEW_UNITS',
      }.contains(code),
    );
    final hasWarehouseScope =
        normalizedPerms.any(
          (code) => {
            'WAREHOUSE_VIEW',
            'WAREHOUSE_REQUEST',
            'WAREHOUSE_APPROVE',
            'WAREHOUSE_READY',
            'WAREHOUSE_ISSUE',
            'WAREHOUSE_RETURN',
            'WAREHOUSE_STOCK_CARD_VIEW',
          }.contains(code),
        ) &&
        !hasKdPlanning &&
        !hasAdvisorApproval &&
        !hasKpApproval;
    final hasFieldExecution = normalizedPerms.any(
      (code) => {
        'TASK_EXECUTE',
        'TASK_SUBMIT',
        'TASK_PENDING',
        'TASK_BREAK',
        'UPLOAD_TICKET',
      }.contains(code),
    );

    if (hasGlobalScope ||
        {
          'pm',
          'mp',
          'admin',
          'mis',
          'manager_produksi',
          'manager_operational',
        }.contains(normalized)) {
      return 'GLOBAL';
    }
    if ({
      'kp',
      'kepala_produksi',
      'kepala_project',
      'kepala_project_unit',
      'project_head',
    }.contains(normalized)) {
      return 'KP';
    }
    if ({'adv', 'advisor'}.contains(normalized)) {
      return 'ADV';
    }
    if ({'kd', 'ketua_divisi', 'kepala_divisi'}.contains(normalized)) {
      return 'KD';
    }
    if ({
          'kp',
          'kepala_produksi',
          'kepala_project',
          'kepala_project_unit',
          'project_head',
        }.contains(normalized) ||
        hasKpApproval) {
      return 'KP';
    }
    if ({'adv', 'advisor'}.contains(normalized) || hasAdvisorApproval) {
      return 'ADV';
    }
    if ({'kd', 'ketua_divisi', 'kepala_divisi'}.contains(normalized) ||
        hasKdPlanning) {
      return 'KD';
    }
    if (_warehouseLegacyRole(normalized) != null || hasWarehouseScope) {
      return 'WAREHOUSE';
    }
    if (hasFieldExecution) {
      return 'FIELD';
    }
    return 'USER';
  }

  String _deriveScopeBasis(String? bucket, List<String> permissions) {
    if (permissions.contains(Perms.viewAllUnits)) return 'GLOBAL';
    return switch ((bucket ?? '').toUpperCase()) {
      'GLOBAL' => 'GLOBAL',
      'KP' => 'ASSIGNED_UNITS',
      'ADV' => 'ASSIGNED_DIVISIONS',
      'KD' => 'ASSIGNED_DIVISIONS',
      'FIELD' => 'SELF_ONLY',
      _ => 'OWN_DIVISION',
    };
  }

  String _normalizeRoleByPermission(
    String normalizedRaw,
    List<String> permissions,
  ) {
    final normalized = _warehouseLegacyRole(normalizedRaw) ?? normalizedRaw;
    if (normalized.isNotEmpty) return normalized;
    final normalizedPerms = permissions
        .map((item) => item.toUpperCase())
        .toSet();
    if (normalizedPerms.contains('VIEW_ALL_UNITS')) return 'pm';
    if (normalizedPerms.any(
      (code) => {
        'WO_APPROVE_PM',
        'APPROVE_WO_PM',
        'WO_APPROVE',
        'PR_APPROVE',
        'VENDOR_APPROVE',
        'QC_VALIDATE',
      }.contains(code),
    )) {
      return 'kp';
    }
    if (normalizedPerms.any(
      (code) => {
        'REVIEW_TASK',
        'WO_APPROVE_ADVISOR',
        'APPROVE_WO_ADVISOR',
      }.contains(code),
    )) {
      return 'adv';
    }
    if (normalizedPerms.any(
      (code) => {'CREATE_TASK', 'UPDATE_PLAN', 'WO_CREATE'}.contains(code),
    )) {
      return 'kd';
    }
    if (normalizedPerms.contains('TASK_EXECUTE')) return 'op';
    return 'user';
  }

  String _normalizeRole(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String? _warehouseLegacyRole(String normalizedRole) {
    if (normalizedRole.isEmpty) return null;
    if ({
      'kepala_gudang',
      'admin_gudang',
      'gudang',
      'gudang_tools',
      'gudang_sparepart',
      'gudang_bahan',
      'ppic',
      'ppc',
      'manager_gudang',
    }.contains(normalizedRole)) {
      return normalizedRole;
    }
    return null;
  }

  String _humanizeRole(String? rawRole) {
    final normalized = _normalizeRole(rawRole);
    return switch (normalized) {
      'kp' || 'kepala_produksi' || 'kepala_project' => 'Penanggung Jawab Unit',
      'adv' || 'advisor' => 'Advisor',
      'kd' || 'ketua_divisi' || 'kepala_divisi' => 'Kepala Divisi',
      'op' || 'team_lapangan' => 'Tim Eksekusi',
      'kepala_gudang' || 'admin_gudang' || 'gudang' => 'Gudang',
      'gudang_tools' => 'Gudang Tools',
      'gudang_sparepart' => 'Gudang Spare Part',
      'gudang_bahan' => 'Gudang Material',
      'ppic' || 'ppc' || 'manager_gudang' => 'PPIC',
      'pm' ||
      'mp' ||
      'manager_produksi' ||
      'manager_operational' => 'Manajemen',
      'admin' => 'Administrator',
      'mis' => 'Super Admin',
      _ => 'User',
    };
  }
}

/// BE-driven permission code constants.
abstract class Perms {
  // ── Task ───────────────────────────────────────────────
  static final taskView = 'TASK_VIEW';
  static final taskAssign = 'TASK_ASSIGN';
  static final taskSubmit = 'TASK_SUBMIT';
  static final taskCheckpoint = 'TASK_CHECKPOINT';
  static final taskPending = 'TASK_PENDING';
  static final taskBreak = 'TASK_BREAK';
  static final taskExecute = 'TASK_EXECUTE';
  static final uploadTicket = 'UPLOAD_TICKET';
  static final jobPlanCreate = 'CREATE_TASK';
  static final jobPlanReview = 'REVIEW_TASK';
  static final jobPlanUpdate = 'UPDATE_PLAN';
  static final viewAllUnits = 'view_all_units';
  static final viewAssignedUnits = 'view_assigned_units';
  static final unitsView = 'VIEW_UNITS';
  static final countdownView = 'VIEW_COUNTDOWN';
  static final countdownDetailView = 'VIEW_COUNTDOWN_DETAIL';
  static final countdownSubmitApproval = 'COUNTDOWN_SUBMIT_APPROVAL';
  static final countdownMarkQcReady = 'COUNTDOWN_MARK_QC_READY';
  static final countdownRequestRevision = 'COUNTDOWN_REQUEST_REVISION';

  // ── Work Order ─────────────────────────────────────────
  static final woCreate = 'WO_CREATE';
  static final woApprove = 'WO_APPROVE';
  static final woApproveAdvisor = 'APPROVE_WO_ADVISOR';
  static final woApprovePm = 'APPROVE_WO_PM';
  static final woExtensionRequest = 'WO_EXTENSION_REQUEST';
  static final woExtensionApprove = 'WO_EXTENSION_APPROVE';
  static final woReject = 'WO_REJECT';
  static final woView = 'WO_VIEW';

  // ── QC ─────────────────────────────────────────────────
  static final qcView = 'QC_VIEW';
  static final qcSubmit = 'QC_SUBMIT';
  static final qcValidate = 'QC_VALIDATE';

  // ── Warehouse / Peminjaman ─────────────────────────────
  static final warehouseView = 'WAREHOUSE_VIEW';
  static final warehouseRequest = 'WAREHOUSE_REQUEST';
  static final warehouseApprove = 'WAREHOUSE_APPROVE';
  static final warehouseReady = 'WAREHOUSE_READY';
  static final warehouseIssue = 'WAREHOUSE_ISSUE';
  static final warehouseReturn = 'WAREHOUSE_RETURN';
  static final warehouseLogs = 'WAREHOUSE_VIEW';
  static final warehouseStockCardView = 'WAREHOUSE_STOCK_CARD_VIEW';

  // ── Monitoring ─────────────────────────────────────────
  static final monitoringView = 'LIST_CAR_PROGRESS';
  static final monitoringDetail = 'CAR_PROGRESS_DETAIL';

  // ── Purchase / Vendor ──────────────────────────────────
  static final prView = 'PR_VIEW';
  static final prCreate = 'PR_CREATE';
  static final prApprove = 'PR_APPROVE';
  static final wovCreate = 'WOV_CREATE';
  static final wovUpdate = 'WOV_UPDATE';
  static final vendorView = 'VENDOR_VIEW';
  static final vendorCreate = 'VENDOR_CREATE';
  static final vendorApprove = 'VENDOR_APPROVE';
  static final vendorUpdateStatus = 'VENDOR_UPDATE_STATUS';
  static final vendorReceive = 'VENDOR_RECEIVE';

  // ── Profile ────────────────────────────────────────────
  static final notificationsView = 'LIST_NOTIFICATIONS';
  static final profileView = 'PROFILE_VIEW';

  // ── Unit Preparation / Catalog ─────────────────────────
  static final unitCatalogView = 'UNIT_CATALOG_VIEW';
  static final unitCatalogSurvey = 'UNIT_CATALOG_SURVEY';
  static final unitCatalogCreateJobdesc = 'UNIT_CATALOG_CREATE_JOBDESC';
}
