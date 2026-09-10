/*
Tujuan: Mengunci mapping read-only Tracking Master Panel di modul Countdown.
Caller: flutter test.
Dependensi: CountdownRepositoryImpl dan entity countdown.
Main Functions: main().
Side Effects: Tidak ada; memakai fake datasource.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/countdown/data/datasources/countdown_datasource.dart';
import 'package:sm_system/features/countdown/data/repositories/countdown_repository_impl.dart';
import 'package:sm_system/features/countdown/presentation/pages/master_panel_tracking_view.dart';

class _FakeCountdownDataSource implements CountdownDataSource {
  Map<String, dynamic>? lastCreatePayload;
  int createCalls = 0;

  @override
  Future<Map<String, dynamic>> getMasterPanelTracking(String unitId) async => {
    'summary': {'total': 2, 'pending': 1, 'progress': 1, 'order': 1, 'done': 0},
    'components': [
      {
        'componentId': 4,
        'componentName': 'BODY',
        'totalPanels': 1,
        'totalParts': 2,
        'pendingCount': 1,
        'progressCount': 1,
        'orderCount': 1,
        'panels': [
          {
            'panelId': null,
            'panelName': 'CUSTOM FOG LAMP AREA',
            'totalParts': 2,
            'activityCount': 1,
            'progressPercent': 50,
            'parts': [
              {
                'masterPanelId': 10,
                'componentName': 'BODY',
                'panelName': 'CUSTOM FOG LAMP AREA',
                'namePart': 'Bracket Fog Lamp',
                'aliasName': null,
                'partNumber': null,
                'qty': 1,
                'initialCondition': 'RESTORE',
                'currentStatus': 'WAITING',
                'trackingStatus': 'PENDING',
                'photoCount': 0,
                'activitySummary': {
                  'countdownCount': 0,
                  'activeCountdownCount': 0,
                  'jobPlanCount': 0,
                  'prCount': 0,
                  'woCount': 0,
                  'wovCount': 0,
                },
              },
              {
                'masterPanelId': 11,
                'componentName': 'BODY',
                'panelName': 'CUSTOM FOG LAMP AREA',
                'namePart': 'Harness Fog Lamp',
                'aliasName': 'Harness kiri',
                'partNumber': 'A-11',
                'qty': 1,
                'initialCondition': 'RESTORE',
                'currentStatus': 'WAITING',
                'trackingStatus': 'PROGRESS_ORDER',
                'photoCount': 2,
                'activitySummary': {
                  'countdownCount': 1,
                  'activeCountdownCount': 1,
                  'jobPlanCount': 1,
                  'prCount': 1,
                  'woCount': 0,
                  'wovCount': 0,
                },
              },
            ],
          },
        ],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> getMasterPanelDetail({
    required String unitId,
    required int panelId,
  }) async => {
    'id': panelId,
    'name': 'Harness Fog Lamp',
    'component_name': 'BODY',
    'panel_name': 'CUSTOM FOG LAMP AREA',
    'part_number': 'A-11',
    'qty_normal': 1,
    'initial_condition': 'RESTORE',
    'current_status': 'WAITING',
    'media': [
      {'id': 1, 'file_url': 'https://cdn.example.com/master.jpg'},
    ],
  };

  @override
  Future<Map<String, dynamic>> getCountdownCreateOptions(String unitId) async =>
      {
        'divisions': [
          {'id': 3, 'name': 'INTERIOR'},
        ],
        'jobTypes': [
          {'id': 9, 'job_name': 'Restorasi Karpet', 'division_id': 3},
        ],
        'users': [
          {'id': 'SM-08.001', 'name': 'Budi', 'divisionId': 3},
        ],
      };

  @override
  Future<List<Map<String, dynamic>>> createMasterPanelCountdown({
    required String unitId,
    required int masterPanelId,
    required String idempotencyKey,
    required int divisionId,
    required String jobTypeId,
    required String description,
    required double targetHours,
    required String picPlan,
    String? startDate,
    String? deadlineDate,
    String taskCategory = 'MAIN',
  }) async {
    createCalls += 1;
    lastCreatePayload = {
      'unitId': unitId,
      'masterPanelId': masterPanelId,
      'idempotencyKey': idempotencyKey,
      'divisionId': divisionId,
      'jobTypeId': jobTypeId,
      'description': description,
      'targetHours': targetHours,
      'picPlan': picPlan,
      'startDate': startDate,
      'deadlineDate': deadlineDate,
      'taskCategory': taskCategory,
    };
    return [
      {
        'countdown_id': idempotencyKey,
        'panel_id': masterPanelId,
        'division_id': divisionId,
        'job_type_id': jobTypeId,
        'task_category': taskCategory,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getDetails(String countdownId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getDivisions(String carId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getRevisionRequests({
    String? carId,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getUnits() async => [];

  @override
  Future<void> markAsQcReady(String countdownId) async {}

  @override
  Future<void> moApproveRevision({
    required String requestId,
    required bool approved,
    String? note,
  }) async {}

  @override
  Future<void> processRevisionRequest({
    required String requestId,
    required bool approved,
    required double approvedHours,
    required String approvedDeadline,
  }) async {}

  @override
  Future<void> requestRevision({
    required String countdownId,
    required double requestedHours,
    required String requestedDeadline,
    required String reason,
  }) async {}

  @override
  Future<void> submitRevisionToApproval(String requestId) async {}
}

void main() {
  test(
    'tracking maps master panels without countdown and additional snapshot panel',
    () async {
      final repository = CountdownRepositoryImpl(
        dataSource: _FakeCountdownDataSource(),
      );

      final tracking = await repository.getMasterPanelTracking('220S');

      expect(tracking.summary.total, 2);
      expect(tracking.components.single.componentName, 'BODY');
      expect(tracking.components.single.panels.single.panelId, isNull);
      expect(
        tracking.components.single.panels.single.panelName,
        'CUSTOM FOG LAMP AREA',
      );
      expect(
        tracking.components.single.panels.single.parts.first.trackingStatus,
        'PENDING',
      );
      expect(
        tracking
            .components
            .single
            .panels
            .single
            .parts
            .last
            .activitySummary
            .prCount,
        1,
      );
      expect(
        tracking.components.single.panels.single.parts.last.trackingStatus,
        'PROGRESS_ORDER',
      );
    },
  );

  test('master panel detail reads media from master panel payload', () async {
    final repository = CountdownRepositoryImpl(
      dataSource: _FakeCountdownDataSource(),
    );

    final detail = await repository.getMasterPanelDetail(
      unitId: '220S',
      panelId: 11,
    );

    expect(detail.id, 11);
    expect(detail.images.single.fileUrl, 'https://cdn.example.com/master.jpg');
  });

  test('create countdown keeps selected master panel id fixed', () async {
    final fake = _FakeCountdownDataSource();
    final repository = CountdownRepositoryImpl(dataSource: fake);

    final created = await repository.createMasterPanelCountdown(
      unitId: '220S',
      masterPanelId: 11,
      idempotencyKey: '089c75f0-1111-4222-8333-123456789abc',
      divisionId: 3,
      jobTypeId: '9',
      description: 'Restorasi Karpet',
      targetHours: 8,
      picPlan: 'SM-08.001',
      deadlineDate: '2026-09-11',
    );

    expect(fake.createCalls, 1);
    expect(fake.lastCreatePayload?['masterPanelId'], 11);
    expect(
      fake.lastCreatePayload?['idempotencyKey'],
      '089c75f0-1111-4222-8333-123456789abc',
    );
    expect(fake.lastCreatePayload?['picPlan'], 'SM-08.001');
    expect(fake.lastCreatePayload?['taskCategory'], 'MAIN');
    expect(created.single['panel_id'], 11);
  });

  test('permission helper shows create only for permission code', () {
    expect(
      canCreateMasterPanelCountdown({'UNIT_CATALOG_CREATE_JOBDESC'}),
      true,
    );
    expect(canCreateMasterPanelCountdown({'CREATE_TASK'}), false);
  });

  test('countdown command id is uuid shaped', () {
    final first = newCountdownCommandId();
    final second = newCountdownCommandId();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(first, isNot(second));
  });
}
