/*
Tujuan: Datasource mock Countdown untuk mode lokal/offline ringan.
Caller: CountdownRepositoryImpl saat memakai LocalMockApiStore.
Dependensi: DummyCountdownData, LocalMockApiStore.
Main Functions: LocalCountdownDataSource.
Side Effects: Read/write mock store lokal.
*/

library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';
import 'countdown_datasource.dart';

class LocalCountdownDataSource implements CountdownDataSource {
  LocalCountdownDataSource({required this.store});

  final LocalMockApiStore store;

  @override
  Future<List<Map<String, dynamic>>> getUnits() async => store.readList(
    key: LocalMockApiStore.countdownUnitsKey,
    seedBuilder: DummyCountdownData.units,
  );

  @override
  Future<List<Map<String, dynamic>>> getDivisions(String carId) async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> getMasterPanelTracking(String unitId) async => {
    'summary': {'total': 0, 'pending': 0, 'progress': 0, 'order': 0, 'done': 0},
    'components': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> getMasterPanelDetail({
    required String unitId,
    required int panelId,
  }) async => <String, dynamic>{
    'id': panelId,
    'name': 'Master Panel',
    'component_name': '-',
    'panel_name': '-',
    'media': <Map<String, dynamic>>[],
    'jobdescs': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> getCountdownCreateOptions(String unitId) async =>
      <String, dynamic>{
        'divisions': <Map<String, dynamic>>[],
        'jobTypes': <Map<String, dynamic>>[],
        'users': <Map<String, dynamic>>[],
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
  }) async => <Map<String, dynamic>>[
    {
      'countdown_id': idempotencyKey,
      'panel_id': masterPanelId,
      'division_id': divisionId,
      'job_type_id': jobTypeId,
      'task_category': taskCategory,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getDetails(String countdownId) async {
    final detailsByCar = await store.readGroupedList(
      key: LocalMockApiStore.countdownDetailsKey,
      seedBuilder: DummyCountdownData.seedDetails,
    );
    for (final details in detailsByCar.values) {
      final filtered = details
          .where((item) => item['countdownId'] == countdownId)
          .toList();
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> getRevisionRequests({
    String? carId,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<void> requestRevision({
    required String countdownId,
    required double requestedHours,
    required String requestedDeadline,
    required String reason,
  }) async {}

  @override
  Future<void> processRevisionRequest({
    required String requestId,
    required bool approved,
    required double approvedHours,
    required String approvedDeadline,
  }) async {}

  @override
  Future<void> markAsQcReady(String countdownId) async {}

  @override
  Future<void> moApproveRevision({
    required String requestId,
    required bool approved,
    String? note,
  }) async {}

  @override
  Future<void> submitRevisionToApproval(String requestId) async {}
}
