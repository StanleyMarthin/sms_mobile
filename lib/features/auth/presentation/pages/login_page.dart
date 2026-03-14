import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/session_manager.dart';
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
  void _handleLogin() {
    final id = _idController.text.trim().toUpperCase();
    final password = _passwordController.text;

    if (id.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Employee ID dan password harus diisi');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    _authBloc.add(LoginRequested(employeeId: id, password: password));
  }

  void _onAuthState(BuildContext context, AuthState state) {
    if (state is LoginSuccess) {
      final result = state.result;
      sl<SessionManager>().login(
        token: result.token,
        userId: result.userId,
        employeeId: _idController.text.trim().toUpperCase(),
        fullName: result.fullname,
        role: result.roleName,
        divisionName: result.division,
        jabatan: result.grade,
        divisionId: result.divisionId,
        permissions: result.permissions,
      );
      if (mounted) context.go('/home');
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
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    _buildBranding(),
                    const SizedBox(height: 40),
                    _buildLoginForm(),
                    const SizedBox(height: 40),
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
        const SizedBox(height: 20),
        const Text(
          'Stanley Marthin System',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Employee ID field
          TextField(
            controller: _idController,
            style: const TextStyle(color: AppColors.textPrimary),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Employee ID',
              hintText: 'e.g. EMP002',
              prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          // Password field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: AppColors.textPrimary),
            onSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppColors.textMuted),
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
          const SizedBox(height: 8),

          // Error message
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.statusLocked, fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),

          // Sign In button
          FilledButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.background),
                    ),
                  )
                : const Text('Sign In',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
