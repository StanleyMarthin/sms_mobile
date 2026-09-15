/*
Tujuan: Mengunci UI dasar QC V2 queue dan detail tanpa action REWORK.
Caller: Flutter test runner.
Dependensi: QcV2QueuePage, QcRepository fake.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/qc/domain/entities/qc_item.dart';
import 'package:sm_system/features/qc/domain/repositories/qc_repository.dart';
import 'package:sm_system/features/qc/presentation/pages/qc_v2_page.dart';

void main() {
  testWidgets('QC V2 queue renders countdown and opens detail without rework', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QcV2QueuePage(repository: _Repo(), initialItems: const [_item]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MB 220S'), findsOneWidget);
    expect(find.textContaining('Countdown: Painting Door RH'), findsOneWidget);

    await tester.tap(find.text('MB 220S'));
    await tester.pumpAndSettle();

    expect(find.text('QC V2 Detail'), findsOneWidget);
    expect(find.text('PASS'), findsOneWidget);
    expect(find.text('NOT PASS'), findsOneWidget);
    expect(find.text('REWORK'), findsNothing);
  });
}

const _item = QcV2QueueItem(
  coreId: 'CORE-1',
  carId: 'CAR-1',
  unitName: 'MB 220S',
  panelId: 'PANEL-1',
  panelName: 'Door RH',
  countdownName: 'Painting Door RH',
  countdownStatus: 'READY_QC',
  remainingHours: 2,
  qcState: 'WAITING_QA',
  validatedPlanCount: 1,
  validatedPlanIds: ['PLAN-1'],
  version: 0,
);

class _Repo implements QcRepository {
  @override
  Future<QcV2PagedResponse> getV2Queue({
    String? divisionId,
    String? unitId,
    String? panelId,
    int page = 1,
    int pageSize = 20,
  }) async => const QcV2PagedResponse(
    items: [_item],
    hasMore: false,
    page: 1,
    total: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
