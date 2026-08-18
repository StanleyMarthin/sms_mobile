import '../../domain/entities/login_result.dart';

class LoginModel {
  final String token;
  final String refreshToken;
  final String userId;
  final String fullname;
  final String division;
  final String grade;
  final String roleName;
  final int divisionId;
  final List<String> permissions;
  final String? accessBucket;
  final int? roleLevel;
  final String? scopeBasis;
  final bool? webEnabled;
  final bool? mobileEnabled;
  final int? approvalRank;
  final bool? canViewAllUnits;
  final bool? canViewAssignedUnits;
  final List<int> managedDivisionIds;
  final List<String> managedUnitIds;

  LoginModel({
    required this.token,
    required this.refreshToken,
    required this.userId,
    required this.fullname,
    required this.division,
    required this.grade,
    required this.roleName,
    required this.divisionId,
    required this.permissions,
    this.accessBucket,
    this.roleLevel,
    this.scopeBasis,
    this.webEnabled,
    this.mobileEnabled,
    this.approvalRank,
    this.canViewAllUnits,
    this.canViewAssignedUnits,
    this.managedDivisionIds = const [],
    this.managedUnitIds = const [],
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    final roleProfile = user['roleProfile'] as Map<String, dynamic>? ?? {};
    final scope = user['scope'] as Map<String, dynamic>? ?? {};
    return LoginModel(
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      userId: user['userId'] as String? ?? user['id'] as String? ?? '',
      fullname: user['fullname'] as String? ?? '',
      division: user['division'] as String? ?? '',
      grade: user['grade'] as String? ?? '',
      roleName:
          user['roleName'] as String? ??
          user['role'] as String? ??
          user['role_name'] as String? ??
          '',
      divisionId: (user['divisionId'] as num?)?.toInt() ?? 0,
      permissions:
          (user['permissions'] as List<dynamic>? ??
                  json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      accessBucket: user['accessBucket'] as String?,
      roleLevel: (roleProfile['roleLevel'] as num?)?.toInt(),
      scopeBasis: roleProfile['scopeBasis'] as String?,
      webEnabled: roleProfile['webEnabled'] as bool?,
      mobileEnabled: roleProfile['mobileEnabled'] as bool?,
      approvalRank: (roleProfile['approvalRank'] as num?)?.toInt(),
      canViewAllUnits: scope['canViewAllUnits'] as bool?,
      canViewAssignedUnits: scope['canViewAssignedUnits'] as bool?,
      managedDivisionIds:
          (scope['managedDivisionIds'] as List<dynamic>? ??
                  user['managedDivisions'] as List<dynamic>?)
              ?.map((e) => int.tryParse('$e'))
              .whereType<int>()
              .toList() ??
          [],
      managedUnitIds:
          (scope['unitIds'] as List<dynamic>? ??
                  user['managedUnits'] as List<dynamic>?)
              ?.map((e) => '$e')
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          [],
    );
  }

  LoginResult toEntity() => LoginResult(
    token: token,
    refreshToken: refreshToken,
    userId: userId,
    fullname: fullname,
    division: division,
    grade: grade,
    roleName: roleName,
    divisionId: divisionId,
    permissions: permissions,
    accessBucket: accessBucket,
    roleLevel: roleLevel,
    scopeBasis: scopeBasis,
    webEnabled: webEnabled,
    mobileEnabled: mobileEnabled,
    approvalRank: approvalRank,
    canViewAllUnits: canViewAllUnits,
    canViewAssignedUnits: canViewAssignedUnits,
    managedDivisionIds: managedDivisionIds,
    managedUnitIds: managedUnitIds,
  );
}
