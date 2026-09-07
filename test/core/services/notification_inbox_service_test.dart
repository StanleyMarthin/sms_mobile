/*
Tujuan: Menjaga inbox notifikasi mobile bisa merge history backend dengan push
        lokal tanpa duplikasi dan tanpa menghidupkan ulang status unread lokal.
Caller: flutter test.
Dependensi: flutter_test, shared_preferences, NotificationInboxService.
Side Effects: Tidak ada.
*/
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sm_system/core/services/notification_inbox_service.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/notifications/domain/entities/notification_item.dart';

void main() {
  group('NotificationInboxService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'merges remote items, keeps local read state, and sorts newest first',
      () async {
        final service = NotificationInboxService(
          storage: _FakeStorage('user-1'),
        );

        await service.mergeRemoteItems([
          NotificationItem(
            id: 'notif-1',
            title: 'Server',
            body: 'Lama',
            isRead: false,
            createdAt: '2026-09-01T08:00:00.000Z',
            targetRoute: '/notifications',
          ),
        ]);
        await service.markAllRead();

        await service.mergeRemoteItems([
          NotificationItem(
            id: 'notif-1',
            title: 'Server',
            body: 'Lama dari backend',
            isRead: false,
            createdAt: '2026-09-01T08:00:00.000Z',
            targetRoute: '/work-orders?woId=WO-1',
          ),
          NotificationItem(
            id: 'notif-2',
            title: 'Server Baru',
            body: 'Baru',
            isRead: false,
            createdAt: '2026-09-02T08:00:00.000Z',
            targetRoute: '/countdown?carId=CAR-1',
          ),
        ]);

        expect(service.items, hasLength(2));
        expect(service.items.first.id, 'notif-2');
        expect(service.items.first.isRead, isFalse);
        expect(service.items.last.id, 'notif-1');
        expect(service.items.last.isRead, isTrue);
        expect(service.unreadCount, 1);
      },
    );

    test('persists merged remote items under active user key', () async {
      final service = NotificationInboxService(storage: _FakeStorage('user-2'));

      await service.mergeRemoteItems([
        NotificationItem(
          id: 'notif-3',
          title: 'QC',
          body: 'Ready',
          isRead: false,
          createdAt: '2026-09-03T08:00:00.000Z',
          targetRoute: '/qc?qcId=123',
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('notification_inbox_user-2');
      expect(stored, contains('notif-3'));
      expect(stored, contains('/qc?qcId=123'));
    });
  });
}

class _FakeStorage {
  _FakeStorage(this.userId);

  final String userId;

  Future<String?> read({required String key}) async {
    if (key == SessionManager.keyUserId) {
      return userId;
    }
    return null;
  }
}
