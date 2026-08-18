import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_page.dart';

void main() {
  group('normalizeSequentialDraftItems', () {
    test('shifts overlapping jobs for the same operator to be sequential', () {
      final result = normalizeSequentialDraftItems([
        {
          'draftItemId': 'a',
          'assignedUserId': 'PIC-A',
          'taskDate': '2026-08-13',
          'startTime': '08:00',
          'finishTime': '10:00',
          'targetHours': 2,
        },
        {
          'draftItemId': 'b',
          'assignedUserId': 'PIC-A',
          'taskDate': '2026-08-13',
          'startTime': '08:00',
          'finishTime': '10:00',
          'targetHours': 2,
        },
      ]);

      expect(result[0]['startTime'], '08:00');
      expect(result[0]['finishTime'], '10:00');
      expect(result[1]['startTime'], '10:00');
      expect(result[1]['finishTime'], '12:00');
    });

    test('does not touch a different operator', () {
      final result = normalizeSequentialDraftItems([
        {
          'draftItemId': 'a',
          'assignedUserId': 'PIC-A',
          'taskDate': '2026-08-13',
          'startTime': '08:00',
          'finishTime': '10:00',
          'targetHours': 2,
        },
        {
          'draftItemId': 'b',
          'assignedUserId': 'PIC-B',
          'taskDate': '2026-08-13',
          'startTime': '08:00',
          'finishTime': '10:00',
          'targetHours': 2,
        },
      ]);

      expect(result[1]['startTime'], '08:00');
      expect(result[1]['finishTime'], '10:00');
    });
  });
}
