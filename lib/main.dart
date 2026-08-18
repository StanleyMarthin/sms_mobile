/*
Tujuan: Entry point aplikasi mobile SM Workshop dan inisialisasi runtime global.
Caller: Android/iOS Flutter runner.
Dependensi: DI, router, SessionManager, FCMService, NotificationInboxService, AppTheme.
Main Functions: main(), SmWorkshopApp.
Side Effects: Init session lokal, FCM permission/token, notification inbox, wakelock, runApp.
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/di/injection.dart';
import 'core/constants/app_colors.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_inbox_service.dart';
import 'core/session/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  initDependencies();
  await sl<SessionManager>().init();
  await ThemeController.load();
  await sl<NotificationInboxService>().init();

  try {
    // Wajib dipanggil sebelum runApp agar getToken() tersedia saat login
    // Jika izin notifikasi ditolak, init() akan melempar error
    await FCMService().init();
  } catch (e) {
    if (e == 'NOTIFICATION_PERMISSION_DENIED') {
      // Jika ditolak, keluar dari aplikasi sesuai instruksi
      await SystemNavigator.pop();
      return;
    }
  }

  WakelockPlus.enable();
  runApp(SmWorkshopApp());
}

class SmWorkshopApp extends StatelessWidget {
  const SmWorkshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeController.mode,
      builder: (context, _, __) {
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        AppColors.isLight = ThemeController.effectiveIsLight(brightness);
        return MaterialApp.router(
          title: 'Stanley Marthin System',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(),
          themeMode: ThemeController.themeMode,
          routerConfig: createRouter(),
        );
      },
    );
  }
}
