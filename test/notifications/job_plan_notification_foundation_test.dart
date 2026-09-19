/*
Tujuan: Mengunci kategori read model notifikasi Job Plan V2 tanpa push engine.
Caller: Flutter test runner.
Dependensi: NotificationItem.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/notifications/domain/entities/notification_item.dart';

void main() {
  test('job plan notification events normalize to display categories', () {
    expect(
      NotificationItem.fromMap({
        'id': 'n-1',
        'title': 'Menunggu Approval',
        'body': 'Job Plan menunggu KP',
        'eventType': 'PLAN_WAITING_APPROVAL',
        'targetRoute': '/job-plan/plan-1',
      }).category,
      'approval',
    );
    expect(
      NotificationItem.fromMap({
        'id': 'n-2',
        'title': 'Jadwal berubah',
        'body': 'Schedule changed',
        'eventType': 'SCHEDULE_CHANGED',
        'targetRoute': '/job-plan/plan-1',
      }).category,
      'job_plan',
    );
    expect(
      NotificationItem.fromMap({
        'id': 'n-3',
        'title': 'Task ready',
        'body': 'Task siap',
        'eventType': 'TASK_READY',
        'targetRoute': '/tasks',
      }).category,
      'execution',
    );
    expect(
      NotificationItem.fromMap({
        'id': 'n-4',
        'title': 'Validation requested',
        'body': 'Menunggu KD',
        'eventType': 'VALIDATION_REQUESTED',
        'targetRoute': '/job-plans/v2/monitoring',
      }).category,
      'validation',
    );
    expect(
      NotificationItem.fromMap({
        'id': 'n-5',
        'title': 'Tambahan Waktu QC',
        'body': 'Menunggu KP',
        'eventType': 'ADJUSTMENT_REQUESTED',
        'targetRoute': '/countdown',
      }).category,
      'approval',
    );
  });
}
