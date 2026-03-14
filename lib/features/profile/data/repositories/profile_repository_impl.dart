library;

import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/local_profile_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({required this.dataSource});

  final ProfileDataSource dataSource;

  @override
  Future<ProfileData> getProfile() async {
    final item = await dataSource.getProfile();
    return ProfileData(
      employeeId: item['employeeId'] as String,
      fullName: item['fullName'] as String,
      email: item['email'] as String,
      role: item['role'] as String,
      division: item['division'] as String,
      grade: item['grade'] as String,
      isActive: item['isActive'] as bool,
      permissions: (item['permissions'] as List).cast<String>(),
      deviceId: item['deviceId'] as String,
    );
  }

  @override
  Future<void> logout() async {
    await dataSource.logout();
  }
}