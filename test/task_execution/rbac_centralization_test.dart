import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/auth/rbac.dart';
import 'package:sm_system/core/di/injection.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/auth/data/models/login_model.dart';

class _MemoryStorage {
  final Map<String, String> _values = {};

  Future<String?> read({required String key}) async => _values[key];

  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  test('LoginModel parses centralized role profile and scope payload', () {
    final model = LoginModel.fromJson({
      'token': 'session:SM-08.005',
      'refreshToken': 'refresh-token',
      'user': {
        'userId': 'SM-08.005',
        'fullname': 'Kepala Project Unit',
        'division': 'INTERIOR',
        'grade': 'Kepala Project',
        'roleName': 'kepala_project',
        'divisionId': 8,
        'accessBucket': 'KP',
        'permissions': ['WO_APPROVE', 'APPROVE_WO_PM', 'TASK_VIEW'],
        'roleProfile': {
          'roleLevel': 30,
          'scopeBasis': 'ASSIGNED_UNITS',
          'webEnabled': true,
          'mobileEnabled': true,
          'approvalRank': 3,
        },
        'scope': {
          'canViewAllUnits': false,
          'canViewAssignedUnits': true,
          'managedDivisionIds': [8],
          'unitIds': ['MB500SEL_MRSILMY'],
        },
      },
    });

    expect(model.accessBucket, 'KP');
    expect(model.roleLevel, 30);
    expect(model.scopeBasis, 'ASSIGNED_UNITS');
    expect(model.canViewAssignedUnits, isTrue);
    expect(model.canViewAllUnits, isFalse);
    expect(model.managedDivisionIds, [8]);
    expect(model.managedUnitIds, ['MB500SEL_MRSILMY']);
  });

  test(
    'SessionManager derives compatible role while keeping centralized scope',
    () async {
      final session = SessionManager(storage: _MemoryStorage());
      sl.registerSingleton<SessionManager>(session);

      await session.login(
        token: 'session:SM-08.005',
        refreshToken: 'refresh-token',
        userId: 'SM-08.005',
        employeeId: 'SM-08.005',
        fullName: 'Kepala Project Unit',
        role: 'kepala_project',
        divisionName: 'INTERIOR',
        jabatan: 'Kepala Project',
        divisionId: 8,
        permissions: const ['WO_APPROVE', 'APPROVE_WO_PM', 'TASK_VIEW'],
        accessBucket: 'KP',
        roleLevel: 30,
        scopeBasis: 'ASSIGNED_UNITS',
        mobileEnabled: true,
        approvalRank: 3,
        canViewAssignedUnits: true,
        managedDivisionIds: const [8],
        managedUnitIds: const ['MB500SEL_MRSILMY'],
      );

      expect(session.role, 'kp');
      expect(session.accessBucket, 'KP');
      expect(session.canViewAssignedUnits, isTrue);
      expect(session.canAccessUnit('MB500SEL_MRSILMY'), isTrue);
      expect(session.canAccessUnit('OTHER_UNIT'), isFalse);
      expect(hasPermission(session.role, Permission.woApprovePm), isTrue);
      expect(
        hasPermission(session.role, Permission.dashboardMechanic),
        isFalse,
      );
    },
  );

  test(
    'Execution-only mobile user is driven by permission snapshot, not raw role name',
    () async {
      final session = SessionManager(storage: _MemoryStorage());
      sl.registerSingleton<SessionManager>(session);

      await session.login(
        token: 'session:SM-18.001',
        refreshToken: 'refresh-token',
        userId: 'SM-18.001',
        employeeId: 'SM-18.001',
        fullName: 'Teknisi Lapangan',
        role: 'custom_executor',
        divisionName: 'MEKANIK',
        jabatan: 'Teknisi',
        divisionId: 3,
        permissions: const [
          'TASK_EXECUTE',
          'TASK_SUBMIT',
          'TASK_PENDING',
          'TASK_BREAK',
          'UPLOAD_TICKET',
        ],
        accessBucket: 'FIELD',
        scopeBasis: 'SELF_ONLY',
        mobileEnabled: true,
      );

      expect(session.role, 'op');
      expect(session.isFieldExecution, isTrue);
      expect(hasPermission(session.role, Permission.taskExecute), isTrue);
      expect(hasPermission(session.role, Permission.dashboardMechanic), isTrue);
      expect(hasPermission(session.role, Permission.dashboardKd), isFalse);
    },
  );

