/*
Tujuan: Mengunci display read-only QC Adjustment pada Countdown Revision.
Caller: Flutter test runner.
Dependensi: CountdownJobdesc, CountdownHelper.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/countdown/domain/entities/countdown_entities.dart';
import 'package:sm_system/features/countdown/presentation/utils/countdown_helper.dart';

CountdownJobdesc _revision({
  required String status,
  String reason = 'QC_ADJUSTMENT',
  String? sourceType = 'QC',
  String? referenceId = 'QC-1',
}) {
  return CountdownJobdesc(
    id: 'cd-1',
    carId: '220S',
    divisionId: '1',
    panelName: 'Door RH',
    sectionName: '-',
    jobdesc: 'Painting Door RH',
    taskCategory: 'MAIN',
    progress: 0,
    status: 'PROSES',
    targetHoursInitial: 8,
    timeExtensionHours: 0,
    targetHoursRevised: 8,
    totalActualHours: 8,
    remainingHours: 0,
    startDate: '2026-09-15',
    deadlineDate: '2026-09-20',
    qcLastStatus: 'TIDAK_LOLOS',
    qcValidationStatus: null,
    qcResultStatus: null,
    qcEstimatedReworkHours: null,
    qcReworkDeadlineDate: null,
    qcAdvisorNotes: null,
    revisionRequestStatus: status,
    requestedRevisionHours: 8,
    requestedRevisionDeadline: '2026-09-22',
    requestedRevisionReason: reason,
    revisionSourceType: sourceType,
    revisionReferenceId: referenceId,
  );
}

void main() {
  test('MO_REVIEW stays active display state', () {
    final banner = CountdownHelper.revisionStatusBanner(
      _revision(status: 'MO_REVIEW'),
    );

    expect(banner?.title, 'Menunggu MO/PM');
    expect(banner?.detail, contains('+8.0 jam'));
  });

  test('QC adjustment reference is carried by revision entity', () {
    final item = _revision(status: 'REQUESTED');

    expect(item.requestedRevisionReason, 'QC_ADJUSTMENT');
    expect(item.revisionSourceType, 'QC');
    expect(item.revisionReferenceId, 'QC-1');
  });
}
