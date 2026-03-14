import '../models/device_init_model.dart';
import '../models/login_model.dart';

/// Abstract interface for auth data operations.
///
/// Implementations:
/// - [LocalAuthDataSource] for dummy/offline mode
/// - [RemoteAuthDataSource] for real API
abstract class AuthDataSource {
  Future<DeviceInitModel> deviceInit(Map<String, dynamic> deviceInfo);

  Future<LoginModel> login({
    required String employeeId,
    required String password,
    String? fcmToken,
  });
}
