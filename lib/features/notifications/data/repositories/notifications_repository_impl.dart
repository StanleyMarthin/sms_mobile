library;

import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({required this.dataSource});

  final NotificationsDataSource dataSource;

  @override
  Future<List<NotificationItem>> getNotifications(
      {required String? role}) async {
    final items = await dataSource.getNotifications(role: role);
    return items
        .map(
          (item) => NotificationItem(
            id: item['id'] as String,
            title: item['title'] as String,
            body: item['body'] as String,
            isRead: item['isRead'] as bool,
            createdAt: item['createdAt'] as String,
            targetRoute: item['targetRoute'] as String? ?? '/notifications',
          ),
        )
        .toList();
  }
}
