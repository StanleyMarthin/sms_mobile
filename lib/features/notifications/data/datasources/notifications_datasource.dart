abstract class NotificationsDataSource {
  Future<List<Map<String, dynamic>>> getNotifications({required String? role});
}
