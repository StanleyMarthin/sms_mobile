import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_inbox_service.dart';
import 'core/session/session_manager.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  initDependencies();
  await sl<SessionManager>().init();
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
  runApp(const SmWorkshopApp());
}

class SmWorkshopApp extends StatelessWidget {
  const SmWorkshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stanley Marthin System',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: createRouter(),
    );
  }
}
