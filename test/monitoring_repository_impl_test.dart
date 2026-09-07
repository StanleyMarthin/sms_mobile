/*
Tujuan: Menjaga detail monitoring memakai hasil load terakhir agar tidak
        fetch ulang seluruh daftar mobil saat report dibuka.
Caller: flutter test.
Dependensi: flutter_test, dio, MonitoringRepositoryImpl.
Side Effects: Tidak ada.
*/
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/monitoring/data/datasources/monitoring_datasource.dart';
import 'package:sm_system/features/monitoring/data/repositories/monitoring_repository_impl.dart';

void main() {
  group('MonitoringRepositoryImpl', () {
    test('reuses last loaded cars when reading car divisions', () async {
      final dataSource = _FakeMonitoringDataSource([
        [
          {
            'carId': 'car-1',
            'unitName': 'Unit 1',
            'owner': 'Owner 1',
            'isMargin': true,
            'avgProgressPercentage': 70,
            'status': 'PROSES',
            'remainingWorkHours': 12.0,
            'divisions': [
              {
                'divisionName': 'Body Repair',
                'progressPercentage': 70,
                'weeklyWorkHours': 4.0,
                'remainingHours': 12.0,
              },
            ],
          },
        ],
      ]);
      final repository = MonitoringRepositoryImpl(dataSource: dataSource);

      await repository.getCars(canSeeAll: true, division: null);
      final divisions = await repository.getCarDivisions('car-1');

      expect(divisions, hasLength(1));
      expect(divisions.single.divisionName, 'Body Repair');
      expect(dataSource.calls, 1);
    });

    test('loads datasource on cache miss', () async {
      final dataSource = _FakeMonitoringDataSource([
        [
          {
            'carId': 'car-2',
            'unitName': 'Unit 2',
            'owner': 'Owner 2',
            'isMargin': false,
            'avgProgressPercentage': 55,
            'status': 'PLAN',
            'remainingWorkHours': 8.0,
            'divisions': [
              {
                'divisionName': 'Trim',
                'progressPercentage': 55,
                'weeklyWorkHours': 2.0,
                'remainingHours': 8.0,
              },
            ],
          },
        ],
      ]);
      final repository = MonitoringRepositoryImpl(dataSource: dataSource);

      final divisions = await repository.getCarDivisions('car-2');

      expect(divisions, hasLength(1));
      expect(divisions.single.divisionName, 'Trim');
      expect(dataSource.calls, 1);
    });
  });
}

class _FakeMonitoringDataSource implements MonitoringDataSource {
  _FakeMonitoringDataSource(this.responses);

  final List<List<Map<String, dynamic>>> responses;
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> getCars({CancelToken? cancelToken}) async {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls += 1;
    return responses[index];
  }
}
