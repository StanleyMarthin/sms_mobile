library;

import 'package:dio/dio.dart';

import '../../../../core/data/dummy_data.dart';

abstract class MonitoringDataSource {
  Future<List<Map<String, dynamic>>> getCars({CancelToken? cancelToken});
}

class LocalMonitoringDataSource implements MonitoringDataSource {
  @override
  Future<List<Map<String, dynamic>>> getCars({
    CancelToken? cancelToken,
  }) async {
    return DummyMonitoringData.cars();
  }
}
