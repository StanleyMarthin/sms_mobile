library;

import '../../../../core/data/dummy_data.dart';
import '../../../../core/data/local_mock_api_store.dart';

abstract class CountdownDataSource {
  Future<List<Map<String, dynamic>>> getUnits();
  Future<List<Map<String, dynamic>>> getCountdowns(String carId);
  Future<List<Map<String, dynamic>>> getDetails(String countdownId);
}

class LocalCountdownDataSource implements CountdownDataSource {
  LocalCountdownDataSource({required this.store});

  final LocalMockApiStore store;

  @override
  Future<List<Map<String, dynamic>>> getUnits() async => store.readList(
        key: LocalMockApiStore.countdownUnitsKey,
        seedBuilder: DummyCountdownData.units,
      );

  @override
  Future<List<Map<String, dynamic>>> getCountdowns(String carId) async {
    final countdowns = await store.readGroupedList(
      key: LocalMockApiStore.countdownItemsKey,
      seedBuilder: DummyCountdownData.seedCountdowns,
    );
    return countdowns[carId] ?? <Map<String, dynamic>>[];
  }

  @override
  Future<List<Map<String, dynamic>>> getDetails(String countdownId) async {
    final detailsByCar = await store.readGroupedList(
      key: LocalMockApiStore.countdownDetailsKey,
      seedBuilder: DummyCountdownData.seedDetails,
    );
    for (final details in detailsByCar.values) {
      final filtered = details.where((item) => item['countdownId'] == countdownId).toList();
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }
    return <Map<String, dynamic>>[];
  }
}