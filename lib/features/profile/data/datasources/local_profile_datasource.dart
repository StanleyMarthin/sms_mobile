library;

import '../../../../core/session/session_manager.dart';
import '../../../task_execution/data/datasources/task_draft_storage.dart';

abstract class ProfileDataSource {
  Future<Map<String, dynamic>> getProfile();
  Future<void> logout();
}

class LocalProfileDataSource implements ProfileDataSource {
  LocalProfileDataSource({
    required this.sessionManager,
    required this.taskDraftStorage,
  });

  final SessionManager sessionManager;
  final TaskDraftStorage taskDraftStorage;

  @override
  Future<Map<String, dynamic>> getProfile() async {
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

  @override
  Future<void> logout() async {
    await taskDraftStorage.clearAllDrafts();
    sessionManager.logout();
  }
}