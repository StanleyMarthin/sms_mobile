import '../../domain/entities/login_result.dart';

class LoginModel {
  final String token;
  final String userId;
  final String fullname;
  final String division;
  final String grade;
  final String roleName;
  final int divisionId;
  final List<String> permissions;

  const LoginModel({
    required this.token,
    required this.userId,
    required this.fullname,
    required this.division,
    required this.grade,
    required this.roleName,
    required this.divisionId,
    required this.permissions,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    return LoginModel(
      token: json['token'] as String? ?? '',
      userId: user['userId'] as String? ?? user['id'] as String? ?? '',
      fullname: user['fullname'] as String? ?? '',
      division: user['division'] as String? ?? '',
      grade: user['grade'] as String? ?? '',
      roleName: user['roleName'] as String? ?? '',
      divisionId: user['divisionId'] as int? ?? 0,
      permissions: (user['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  LoginResult toEntity() => LoginResult(
        token: token,
        userId: userId,
        fullname: fullname,
        division: division,
        grade: grade,
        roleName: roleName,
        divisionId: divisionId,
        permissions: permissions,
      );
}
