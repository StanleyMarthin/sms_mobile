library;

import '../entities/notification_item.dart';

abstract class NotificationsRepository {
  Future<List<NotificationItem>> getNotifications({required String? role});
}
