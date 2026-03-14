import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/device_init_result.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;

  const AuthRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, DeviceInitResult>> deviceInit({
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      final model = await dataSource.deviceInit(deviceInfo);
      return Right(model.toEntity());
    } catch (e) {
      return Left(UnknownFailure(message: 'Device init gagal: $e'));
    }
  }

  @override
  Future<Either<Failure, LoginResult>> login({
    required String employeeId,
    required String password,
    String? fcmToken,
  }) async {
    try {
      final model = await dataSource.login(
        employeeId: employeeId,
        password: password,
        fcmToken: fcmToken,
      );
      return Right(model.toEntity());
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('INVALID_CREDENTIALS')) {
        return const Left(InvalidCredentialsFailure());
      }
      return Left(UnknownFailure(message: 'Login gagal: $e'));
    }
  }
}