  test(
    'KD with mixed planning and execution permissions stays on management access',
    () async {
      final session = SessionManager(storage: _MemoryStorage());
      sl.registerSingleton<SessionManager>(session);

      await session.login(
        token: 'session:SM-17.001',
        refreshToken: 'refresh-token',
        userId: 'SM-17.001',
        employeeId: 'SM-17.001',
        fullName: 'Ketua Divisi Interior',
        role: 'ketua_divisi',
        divisionName: 'INTERIOR',
        jabatan: 'Ketua Divisi',
        divisionId: 8,
        permissions: const [
          'CREATE_TASK',
          'UPDATE_PLAN',
          'VIEW_UNITS',
          'VIEW_COUNTDOWN',
          'VIEW_COUNTDOWN_DETAIL',
          'COUNTDOWN_MARK_QC_READY',
          'COUNTDOWN_REQUEST_REVISION',
          'TASK_VIEW',
          'TASK_ASSIGN',
          'TASK_CHECKPOINT',
          'TASK_PENDING',
          'UPLOAD_TICKET',
          'QC_VIEW',
          'QC_SUBMIT',
          'WO_CREATE',
          'WO_EXTENSION_REQUEST',
          'WO_VIEW',
          'PR_VIEW',
          'PR_CREATE',
          'WAREHOUSE_APPROVE',
          'PROFILE_VIEW',
          'LIST_NOTIFICATIONS',
          'view_assigned_units',
        ],
        accessBucket: 'KD',
        scopeBasis: 'ASSIGNED_DIVISIONS',
        mobileEnabled: true,
        approvalRank: 1,
        canViewAssignedUnits: true,
        managedDivisionIds: const [8],
      );

      expect(session.role, 'kd');
      expect(session.isFieldExecution, isFalse);
      expect(
        hasPermission(session.role, Permission.dashboardMechanic),
        isFalse,
      );
      expect(hasPermission(session.role, Permission.dashboardKd), isTrue);
      expect(hasPermission(session.role, Permission.jobPlanCreate), isTrue);
      expect(hasPermission(session.role, Permission.countdownView), isTrue);
      expect(
        hasPermission(session.role, Permission.countdownMarkQcReady),
        isTrue,
      );
      expect(
        hasPermission(session.role, Permission.countdownRequestRevision),
        isTrue,
      );
      expect(hasPermission(session.role, Permission.qcSubmit), isTrue);
      expect(hasPermission(session.role, Permission.woCreate), isTrue);
      expect(
        hasPermission(session.role, Permission.woExtensionRequest),
        isTrue,
      );
      expect(hasPermission(session.role, Permission.prCreate), isTrue);
      expect(hasPermission(session.role, Permission.warehouseApprove), isTrue);
      expect(hasPermission(session.role, Permission.profileView), isTrue);
    },
  );

  test(
    'Global purchasing style permissions unlock WOV updates and WO extension approvals',
    () async {
      final session = SessionManager(storage: _MemoryStorage());
      sl.registerSingleton<SessionManager>(session);

      await session.login(
        token: 'session:SM-20.001',
        refreshToken: 'refresh-token',
        userId: 'SM-20.001',
        employeeId: 'SM-20.001',
        fullName: 'Purchasing Management',
        role: 'manager_operational',
        divisionName: 'PURCHASING',
        jabatan: 'Manager Operational',
        divisionId: 20,
        permissions: const [
          'WO_EXTENSION_APPROVE',
          'COUNTDOWN_SUBMIT_APPROVAL',
          'WOV_UPDATE',
          'VENDOR_UPDATE_STATUS',
          'VENDOR_RECEIVE',
          'PR_APPROVE',
          'view_all_units',
        ],
        accessBucket: 'GLOBAL',
        scopeBasis: 'GLOBAL',
        mobileEnabled: true,
        canViewAllUnits: true,
      );

      expect(session.isGlobalAccess, isTrue);
      expect(
        hasPermission(session.role, Permission.woExtensionApprove),
        isTrue,
      );
      expect(
        hasPermission(session.role, Permission.countdownSubmitApproval),
        isTrue,
      );
      expect(hasPermission(session.role, Permission.wovUpdate), isTrue);
    },
  );

  test(
    'MIS role is labeled as Super Admin while keeping global scope',
    () async {
      final session = SessionManager(storage: _MemoryStorage());
      sl.registerSingleton<SessionManager>(session);

      await session.login(
        token: 'session:SM-03.003',
        refreshToken: 'refresh-token',
        userId: 'SM-03.003',
        employeeId: 'SM-03.003',
        fullName: 'Tim MIS',
        role: 'mis',
        divisionName: 'MANAGEMENT INFORMATION SYSTEM',
        jabatan: 'Management Information System',
        divisionId: 3,
        permissions: const [
          'PROFILE_VIEW',
          'view_all_units',
          'LIST_CAR_PROGRESS',
        ],
        accessBucket: 'GLOBAL',
        scopeBasis: 'GLOBAL',
        mobileEnabled: true,
        canViewAllUnits: true,
        managedDivisionIds: const [3],
      );

      expect(session.role, 'pm');
      expect(session.accessBucket, 'GLOBAL');
      expect(session.roleLabel, 'Super Admin');
      expect(session.isGlobalAccess, isTrue);
      expect(hasPermission(session.role, Permission.dashboardKd), isTrue);
    },
  );
}
