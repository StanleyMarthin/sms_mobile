import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/device_init_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final DeviceInitUseCase deviceInitUseCase;
  final LoginUseCase loginUseCase;

  AuthBloc({
    required this.deviceInitUseCase,
    required this.loginUseCase,
  }) : super(const AuthInitial()) {
    on<DeviceInitRequested>(_onDeviceInit);
    on<LoginRequested>(_onLogin);
  }

  Future<void> _onDeviceInit(
    DeviceInitRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Verifikasi perangkat...'));
    final result = await deviceInitUseCase(
      DeviceInitParams(deviceInfo: event.deviceInfo),
    );
    result.fold(
      (failure) => emit(AuthError(
        message: failure.message ?? 'Device init gagal',
        errorCode: failure.errorCode,
      )),
      (data) => emit(DeviceInitSuccess(result: data)),
    );
  }

  Future<void> _onLogin(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading(message: 'Masuk...'));
    final result = await loginUseCase(
      LoginParams(
        employeeId: event.employeeId,
        password: event.password,
        fcmToken: event.fcmToken,
      ),
    );
    result.fold(
      (failure) => emit(AuthError(
        message: failure.message ?? 'Login gagal',
        errorCode: failure.errorCode,
      )),
      (data) => emit(LoginSuccess(result: data)),
    );
  }
}
