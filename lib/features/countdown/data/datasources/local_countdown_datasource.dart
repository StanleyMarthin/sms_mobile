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
  Future<List<Map<String, dynamic>>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getDetails(String countdownId) async {
    final detailsByCar = await store.readGroupedList(
      key: LocalMockApiStore.countdownDetailsKey,
      seedBuilder: DummyCountdownData.seedDetails,
    );
    for (final details in detailsByCar.values) {
      final filtered =
          details.where((item) => item['countdownId'] == countdownId).toList();
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> getRevisionRequests(
          {String? carId}) async =>
      <Map<String, dynamic>>[];

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
