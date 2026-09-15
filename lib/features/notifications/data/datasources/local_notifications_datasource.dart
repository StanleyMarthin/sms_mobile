/*
Tujuan: Datasource lokal notifikasi untuk mode dummy/offline development.
Caller: NotificationsRepositoryImpl saat local datasource dipakai.
Dependensi: DummyNotificationsData.
Main Functions: LocalNotificationsDataSource.getNotifications.
Side Effects: Tidak ada.
*/
library;

import '../../../../core/data/dummy_data.dart';

abstract class NotificationsDataSource {
  Future<List<Map<String, dynamic>>> getNotifications({required String? role});
}

class LocalNotificationsDataSource implements NotificationsDataSource {
  @override
  Future<List<Map<String, dynamic>>> getNotifications({
    required String? role,
  }) async {
    return DummyNotificationsData.all().where((item) {
      final roles = (item['roles'] as List).cast<String>();
      return role == null || roles.contains(role);
    }).toList();
  }
}
