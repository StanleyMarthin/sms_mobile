import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/login_result.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  final String employeeId;
  final String password;
  final String? fcmToken;

  LoginParams({
    required this.employeeId,
    required this.password,
    this.fcmToken,
  });
}

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase({required this.repository});

  Future<Either<Failure, LoginResult>> call(LoginParams params) {
    return repository.login(
      employeeId: params.employeeId,
      password: params.password,
      fcmToken: params.fcmToken,
    );
  }
}
