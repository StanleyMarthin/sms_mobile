import 'dart:io' show Platform;

import 'package:android_id/android_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/device_signing_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Animated splash screen with **device attestation** flow.
///
/// On startup:
/// 1. Collect device info (deviceId, model, OS, appVersion)
/// 2. Call POST /auth/device-init (simulated in MVP)
/// 3. If versionStatus == 'LATEST' → store tempToken, go to /login
/// 4. If versionStatus == 'FORCE_UPDATE' → show update dialog
///
/// The [tempToken] obtained here is ONLY valid for the login endpoint.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final AuthBloc _authBloc;

  String _statusMessage = 'Memuat...';
  bool _hasError = false;
  String? _errorTitle;
  String? _downloadUrl;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();

    _authBloc = sl<AuthBloc>();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Start device attestation after animation settles
    Future.delayed(Duration(milliseconds: 800), _startDeviceInit);
  }

  @override
  void dispose() {
    _authBloc.close();
    _controller.dispose();
    super.dispose();
  }

  // ── Device Attestation Flow ────────────────────────────
  Future<void> _startDeviceInit() async {
    if (!mounted) return;
    if (sl<SessionManager>().isLoggedIn) {
      context.go('/home');
      return;
    }
    setState(() => _statusMessage = 'Verifikasi perangkat...');

    final deviceInfo = await _collectDeviceInfo();
    if (!mounted) return;

    _currentDeviceId = deviceInfo['deviceId'] as String?;
    _authBloc.add(DeviceInitRequested(deviceInfo: deviceInfo));
  }

  void _onAuthState(BuildContext context, AuthState state) async {
    if (state is DeviceInitSuccess) {
      final result = state.result;
      if (result.isLatest) {
        final tempToken = (result.tempToken ?? '').trim();
        if (tempToken.isEmpty) {
          setState(() {
            _hasError = true;
            _errorTitle = 'Gagal Verifikasi';
            _statusMessage =
                'Token verifikasi perangkat tidak valid. Silakan coba lagi.';
            _downloadUrl = null;
          });
          return;
        }

        await sl<SessionManager>().setDeviceAttestation(
          tempToken: tempToken,
          deviceId: _currentDeviceId ?? '',
        );
        await DeviceSigningService().markRegistered();
        setState(() => _statusMessage = 'Perangkat terverifikasi ✓');
        Future.delayed(Duration(milliseconds: 500), () {
          if (!mounted) return;
          this.context.go('/login');
        });
      } else if (result.isForceUpdate) {
        setState(() {
          _hasError = true;
          _errorTitle = 'Update Diperlukan';
          _statusMessage = result.message ?? 'Aplikasi usang, wajib update.';
          _downloadUrl = result.downloadUrl;
        });
      }
    } else if (state is AuthError) {
      if (state.errorCode == 'FORCE_UPDATE') {
        setState(() {
          _hasError = true;
          _errorTitle = 'Update Diperlukan';
          _statusMessage = state.message;
          _downloadUrl = 'required';
        });
        AppNotification.showError(context, state.message);
        return;
      }

      if (state.errorCode == 'DEVICE_NOT_REGISTERED') {
        // Ensure next retry sends public key again for pinning flow.
        DeviceSigningService().resetRegistration();
      }
      setState(() {
        _hasError = true;
        _errorTitle = 'Gagal Verifikasi';
        _statusMessage = state.message;
      });
      AppNotification.showError(context, state.message);
    }
  }

  /// Collects device information.
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final androidIdPlugin = AndroidId();
    final signingService = DeviceSigningService();
    final nowUtc = DateTime.now().toUtc();
    final timestamp = nowUtc.toIso8601String();
    final appVersion = '1.0.1';

    String? androidId;
    if (Platform.isAndroid) {
      try {
        androidId = await androidIdPlugin.getId();
      } catch (_) {
        androidId = null;
      }
    }

    final deviceId = await signingService.buildDeviceIdentity(
      androidId: androidId,
    );
    final signatureExtra = await signingService.buildDeviceInitExtra(
      deviceId: deviceId,
      appVersion: appVersion,
      timestamp: timestamp,
    );

    // Get actual location for sm_user_devices table
    Map<String, double> location = {'lat': -6.200000, 'lng': 106.816666};
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 3),
            ),
          );
          location = {'lat': pos.latitude, 'lng': pos.longitude};
        }
      }
    } catch (_) {}

    return {
      'deviceId': deviceId,
      'deviceModel': Platform.isAndroid ? 'Android Device' : 'iOS Device',
      'osVersion': Platform.operatingSystemVersion,
      'appVersion': appVersion,
      'timestamp': timestamp,
      'location': location,
      'eddsaSignature': signatureExtra['eddsaSignature'],
      if (signatureExtra['devicePublicKey'] != null)
        'devicePublicKey': signatureExtra['devicePublicKey'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: _authBloc,
      listener: _onAuthState,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(flex: 3),

              // ── Animated Logo ────────────────────────────────
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/sm.jpeg',
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 28),

              // ── Company Name ─────────────────────────────────
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Stanley Marthin System',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Classic Car Restoration',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              Spacer(flex: 2),

              // ── Status / Loading ─────────────────────────────
              FadeTransition(
                opacity: _fadeAnimation,
                child: _hasError ? _buildErrorState() : _buildLoadingState(),
              ),

              Spacer(flex: 1),

              // ── Footer ───────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Text(
                    'v1.0.1',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
        SizedBox(height: 14),
        Text(
          _statusMessage,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _downloadUrl != null
                ? Icons.system_update_rounded
                : Icons.error_outline_rounded,
            size: 36,
            color: AppColors.gold,
          ),
          SizedBox(height: 12),
          Text(
            _errorTitle ?? 'Error',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          SizedBox(height: 20),
          if (_downloadUrl != null)
            FilledButton.icon(
              onPressed: _openStore,
              icon: Icon(Icons.download_rounded, size: 18),
              label: Text('Update Sekarang'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            )
          else
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _statusMessage = 'Memuat...';
                });
                _startDeviceInit();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.gold),
                foregroundColor: AppColors.gold,
              ),
              child: Text('Coba Lagi'),
            ),
        ],
      ),
    );
  }

  Future<void> _openStore() async {
    final fallbackUrl = Platform.isIOS
        ? AppConfig.iosStoreUrl
        : AppConfig.androidStoreUrl;
    final rawUrl = (_downloadUrl == null || _downloadUrl == 'required')
        ? fallbackUrl
        : _downloadUrl!;
    final launched = await launchUrl(
      Uri.parse(rawUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      AppNotification.showError(
        context,
        'Tidak dapat membuka halaman update aplikasi.',
      );
    }
  }
}
