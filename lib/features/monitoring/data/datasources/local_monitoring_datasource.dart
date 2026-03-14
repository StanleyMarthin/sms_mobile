library;

import '../../../../core/data/dummy_data.dart';

abstract class MonitoringDataSource {
  Future<List<Map<String, dynamic>>> getCars();
}

class LocalMonitoringDataSource implements MonitoringDataSource {
  @override
  Future<List<Map<String, dynamic>>> getCars() async => DummyMonitoringData.cars();
}