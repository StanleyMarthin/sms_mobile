import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Login page with dark luxury theme matching the SM Workshop UI.
///
/// Features:
/// - Demo account quick-login buttons
/// - Manual employee ID + password login
/// - Gold accent branding for classic car restoration aesthetic
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>();
  }

  @override
  void dispose() {
    _authBloc.close();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Login via BLoC ─────────────────────────────────────────
  Future<void> _handleLogin() async {
    final id = _sanitizeEmployeeId(_idController.text);
    final password = _passwordController.text.trim();
    final validationError = _validateCredentials(
      employeeId: id,
      password: password,
    );

    _idController.value = _idController.value.copyWith(
      text: id,
      selection: TextSelection.collapsed(offset: id.length),
    );
    _passwordController.value = _passwordController.value.copyWith(
      text: password,
      selection: TextSelection.collapsed(offset: password.length),
    );

    if (validationError != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    String? fcmToken;
    try {
      // Retry sampai 3x dengan jeda 1 detik agar Firebase punya waktu init
      for (int attempt = 0; attempt < 3; attempt++) {
        fcmToken = await FCMService().getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) break;
        await Future<void>.delayed(Duration(seconds: 1));
      }
    } catch (_) {
      fcmToken = null;
    }

    if (!mounted) return;
    _authBloc.add(
      LoginRequested(employeeId: id, password: password, fcmToken: fcmToken),
    );
  }

  String _sanitizeEmployeeId(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String? _validateCredentials({
    required String employeeId,
    required String password,
  }) {
    if (employeeId.isEmpty || password.isEmpty) {
      return 'Employee ID dan password harus diisi';
    }
    if (!RegExp(r'^[A-Z0-9._-]{3,20}$').hasMatch(employeeId)) {
      return 'Format Employee ID tidak valid.';
    }
    if (password.length < 8) {
      return 'Password minimal 8 karakter.';
    }
    return null;
  }

  void _onAuthState(BuildContext context, AuthState state) async {
    if (state is LoginSuccess) {
      final result = state.result;
      await sl<SessionManager>().login(
        token: result.token,
        refreshToken: result.refreshToken,
        userId: result.userId,
        employeeId: _idController.text.trim().toUpperCase(),
        fullName: result.fullname,
        role: result.roleName,
        divisionName: result.division,
        jabatan: result.grade,
        divisionId: result.divisionId,
        permissions: result.permissions,
        accessBucket: result.accessBucket,
        roleLevel: result.roleLevel,
        scopeBasis: result.scopeBasis,
        webEnabled: result.webEnabled,
        mobileEnabled: result.mobileEnabled,
        approvalRank: result.approvalRank,
        canViewAllUnits: result.canViewAllUnits,
        canViewAssignedUnits: result.canViewAssignedUnits,
        managedDivisionIds: result.managedDivisionIds,
        managedUnitIds: result.managedUnitIds,
      );
      if (!context.mounted) return;
      context.go('/home');
    } else if (state is AuthError) {
      setState(() {
        _isLoading = false;
        _errorMessage = state.message;
      });
      AppNotification.showError(context, state.message);
    } else if (state is AuthLoading) {
      setState(() => _isLoading = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: _authBloc,
      listener: _onAuthState,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 24),
                    _buildBranding(),
                    SizedBox(height: 40),
                    _buildLoginForm(),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        // Logo
        ClipOval(
          child: Image.asset(
            'assets/images/sm.jpeg',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Stanley Marthin System',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Classic Restoration Garage',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign In',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 20),

          // Employee ID field
          TextField(
            controller: _idController,
            style: TextStyle(color: AppColors.textPrimary),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Employee ID',
              hintText: 'e.g. SM-00.000',
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(height: 16),

          // Password field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: AppColors.textPrimary),
            onSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
              prefixIcon: Icon(
                Icons.lock_outline,
                color: AppColors.textMuted,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Error message
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(
                color: AppColors.statusLocked,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 8),
          ],

          SizedBox(height: 16),

          // Sign In button
          FilledButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.background,
                      ),
                    ),
                  )
                : Text(
                    'Sign In',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
