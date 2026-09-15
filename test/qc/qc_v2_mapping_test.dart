/*
Tujuan: Mengunci mapping read model QC V2 dari response backend.
Caller: Flutter test runner.
Dependensi: QcRepositoryImpl, QcDataSource, QcV2QueueItem.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/qc/data/datasources/qc_datasource.dart';
import 'package:sm_system/features/qc/data/repositories/qc_repository_impl.dart';

void main() {
  test('maps QC V2 queue from backend ids and display snapshots', () async {
    final repo = QcRepositoryImpl(dataSource: _QcV2DataSource());

    final result = await repo.getV2Queue(unitId: 'CAR-1', page: 2);
    final item = result.items.single;

    expect(result.page, 2);
    expect(result.total, 1);
    expect(item.coreId, 'CORE-1');
    expect(item.carId, 'CAR-1');
    expect(item.unitName, 'MB 220S');
    expect(item.panelId, 'PANEL-1');
    expect(item.panelName, 'Door RH');
    expect(item.countdownName, 'Painting Door RH');
    expect(item.qcState, 'WAITING_QA');
    expect(item.validatedPlanIds, ['PLAN-1', 'PLAN-2']);
    expect(item.version, 3);
  });
}

class _QcV2DataSource implements QcDataSource {
  @override
  Future<Map<String, dynamic>> getV2Queue({
    String? divisionId,
    String? unitId,
    String? panelId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return {
      'page': page,
      'pageSize': pageSize,
      'total': 1,
      'hasMore': false,
      'items': [
        {
          'coreId': 'CORE-1',
          'carId': unitId,
          'unitName': 'MB 220S',
          'panelId': 'PANEL-1',
          'panelName': 'Door RH',
          'countdownName': 'Painting Door RH',
          'countdownStatus': 'READY_QC',
          'remainingHours': 2.5,
          'qcState': 'WAITING_QA',
          'latestQcResult': null,
          'latestQcLevel': null,
          'validatedPlanCount': 2,
          'validatedPlanIds': ['PLAN-1', 'PLAN-2'],
          'version': 3,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> submitV2Qc({
    required String coreId,
    required String commandId,
    required int expectedVersion,
    required String action,
    String? notes,
    List<String>? photos,
    int? inspectionDurationMinutes,
  }) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
