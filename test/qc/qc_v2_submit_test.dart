/*
Tujuan: Mengunci payload command submit QC V2 dari repository mobile.
Caller: Flutter test runner.
Dependensi: QcRepositoryImpl, QcDataSource.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/qc/data/datasources/qc_datasource.dart';
import 'package:sm_system/features/qc/data/repositories/qc_repository_impl.dart';

void main() {
  test('submits PASS command with command id and expected version', () async {
    final dataSource = _CaptureQcV2DataSource();
    final repo = QcRepositoryImpl(dataSource: dataSource);

    final result = await repo.submitV2Qc(
      coreId: 'CORE-1',
      commandId: 'cmd-qc-1',
      expectedVersion: 4,
      action: 'PASS',
      notes: 'ok',
      photos: const ['https://cdn/qc-a.jpg'],
      inspectionDurationMinutes: 15,
    );

    expect(result.result, 'PASS');
    expect(dataSource.lastPayload['coreId'], 'CORE-1');
    expect(dataSource.lastPayload['commandId'], 'cmd-qc-1');
    expect(dataSource.lastPayload['expectedVersion'], 4);
    expect(dataSource.lastPayload['action'], 'PASS');
    expect(dataSource.lastPayload['photos'], ['https://cdn/qc-a.jpg']);
  });
}

class _CaptureQcV2DataSource implements QcDataSource {
  Map<String, dynamic> lastPayload = {};

  @override
  Future<Map<String, dynamic>> submitV2Qc({
    required String coreId,
    required String commandId,
    required int expectedVersion,
    required String action,
    String? notes,
    List<String>? photos,
    int? inspectionDurationMinutes,
  }) async {
    lastPayload = {
      'coreId': coreId,
      'commandId': commandId,
      'expectedVersion': expectedVersion,
      'action': action,
      'notes': notes,
      'photos': photos,
      'inspectionDurationMinutes': inspectionDurationMinutes,
    };
    return {
      'qcId': 'QC-1',
      'result': action,
      'version': expectedVersion + 1,
      'reused': false,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
