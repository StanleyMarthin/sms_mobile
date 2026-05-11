import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

// ──────────────────────────────────────────────────────────────────
// Navigator key — diisi oleh app_router, dipakai untuk navigasi
// dari notifikasi ketika app sedang background/terminated.
// ──────────────────────────────────────────────────────────────────
import '../router/app_router.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'notification_inbox_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  await NotificationInboxService.persistBackgroundMessage(message);
  if (kDebugMode) {
    debugPrint(
      '[FCM] Background message: ${message.messageId} | title=${message.notification?.title}',
    );
  }
}

// Channel Android
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'sm_system_channel',
  'SM System Notifications',
  description: 'Notifikasi sistem Stanley Marthin Workshop',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel _alarmChannel = AndroidNotificationChannel(
  'task_alarm_channel',
  'Alarm Pekerjaan',
  description: 'Waktu Pengerjaan Hampir Habis',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  enableLights: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _messaging;
  bool _initialized = false;

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      _messaging = FirebaseMessaging.instance;
      _initialized = true;

      // -- Init Timezone data --
      tz.initializeTimeZones();

      await _messaging!.setAutoInitEnabled(true);

      // ── Izin notifikasi (Android 13+ & iOS) ─────────────────────
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Jika izin ditolak, aplikasi akan keluar
        return Future.error('NOTIFICATION_PERMISSION_DENIED');
      }

      // ── Setup local notifications (foreground android) ──────────
      if (Platform.isAndroid) {
        final androidPlugin = _localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(_channel);
        await androidPlugin?.createNotificationChannel(_alarmChannel);
      }

      await _localNotif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (details) {
          // User tap notif lokal (foreground)
          _handleMessageData(details.payload ?? '');
        },
      );

      // ── Background messages ──────────────────────────────────────
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // ── Foreground messages: tampilkan sebagai local notification ─
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint(
            '[FCM] Foreground | title=${message.notification?.title}',
          );
        }
        sl<NotificationInboxService>().saveRemoteMessage(message);
        final notif = message.notification;
        final android = message.notification?.android;
        if (notif != null && android != null) {
          _localNotif.show(
            notif.hashCode,
            notif.title,
            notif.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@drawable/ic_notification',
                importance: Importance.max,
                priority: Priority.high,
                color: const Color(0xFFFFCF40),
              ),
            ),
            payload: _buildPayload(message.data),
          );

          // In-App Popup for Reminders (Foreground only)
          final titleLower = (notif.title ?? '').toLowerCase();
          if (titleLower.contains('reminder') || titleLower.contains('pengembalian')) {
            _showInAppPopup(message);
          }
        }
      });

      // ── App dibuka dari notif (saat background) ──────────────────
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[FCM] Opened from background | data=${message.data}');
        }
        _navigateFromMessage(message);
      });

      // ── App dibuka dari notif (saat terminated) ──────────────────
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          debugPrint(
            '[FCM] Opened from terminated | data=${initialMessage.data}',
          );
        }
        // Delay sedikit agar router sudah siap
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _navigateFromMessage(initialMessage);
        });
      }

      // ── Token refresh ────────────────────────────────────────────
      _messaging!.onTokenRefresh.listen((token) {
        if (kDebugMode) {
          debugPrint('[FCM] Token refreshed');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Init Error: $e');
      }
    }
  }

  void _showInAppPopup(RemoteMessage message) {
    final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    
    final title = message.notification?.title ?? 'Reminder';
    final body = message.notification?.body ?? '';

    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: Color(0xFFFFCF40)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(body, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateFromMessage(message);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFCF40),
              foregroundColor: Colors.black,
            ),
            child: const Text('Lihat Detail', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Navigasi berdasarkan payload data dari notifikasi ─────────
  void _navigateFromMessage(RemoteMessage message) {
    final data = message.data;
    final route = NotificationInboxService.resolveRoute(data);
    if (appRouter.routerDelegate.navigatorKey.currentContext != null) {
      appRouter.go(route);
    }
  }

  void _handleMessageData(String payload) {
    if (payload.isEmpty) return;
    // payload == route string yang sudah di-encode oleh _buildPayload
    if (appRouter.routerDelegate.navigatorKey.currentContext != null) {
      appRouter.go(payload);
    }
  }

  String _buildPayload(Map<String, dynamic> data) {
    return NotificationInboxService.resolveRoute(data);
  }

  /// Menampilkan notifikasi lokal secara instan.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    bool isAlarm = false,
    Map<String, dynamic>? data,
  }) async {
    await _localNotif.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isAlarm ? _alarmChannel.id : _channel.id,
          isAlarm ? _alarmChannel.name : _channel.name,
          channelDescription: isAlarm ? _alarmChannel.description : _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: isAlarm,
          category: isAlarm ? AndroidNotificationCategory.alarm : null,
          color: const Color(0xFFFFCF40),
          enableVibration: true,
          vibrationPattern: isAlarm ? Int64List.fromList([0, 500, 200, 500]) : null,
        ),
      ),
      payload: data != null ? _buildPayload(data) : null,
    );
  }

  Future<String?> getToken() async {
    if (!_initialized || _messaging == null) {
      return null;
    }
    try {
      return await _messaging!.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] GetToken Error: $e');
      }
      return null;
    }
  }

  /// Mengirim notifikasi via backend sm_notification (Port 8084).
  /// Dipakai untuk trigger push notif ke diri sendiri atau orang lain secara resmi.
  Future<void> sendRemoteNotification({
    required String employeeId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await sl<ApiClient>().post(
        ApiEndpoints.notifySend,
        data: {
          'target': {
            'type': 'employee',
            'employeeIds': [employeeId],
          },
          'notification': {
            'title': title,
            'body': body,
            if (data != null) 'data': data,
          },
          'source': 'mobile_app',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] sendRemoteNotification Error: $e');
      }
    }
  }

  // ── Alarm Scheduling (Background support) ──────────────────
  
  /// Menjadwalkan alarm pengerjaan (T-10, T-5, T-0).
  /// [taskId] dipakai untuk ID notifikasi unik agar bisa di-cancel.
  Future<void> scheduleTaskAlarms({
    required String taskId,
    required DateTime startedAt,
    required double targetHours,
    required String unitName,
  }) async {
    final targetTime = startedAt.add(Duration(seconds: (targetHours * 3600).round()));
    final now = DateTime.now();

    // 10 Menit sebelum selesai
    _scheduleSingleAlarm(
      id: taskId.hashCode + 10,
      title: 'Reminder Selesai (10 Menit)',
      body: 'Pekerjaan $unitName tersisa 10 menit lagi.',
      scheduledDate: targetTime.subtract(const Duration(minutes: 10)),
      now: now,
    );

    // 5 Menit sebelum selesai
    _scheduleSingleAlarm(
      id: taskId.hashCode + 5,
      title: 'Reminder Selesai (5 Menit)',
      body: 'Pekerjaan $unitName tersisa 5 menit lagi.',
      scheduledDate: targetTime.subtract(const Duration(minutes: 5)),
      now: now,
    );

    // Waktu habis
    _scheduleSingleAlarm(
      id: taskId.hashCode + 0,
      title: 'Waktu Pengerjaan Habis!',
      body: 'Segera selesaikan dan submit progress $unitName.',
      scheduledDate: targetTime,
      now: now,
    );
  }

  Future<void> _scheduleSingleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required DateTime now,
  }) async {
    if (scheduledDate.isBefore(now)) return;

    await _localNotif.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannel.id,
          _alarmChannel.name,
          channelDescription: _alarmChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: AndroidNotificationCategory.alarm,
          ticker: 'ALARM WORKSHOP',
          ongoing: false,
          color: const Color(0xFFFFCF40),
          sound: const RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 1000]),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskAlarms(String taskId) async {
    await _localNotif.cancel(taskId.hashCode + 10);
    await _localNotif.cancel(taskId.hashCode + 5);
    await _localNotif.cancel(taskId.hashCode + 0);
  }
}
