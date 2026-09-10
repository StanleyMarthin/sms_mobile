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

class _FakeCountdownDataSource implements CountdownDataSource {
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
}
