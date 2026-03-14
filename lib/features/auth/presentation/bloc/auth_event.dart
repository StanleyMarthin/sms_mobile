import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered on splash: POST /auth/device-init
class DeviceInitRequested extends AuthEvent {
  final Map<String, dynamic> deviceInfo;

  const DeviceInitRequested({required this.deviceInfo});

  @override
  List<Object?> get props => [deviceInfo];
}

/// Triggered on login form submit: POST /auth/login
class LoginRequested extends AuthEvent {
  final String employeeId;
  final String password;
  final String? fcmToken;

  const LoginRequested({
    required this.employeeId,
    required this.password,
    this.fcmToken,
  });

  @override
  List<Object?> get props => [employeeId, password, fcmToken];
}
