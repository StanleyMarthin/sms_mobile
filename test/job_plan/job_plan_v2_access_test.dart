/*
Tujuan: Mengunci akses menu/route Job Plan V2 berbasis permission backend.
Caller: Flutter test runner.
Dependensi: SessionManager dan JobPlanV2Access.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_v2_access.dart';

class _MemoryStorage {
  final Map<String, String> values = {};
  Future<String?> read({required String key}) async => values[key];
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  Future<void> delete({required String key}) async => values.remove(key);
}

void main() {
  test('V2 routes are hidden when backend permissions are absent', () async {
    final session = await _session(const []);

    expect(JobPlanV2Access.canOpenAny(session), isFalse);
    expect(JobPlanV2Access.canOpenRoute(session, '/job-plans/v2'), isFalse);
  });

  test('planning permission exposes V2 list create and calendar', () async {
    final session = await _session(const ['CREATE_TASK']);

    expect(JobPlanV2Access.canCreate(session), isTrue);
    expect(JobPlanV2Access.canOpenRoute(session, '/job-plans/v2'), isTrue);
    expect(
      JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/create'),
      isTrue,
    );
    expect(
      JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/calendar'),
      isTrue,
    );
  });

  test('review permission exposes approval and tracking', () async {
    final session = await _session(const ['REVIEW_TASK']);

    expect(JobPlanV2Access.canApprove(session), isTrue);
    expect(
      JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/approval'),
      isTrue,
    );
    expect(
      JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/approval-tracking'),
      isTrue,
    );
  });

  test(
    'monitoring permission exposes monitor and final validation only',
    () async {
      final session = await _session(const ['LIST_CAR_PROGRESS']);

      expect(
        JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/monitoring'),
        isTrue,
      );
      expect(
        JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/validation'),
        isTrue,
      );
      expect(
        JobPlanV2Access.canOpenRoute(session, '/job-plans/v2/approval'),
        isFalse,
      );
    },
  );
}

Future<SessionManager> _session(List<String> permissions) async {
  final session = SessionManager(storage: _MemoryStorage());
  await session.login(
    token: 'token',
    refreshToken: 'refresh',
    userId: 'U-1',
    employeeId: 'U-1',
    fullName: 'User',
    role: 'custom',
    divisionName: 'Interior',
    jabatan: 'Staff',
    divisionId: 1,
    permissions: permissions,
    accessBucket: permissions.isEmpty ? 'FIELD' : 'KD',
    mobileEnabled: true,
  );
  return session;
}
