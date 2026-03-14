import '../../../../core/data/dummy_data.dart';
import '../../../../core/session/session_manager.dart';
import '../models/device_init_model.dart';
import '../models/login_model.dart';
import 'auth_datasource.dart';

/// Local dummy implementation of auth datasource.
///
/// Simulates POST /auth/device-init and POST /auth/login
/// using [DemoAccounts] and [DummyEmployees] seed data matching ERD.
class LocalAuthDataSource implements AuthDataSource {
  const LocalAuthDataSource();

  /// Simulates POST /auth/device-init.
  /// Always returns versionStatus=LATEST with a demo tempToken.
  @override
  Future<DeviceInitModel> deviceInit(Map<String, dynamic> deviceInfo) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const DeviceInitModel(
      versionStatus: 'LATEST',
      tempToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo-temp-token',
      message: null,
      downloadUrl: null,
    );
  }

  /// Simulates POST /auth/login.
  /// Validates employeeId + password against [DemoAccounts.users].
  /// Throws if credentials are invalid.
  @override
  Future<LoginModel> login({
    required String employeeId,
    required String password,
    String? fcmToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final account = DemoAccounts.users.cast<Map<String, dynamic>>().firstWhere(
          (u) =>
              (u['employeeId'] as String).toUpperCase() ==
                  employeeId.toUpperCase() &&
              u['password'] == password,
          orElse: () => <String, dynamic>{},
        );

    if (account.isEmpty) {
      throw Exception('INVALID_CREDENTIALS');
    }

    return LoginModel(
      token: account['token'] as String,
      userId: account['userId'] as String,
      fullname: account['fullName'] as String,
      division: account['divisionName'] as String,
      grade: account['jabatan'] as String,
      roleName: account['role'] as String,
      divisionId: account['divisionId'] as int,
      permissions: List<String>.from(account['permissions'] as List),
    );
  }
}
