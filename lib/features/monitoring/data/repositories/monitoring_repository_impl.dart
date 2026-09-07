/*
Tujuan: Repository monitoring mobile untuk mapping data source mobil dan progres divisi.
Caller: MonitoringPage dan DI MonitoringRepository.
Dependensi: MonitoringDataSource, MonitoringCar, MonitoringDivisionProgress.
Main Functions: getCars, getCarDivisions.
Side Effects: HTTP read via datasource dan cache in-memory daftar mobil terakhir.
*/
library;

import 'package:dio/dio.dart';

import '../../domain/entities/monitoring_entities.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../datasources/monitoring_datasource.dart';

class MonitoringRepositoryImpl implements MonitoringRepository {
  MonitoringRepositoryImpl({required this.dataSource});

  final MonitoringDataSource dataSource;
  List<Map<String, dynamic>> _cachedCars = const [];

  @override
  Future<List<MonitoringCar>> getCars({
    required bool canSeeAll,
    required String? division,
    CancelToken? cancelToken,
  }) async {
    final cars = await dataSource.getCars(cancelToken: cancelToken);
    final filtered = canSeeAll
        ? cars
        : cars.where((car) {
            final divisions = (car['divisions'] as List)
                .cast<Map<String, dynamic>>();
            return divisions.any((item) => item['divisionName'] == division);
          }).toList();
    _cachedCars = List<Map<String, dynamic>>.from(filtered);
    return filtered.map(_mapCar).toList();
  }

  @override
  Future<List<MonitoringDivisionProgress>> getCarDivisions(String carId) async {
    final cached = _cachedCars.where((item) => item['carId'] == carId).toList();
    final car = (cached.isNotEmpty ? cached : await dataSource.getCars())
        .firstWhere((item) => item['carId'] == carId);
    return (car['divisions'] as List)
        .cast<Map<String, dynamic>>()
        .map(_mapDivision)
        .toList();
  }

  MonitoringCar _mapCar(Map<String, dynamic> item) {
    final divisions = (item['divisions'] as List)
        .cast<Map<String, dynamic>>()
        .map(_mapDivision)
        .toList();
    return MonitoringCar(
      carId: item['carId'] as String,
      unitName: item['unitName'] as String,
      owner: item['owner'] as String,
      isMargin: item['isMargin'] as bool? ?? true,
      avgProgressPercentage: item['avgProgressPercentage'] as int,
      status: item['status'] as String,
      divisions: divisions,
      remainingWorkHours:
          (item['remainingWorkHours'] as num?)?.toDouble() ??
          divisions.fold<double>(0, (sum, d) => sum + d.remainingHours),
      deliveryDate: item['deliveryDate'] as String?,
      projectStartDate: item['projectStartDate'] as String?,
      lastUpdateDate: item['lastUpdateDate'] as String?,
      nextMilestone: item['nextMilestone'] as String?,
    );
  }

  MonitoringDivisionProgress _mapDivision(Map<String, dynamic> item) {
    return MonitoringDivisionProgress(
      divisionName: item['divisionName'] as String,
      progressPercentage: item['progressPercentage'] as int,
      weeklyWorkHours: (item['weeklyWorkHours'] as num?)?.toDouble() ?? 0,
      remainingHours: (item['remainingHours'] as num?)?.toDouble() ?? 0,
      blockedJobs: item['blockedJobs'] as int? ?? 0,
      overdueJobs: item['overdueJobs'] as int? ?? 0,
      forecastFinishDate: item['forecastFinishDate'] as String?,
      note: item['note'] as String?,
    );
  }
}
