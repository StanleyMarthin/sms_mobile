/*
Tujuan: Memverifikasi caching ProfileRepository supaya fetch profil tidak berulang saat UI rebuild.
Caller: Flutter test suite untuk fitur profile.
Dependensi: flutter_test, ProfileRepositoryImpl, ProfileDataSource.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/profile/data/datasources/profile_datasource.dart';
import 'package:sm_system/features/profile/data/repositories/profile_repository_impl.dart';

void main() {
  test('getProfile reuses the in-flight profile request', () async {
    final dataSource = _FakeProfileDataSource();
    final repository = ProfileRepositoryImpl(dataSource: dataSource);

    final results = await Future.wait([
      repository.getProfile(),
      repository.getProfile(),
    ]);

    expect(dataSource.getProfileCalls, 1);
    expect(results.first.photoUrl, 'https://example.com/avatar.jpg');
    expect(results.last.fullName, 'Tester');
  });

  test('logout clears cached profile request', () async {
    final dataSource = _FakeProfileDataSource();
    final repository = ProfileRepositoryImpl(dataSource: dataSource);

    await repository.getProfile();
    await repository.logout();
    await repository.getProfile();

    expect(dataSource.getProfileCalls, 2);
    expect(dataSource.logoutCalls, 1);
  });

  test('failed profile request is not cached', () async {
    final dataSource = _FakeProfileDataSource(failFirstRequest: true);
    final repository = ProfileRepositoryImpl(dataSource: dataSource);

    await expectLater(repository.getProfile(), throwsStateError);
    final profile = await repository.getProfile();

    expect(dataSource.getProfileCalls, 2);
    expect(profile.fullName, 'Tester');
  });
}

class _FakeProfileDataSource implements ProfileDataSource {
  _FakeProfileDataSource({this.failFirstRequest = false});

  final bool failFirstRequest;
  int getProfileCalls = 0;
  int logoutCalls = 0;

  @override
  Future<Map<String, dynamic>> getProfile() async {
    getProfileCalls += 1;
    if (failFirstRequest && getProfileCalls == 1) {
      throw StateError('profile unavailable');
    }
    return {
      'employeeId': 'SM-1',
      'fullName': 'Tester',
      'email': 'tester@example.com',
      'role': 'MECHANIC',
      'division': 'WORKSHOP',
      'grade': 'STAFF',
      'isActive': true,
      'permissions': <String>[],
      'deviceId': 'device-1',
      'photoUrl': 'https://example.com/avatar.jpg',
    };
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}
