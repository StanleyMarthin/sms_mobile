/*
Tujuan: Repository notifikasi yang mengubah payload datasource menjadi entity mobile.
Caller: DI dan NotificationsPage.
Dependensi: NotificationsDataSource, NotificationItem.
Main Functions: getNotifications.
Side Effects: Delegasi HTTP/local datasource.
*/
library;

import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({required this.dataSource});

  final NotificationsDataSource dataSource;

  @override
  Future<List<NotificationItem>> getNotifications({
    required String? role,
  }) async {
    final items = await dataSource.getNotifications(role: role);
    return items.map(NotificationItem.fromMap).toList();
  }
}
