library;

import '../entities/monitoring_entities.dart';

abstract class MonitoringRepository {
  Future<List<MonitoringCar>> getCars({
    required bool canSeeAll,
    required String? division,
  });

  Future<List<MonitoringDivisionProgress>> getCarDivisions(String carId);
}