import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_init_result.dart';
import '../repositories/auth_repository.dart';

class DeviceInitParams {
  final Map<String, dynamic> deviceInfo;
  const DeviceInitParams({required this.deviceInfo});
}

class DeviceInitUseCase {
  final AuthRepository repository;
  const DeviceInitUseCase({required this.repository});

  Future<Either<Failure, DeviceInitResult>> call(DeviceInitParams params) {
    return repository.deviceInit(deviceInfo: params.deviceInfo);
  }
}
