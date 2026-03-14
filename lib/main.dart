import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  initDependencies();
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
