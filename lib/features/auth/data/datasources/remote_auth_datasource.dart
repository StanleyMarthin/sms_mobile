import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/device_init_model.dart';
import '../models/login_model.dart';
import 'auth_datasource.dart';

/// Remote data source for authentication using ApiClient (Dio).
class RemoteAuthDataSource implements AuthDataSource {
  final ApiClient apiClient;

  const RemoteAuthDataSource({required this.apiClient});

  /// POST /auth/device-init
  @override
  Future<DeviceInitModel> deviceInit(Map<String, dynamic> deviceInfo) async {
    final response = await apiClient.post(
      ApiEndpoints.deviceInit,
      data: deviceInfo,
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    // versionStatus can be at top level or inside data
    return DeviceInitModel.fromJson({
      ...data,
      'versionStatus': data['versionStatus'] ?? response.data?['versionStatus'],
      'tempToken': data['tempToken'] ?? response.data?['tempToken'],
    });
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
        if (fcmToken != null) 'fcmToken': fcmToken,
      },
    );
    final rawData = response.data as Map<String, dynamic>? ?? {};
    // Token may be at top level of response or inside data
    final token = rawData['token'] as String? ?? '';
    final user = rawData['user'] as Map<String, dynamic>? ?? rawData;
    return LoginModel.fromJson({
      'token': token,
      'user': user,
    });
  }
}
