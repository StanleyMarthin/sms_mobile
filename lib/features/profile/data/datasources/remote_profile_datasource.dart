/*
Tujuan: Remote datasource untuk mengambil profil user dan fallback session lokal.
Caller: ProfileRepositoryImpl/ProfilePage.
Dependensi: ApiClient, ApiEndpoints, SessionManager, TaskDraftStorage.
Main Functions: RemoteProfileDataSource.getProfile(), clearLocalDrafts().
Side Effects: HTTP GET profile, clear draft task lokal.
*/

import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../../task_execution/data/datasources/task_draft_storage.dart';
import 'profile_datasource.dart';

class RemoteProfileDataSource implements ProfileDataSource {
  RemoteProfileDataSource({
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

        // Coba beberapa alias field foto yang mungkin dipakai backend
        final rawPhoto =
            user['photoUrl'] ??
            user['photo_url'] ??
            user['profilePhoto'] ??
            user['avatar_url'] ??
            user['avatarUrl'];
        String? photoUrl = (rawPhoto is String && rawPhoto.trim().isNotEmpty)
            ? rawPhoto.trim()
            : null;

        // Wrap dengan proxy backend untuk menghindari blokir .r2.dev dari ISP lokal
        if (photoUrl != null && photoUrl.contains('.r2.dev')) {
          final encodedUrl = Uri.encodeComponent(photoUrl);
          // ApiEndpoints.baseUrl mengarah ke auth/gateway origin.
          photoUrl =
              '${ApiEndpoints.baseUrl}/api/v1/proxy/image?url=$encodedUrl';
        }

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
          'photoUrl': photoUrl,
        };
      }
    } catch (e, stack) {
      debugPrint('--- PROFILE DATASOURCE ERROR: $e\n$stack ---');
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
      'photoUrl': null,
    };
  }
}
