/*
Tujuan: Repository profile yang memetakan response datasource ke entity dan menahan cache profile sesi.
Caller: HomePage, ProfilePage, dan DI ProfileRepository.
Dependensi: ProfileData, ProfileRepository, ProfileDataSource.
Main Functions: ProfileRepositoryImpl.getProfile(), logout().
Side Effects: Memanggil datasource profile/logout; cache in-memory selama sesi.
*/

import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.dataSource});

  final ProfileDataSource dataSource;
  Future<ProfileData>? _profileFuture;

  @override
  Future<ProfileData> getProfile() async {
    final cached = _profileFuture;
    if (cached != null) return cached;

    final pending = _loadProfile();
    _profileFuture = pending;
    try {
      return await pending;
    } catch (_) {
      if (identical(_profileFuture, pending)) {
        _profileFuture = null;
      }
      rethrow;
    }
  }

  Future<ProfileData> _loadProfile() async {
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
      photoUrl: item['photoUrl'] as String?,
    );
  }

  @override
  Future<void> logout() async {
    _profileFuture = null;
    await dataSource.logout();
  }
}
