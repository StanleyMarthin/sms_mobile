import 'package:dio/dio.dart';

abstract class MonitoringDataSource {
  Future<List<Map<String, dynamic>>> getCars({CancelToken? cancelToken});
}
