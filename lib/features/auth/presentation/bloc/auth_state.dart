import 'package:equatable/equatable.dart';

import '../../domain/entities/device_init_result.dart';
import '../../domain/entities/login_result.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  final String message;

  const AuthLoading({this.message = 'Memuat...'});

  @override
  List<Object?> get props => [message];
}

class DeviceInitSuccess extends AuthState {
  final DeviceInitResult result;

  const DeviceInitSuccess({required this.result});

  @override
  List<Object?> get props => [result];
}

class LoginSuccess extends AuthState {
  final LoginResult result;

  const LoginSuccess({required this.result});

  @override
  List<Object?> get props => [result];
}

class AuthError extends AuthState {
  final String message;
  final String? errorCode;

  const AuthError({required this.message, this.errorCode});

  @override
  List<Object?> get props => [message, errorCode];
}
