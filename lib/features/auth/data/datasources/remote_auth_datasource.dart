import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../models/device_init_model.dart';
import '../models/login_model.dart';
import 'auth_datasource.dart';

/// Remote data source for authentication using ApiClient (Dio).
class RemoteAuthDataSource implements AuthDataSource {
  final ApiClient apiClient;

  RemoteAuthDataSource({required this.apiClient});

  /// POST /auth/device-init
  @override
  Future<DeviceInitModel> deviceInit(Map<String, dynamic> deviceInfo) async {
    final response = await apiClient.post(
      ApiEndpoints.deviceInit,
      data: deviceInfo,
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return DeviceInitModel.fromJson(data);
  }

  /// POST /auth/login
  @override
  Future<LoginModel> login({
    required String employeeId,
    required String password,
    String? fcmToken,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      data: {
        'employeeId': employeeId,
        'password': password,
        'deviceId': sl<SessionManager>().deviceId,
        if (fcmToken != null) 'fcmToken': fcmToken,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    final user = data['user'] as Map<String, dynamic>? ?? {};
    return LoginModel.fromJson({
      'token': data['token'],
      'refreshToken': data['refreshToken'],
      'user': user,
    });
  }
}
