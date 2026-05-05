library;

import 'package:dio/dio.dart';

import '../entities/monitoring_entities.dart';

abstract class MonitoringRepository {
  Future<List<MonitoringCar>> getCars({
    required bool canSeeAll,
    required String? division,
    CancelToken? cancelToken,
  });

  Future<List<MonitoringDivisionProgress>> getCarDivisions(String carId);
}
