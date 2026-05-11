import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../router/app_router.dart';
import '../constants/app_colors.dart';
import 'fcm_service.dart';

class AlarmTimerService {
  static final AlarmTimerService _instance = AlarmTimerService._internal();
  factory AlarmTimerService() => _instance;
  AlarmTimerService._internal();

  bool _isAlarmShowing = false;

  /// Memutar suara notifikasi berulang beberapa kali dengan jeda wait
  Future<void> playReminder(int times, {String? taskId, String? unitName, String? message}) async {
    try {
      // Tampilkan popup jika di foreground
      if (unitName != null) {
        showForegroundAlarm(
          title: 'Reminder Pekerjaan',
          message: message ?? 'Waktu pengerjaan $unitName hampir habis.',
          isCritical: times >= 3,
        );
        
        // Munculkan notifikasi sistem juga sebagai backup popup
        FCMService().showLocalNotification(
          id: taskId.hashCode,
          title: 'SMS Alarm: $unitName',
          body: message ?? 'Waktu pengerjaan hampir habis.',
          isAlarm: true,
        );
      }

      for (int i = 0; i < times; i++) {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.notification,
          ios: IosSounds.glass,
          looping: false,
          volume: 1.0,
        );
        if (i < times - 1) {
          // Tunggu sebentar agar suara notifikasi selesai
          await Future.delayed(const Duration(milliseconds: 2500));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AlarmTimerService] gagal memutar suara notif: $e');
      }
    }
  }

  /// Memutar dering saat waktu benar-benar habis (bunyi 3x)
  Future<void> playFinalAlarm({String? taskId, String? unitName}) async {
    await playReminder(
      3,
      taskId: taskId,
      unitName: unitName,
      message: 'Waktu pengerjaan $unitName sudah HABIS! Mohon segera submit progress.',
    );
  }

  /// Menampilkan dialog alarm di foreground menggunakan context global
  void showForegroundAlarm({
    required String title,
    required String message,
    bool isCritical = false,
  }) {
    if (_isAlarmShowing) return;

    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;

    _isAlarmShowing = true;

    if (isCritical) {
      // Full screen alarm for critical state
      appRouter.push('/alarm', extra: {
        'title': title,
        'message': message,
        'isCritical': true,
      }).then((_) => _isAlarmShowing = false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !isCritical,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isCritical ? AppColors.statusLocked : AppColors.gold,
            width: 2,
          ),
        ),
        icon: Icon(
          isCritical ? Icons.report_problem_rounded : Icons.alarm_on_rounded,
          color: isCritical ? AppColors.statusLocked : AppColors.gold,
          size: 48,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isCritical ? AppColors.statusLocked : AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                _isAlarmShowing = false;
                Navigator.pop(ctx);
                FlutterRingtonePlayer().stop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: isCritical ? AppColors.statusLocked : AppColors.gold,
                foregroundColor: AppColors.background,
              ),
              child: const Text('SAYA MENGERTI'),
            ),
          ),
        ],
      ),
    ).then((_) => _isAlarmShowing = false);
  }
}
