library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../task_execution/data/datasources/task_draft_storage.dart';
import 'local_profile_datasource.dart';

class RemoteProfileDataSource implements ProfileDataSource {
  const RemoteProfileDataSource({
    required this.apiClient,
    required this.sessionManager,
    required this.taskDraftStorage,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;
  final TaskDraftStorage taskDraftStorage;

  @override
  Future<Map<String, dynamic>> getProfile() async {
    Map<String, dynamic> result = _fromSession();

    try {
      final response = await apiClient.get(ApiEndpoints.userProfile);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final user = data['user'] is Map<String, dynamic>
            ? data['user'] as Map<String, dynamic>
            : data;

        result = {
          'employeeId':
              '${user['employeeId'] ?? user['employee_id'] ?? result['employeeId']}',
          'fullName':
              '${user['fullName'] ?? user['fullname'] ?? user['name'] ?? result['fullName']}',
          'email': '${user['email'] ?? result['email']}',
          'role': '${user['roleName'] ?? user['role'] ?? result['role']}'
              .toUpperCase(),
          'division': '${user['division'] ?? result['division']}',
          'grade': '${user['grade'] ?? result['grade']}',
          'isActive': true,
          'permissions': user['permissions'] is List
              ? (user['permissions'] as List).map((e) => '$e').toList()
              : (result['permissions'] as List<String>),
          'deviceId': sessionManager.deviceId ?? '-',
        };
      }
    } catch (_) {
      // Keep session fallback when profile endpoint is unavailable.
    }

    return result;
  }

  @override
  Future<void> logout() async {
    await taskDraftStorage.clearAllDrafts();
    sessionManager.logout();
  }

  Map<String, dynamic> _fromSession() {
    final employeeId = sessionManager.employeeId ?? '-';
    return {
      'employeeId': employeeId,
      'fullName': sessionManager.fullName ?? '-',
      'email': '${employeeId.toLowerCase()}@system.com',
      'role': (sessionManager.role ?? '-').toUpperCase(),
      'division': sessionManager.divisionName ?? '-',
      'grade': sessionManager.jabatan ?? '-',
      'isActive': sessionManager.isLoggedIn,
      'permissions': sessionManager.permissions,
      'deviceId': sessionManager.deviceId ?? '-',
    };
  }
}
