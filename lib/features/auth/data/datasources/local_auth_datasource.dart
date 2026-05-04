import '../models/device_init_model.dart';
import '../models/login_model.dart';
import 'auth_datasource.dart';

/// Guard implementation to prevent auth fallback outside the real API.
class LocalAuthDataSource implements AuthDataSource {
  const LocalAuthDataSource();

  @override
  Future<DeviceInitModel> deviceInit(Map<String, dynamic> deviceInfo) async {
    throw UnsupportedError(
      'LocalAuthDataSource is disabled. Use RemoteAuthDataSource with the login API.',
    );
  }

  @override
  Future<LoginModel> login({
    required String employeeId,
    required String password,
    String? fcmToken,
  }) async {
    throw UnsupportedError(
      'LocalAuthDataSource is disabled. Use RemoteAuthDataSource with the login API.',
    );
  }
}
