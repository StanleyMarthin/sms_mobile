library;

import '../../../../core/data/dummy_data.dart';

abstract class NotificationsDataSource {
  Future<List<Map<String, dynamic>>> getNotifications({required String? role});
}

class LocalNotificationsDataSource implements NotificationsDataSource {
  @override
  Future<List<Map<String, dynamic>>> getNotifications(
      {required String? role}) async {
    return DummyNotificationsData.all().where((item) {
      final roles = (item['roles'] as List).cast<String>();
      return role == null || roles.contains(role);
    }).toList();
  }
}
