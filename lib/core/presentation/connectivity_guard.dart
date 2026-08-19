/*
Tujuan: Overlay global untuk kondisi tidak ada internet / server tidak
        merespons. Menampilkan notif (SnackBar) dan dialog modal sekali per
        episode dengan opsi "Keluar" (logout ke /login) dan "Coba Lagi".
Caller: main.dart (MaterialApp.builder), ConnectivityMonitor.
Dependensi: ConnectivityMonitor, SessionManager, appRouter (go_router),
            AppColors.
Main Functions: ConnectivityGuard.
Side Effects: Menampilkan SnackBar + AlertDialog global; pada Keluar:
              SessionManager.logout() + navigasi /login.
*/

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../di/injection.dart';
import '../router/app_router.dart';
import '../session/session_manager.dart';
import '../services/connectivity_monitor.dart';
import '../utils/app_messages.dart';

/// Wraps the app Navigator and reacts to global connectivity changes.
class ConnectivityGuard extends StatefulWidget {
  const ConnectivityGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGuard> createState() => _ConnectivityGuardState();
}

class _ConnectivityGuardState extends State<ConnectivityGuard> {
  late final ConnectivityMonitor _monitor = sl<ConnectivityMonitor>();
  bool _dialogShowing = false;
  BuildContext? _dialogContext;

  @override
  void initState() {
    super.initState();
    _monitor.status.addListener(_onStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStatusChanged();
    });
  }

  @override
  void dispose() {
    _monitor.status.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    final s = _monitor.status.value;
    if (s == ConnectionStatus.online) {
      _closeDialog();
      return;
    }
    if (_dialogShowing || !mounted) return;

    _dialogShowing = true;
    final isServerDown = s == ConnectionStatus.serverDown;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          isServerDown ? AppMessages.http503 : AppMessages.net001,
        ),
        backgroundColor: AppColors.statusLocked,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
    if (navContext == null) {
      _dialogShowing = false;
      return;
    }
    showDialog<void>(
      context: navContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _dialogContext = dialogCtx;
        return PopScope(
          canPop: false,
          child: _OfflineDialog(
            isServerDown: isServerDown,
            onRetry: _onRetry,
            onExit: _onExit,
          ),
        );
      },
    );
  }

  Future<void> _onRetry() async {
    await _monitor.recheck();
    if (_monitor.status.value == ConnectionStatus.online) {
      _closeDialog();
    }
  }

  void _onExit() {
    sl<SessionManager>().logout();
    _closeDialog();
    appRouter.go('/login');
  }

  void _closeDialog() {
    final ctx = _dialogContext;
    _dialogContext = null;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).pop();
    }
    _dialogShowing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _OfflineDialog extends StatelessWidget {
  const _OfflineDialog({
    required this.isServerDown,
    required this.onRetry,
    required this.onExit,
  });

  final bool isServerDown;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(
        isServerDown ? Icons.dns_outlined : Icons.wifi_off_rounded,
        color: AppColors.statusLocked,
        size: 40,
      ),
      title: Text(
        isServerDown ? 'Server Tidak Merespons' : 'Koneksi Terputus',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
      ),
      content: Text(
        isServerDown ? AppMessages.http503 : AppMessages.net001,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: onExit,
          child: Text('Keluar', style: TextStyle(color: AppColors.textMuted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
          ),
          onPressed: onRetry,
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }
}
