import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_init_result.dart';
import '../entities/login_result.dart';

/// Abstract repository for authentication operations.
abstract class AuthRepository {
  /// POST /auth/device-init
  Future<Either<Failure, DeviceInitResult>> deviceInit({
    required Map<String, dynamic> deviceInfo,
  });

  /// POST /auth/login
  Future<Either<Failure, LoginResult>> login({
    required String employeeId,
    required String password,
    String? fcmToken,
  });
}
