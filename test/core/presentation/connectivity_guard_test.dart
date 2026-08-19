/*
Tujuan: Memverifikasi ConnectivityGuard menampilkan dialog + snackbar saat
        offline/server down dan menutupnya saat "Coba Lagi" berhasil.
Caller: Flutter widget test suite.
Dependensi: ConnectivityGuard, ConnectivityMonitor (inject fake), go_router,
            get_it, flutter_test.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sm_system/core/di/injection.dart';
import 'package:sm_system/core/presentation/connectivity_guard.dart';
import 'package:sm_system/core/router/app_router.dart';
import 'package:sm_system/core/services/connectivity_monitor.dart';

void main() {
  testWidgets('server down shows snackbar and dialog with exit/retry',
      (tester) async {
    await sl.reset();
    final monitor = ConnectivityMonitor(
      check: () async => [ConnectivityResult.wifi],
      changes: () => const Stream.empty(),
    );
    sl.registerSingleton<ConnectivityMonitor>(monitor);

    appRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        builder: (context, child) =>
            ConnectivityGuard(child: child ?? const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    monitor.reportServerDown();
    await tester.pump();

    expect(find.text('Server Tidak Merespons'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
    expect(find.textContaining('cukup dulu, bos'), findsWidgets);
  });

  testWidgets('Coba Lagi closes dialog when connection restored',
      (tester) async {
    await sl.reset();
    final monitor = ConnectivityMonitor(
      check: () async => [ConnectivityResult.wifi],
      changes: () => const Stream.empty(),
    );
    sl.registerSingleton<ConnectivityMonitor>(monitor);

    appRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        builder: (context, child) =>
            ConnectivityGuard(child: child ?? const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    monitor.reportServerDown();
    await tester.pump();
    expect(find.text('Coba Lagi'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Server Tidak Merespons'), findsNothing);
  });

  testWidgets('offline sejak launch tetap menampilkan dialog di splash',
      (tester) async {
    await sl.reset();
    final monitor = ConnectivityMonitor(
      check: () async => [ConnectivityResult.none],
      changes: () => const Stream.empty(),
    );
    sl.registerSingleton<ConnectivityMonitor>(monitor);
    monitor.status.value = ConnectionStatus.offline;

    appRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('splash')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: appRouter,
        builder: (context, child) =>
            ConnectivityGuard(child: child ?? const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Koneksi Terputus'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
}
