import 'package:equatable/equatable.dart';

/// Result from POST /auth/login.
class LoginResult extends Equatable {
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

  const LoginResult({
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

  @override
  List<Object?> get props => [
    token,
    refreshToken,
    userId,
    fullname,
    division,
    grade,
    roleName,
    divisionId,
    permissions,
    accessBucket,
    roleLevel,
    scopeBasis,
    webEnabled,
    mobileEnabled,
    approvalRank,
    canViewAllUnits,
    canViewAssignedUnits,
    managedDivisionIds,
    managedUnitIds,
  ];
}
