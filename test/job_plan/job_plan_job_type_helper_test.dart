/*
Tujuan: Mengunci helper job type additional agar dropdown jobdesc memakai source terfilter divisi dan membaca label backend dengan benar.
Caller: flutter test.
Dependensi: flutter_test, JobPlanJobTypeHelper.
Main Functions: test loadAdditionalJobTypeNames, test normalizeJobTypeNames.
Side Effects: Tidak ada; hanya assertion unit test.
*/
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_job_type_helper.dart';

void main() {
  group('JobPlanJobTypeHelper', () {
    test('normalizes job type labels from backend aliases and removes blanks', () {
      final names = JobPlanJobTypeHelper.normalizeJobTypeNames([
        {'id': 1, 'job_name': 'Pasang Dashboard'},
        {'id': 2, 'name': 'Jahit Jok'},
        {'id': 3, 'jobName': 'Poles Panel'},
        {'id': 4, 'job_name': ''},
        {'id': 5, 'name': 'Pasang Dashboard'},
      ]);

      expect(names, ['Pasang Dashboard', 'Jahit Jok', 'Poles Panel']);
    });

    test('loads additional job types with the selected division filter', () async {
      String? capturedDivisionId;

      final names = await JobPlanJobTypeHelper.loadAdditionalJobTypeNames(
        divisionId: 'INTERIOR',
        loadDropdowns: ({String? divisionId}) async {
          capturedDivisionId = divisionId;
          return {
            'jobTypes': [
              {'id': 1, 'job_name': 'Pasang Dashboard'},
              {'id': 2, 'job_name': 'Jahit Jok'},
            ],
          };
        },
      );

      expect(capturedDivisionId, 'INTERIOR');
      expect(names, ['Pasang Dashboard', 'Jahit Jok']);
    });
  });
}
