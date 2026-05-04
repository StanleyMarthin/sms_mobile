import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class AlarmTimerService {
  static final AlarmTimerService _instance = AlarmTimerService._internal();
  factory AlarmTimerService() => _instance;
  AlarmTimerService._internal();

  /// Memutar suara notifikasi berulang beberapa kali dengan jeda wait
  Future<void> playReminder(int times) async {
    try {
      for (int i = 0; i < times; i++) {
        FlutterRingtonePlayer().playNotification();
        if (i < times - 1) {
          // Tunggu sebentar agar suara notifikasi selesai (durasi wajar = 2.5s)
          await Future.delayed(const Duration(milliseconds: 2500));
        }
      }
    } catch (e) {
      debugPrint('[AlarmTimerService] gagal memutar suara notif: $e');
    }
  }

  /// Memutar dering saat waktu benar-benar habis (bunyi 3x)
  Future<void> playFinalAlarm() async {
    await playReminder(3);
  }
}
