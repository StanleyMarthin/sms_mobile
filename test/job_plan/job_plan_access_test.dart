/*
Tujuan: Mengunci akses menu/route Job Plan berbasis permission backend.
Caller: Flutter test runner.
Dependensi: SessionManager dan JobPlanAccess.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_access.dart';

class _MemoryStorage {
  final Map<String, String> values = {};
  Future<String?> read({required String key}) async => values[key];
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  Future<void> delete({required String key}) async => values.remove(key);
}

void main() {
  test(
    'canonical routes preserve permission checks and reject unknown routes',
    () async {
      final session = await _session(const ['TASK_VIEW']);
      expect(JobPlanAccess.canOpenRoute(session, '/plans'), isTrue);
      expect(JobPlanAccess.canOpenRoute(session, '/plans/create'), isFalse);
      expect(JobPlanAccess.canOpenRoute(session, '/plans/approval'), isFalse);
      expect(JobPlanAccess.canOpenRoute(session, '/plans/unknown'), isFalse);
    },
  );

  test(
    'legacy deep-link routes are hidden when backend permissions are absent',
    () async {
      final session = await _session(const []);

      expect(JobPlanAccess.canOpenAny(session), isFalse);
      expect(JobPlanAccess.canOpenRoute(session, '/job-plans/v2'), isFalse);
    },
  );

  test('planning permission exposes V2 list create and calendar', () async {
    final session = await _session(const ['CREATE_TASK']);

    expect(JobPlanAccess.canCreate(session), isTrue);
    expect(JobPlanAccess.canOpenRoute(session, '/job-plans/v2'), isTrue);
    expect(JobPlanAccess.canOpenRoute(session, '/job-plans/v2/create'), isTrue);
    expect(
      JobPlanAccess.canOpenRoute(session, '/job-plans/v2/calendar'),
      isTrue,
    );
  });

  test('review permission exposes approval and tracking', () async {
    final session = await _session(const ['REVIEW_TASK']);

    expect(JobPlanAccess.canApprove(session), isTrue);
    expect(
      JobPlanAccess.canOpenRoute(session, '/job-plans/v2/approval'),
      isTrue,
    );
    expect(
      JobPlanAccess.canOpenRoute(session, '/job-plans/v2/approval-tracking'),
      isTrue,
    );
  });

  test(
    'monitoring permission exposes monitor and final validation only',
    () async {
      final session = await _session(const ['LIST_CAR_PROGRESS']);

      expect(
        JobPlanAccess.canOpenRoute(session, '/job-plans/v2/monitoring'),
        isTrue,
      );
      expect(
        JobPlanAccess.canOpenRoute(session, '/job-plans/v2/validation'),
        isTrue,
      );
      expect(
        JobPlanAccess.canOpenRoute(session, '/job-plans/v2/approval'),
        isFalse,
      );
    },
  );

  test('operator execution access stays on task route only', () async {
    final session = await _session(const ['TASK_EXECUTE']);

    expect(JobPlanAccess.canExecute(session), isTrue);
    expect(JobPlanAccess.canOpenAny(session), isFalse);
    expect(
      JobPlanAccess.canOpenRoute(session, '/job-plans/v2/approval'),
      isFalse,
    );
  });

  test('calendar permission follows backend task view permission', () async {
    final session = await _session(const ['TASK_VIEW']);

    expect(JobPlanAccess.canTrack(session), isTrue);
    expect(
      JobPlanAccess.canOpenRoute(session, '/job-plans/v2/calendar'),
      isTrue,
    );
  });
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
