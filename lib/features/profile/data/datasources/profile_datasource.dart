abstract class ProfileDataSource {
  Future<Map<String, dynamic>> getProfile();
  Future<void> logout();
}
