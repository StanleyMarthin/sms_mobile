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
      ];
}
