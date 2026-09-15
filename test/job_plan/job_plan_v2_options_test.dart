/*
Tujuan: Mengunci normalisasi dropdown/options Job Plan V2 dari kontrak dropdown existing.
Caller: Flutter test runner.
Dependensi: JobPlanV2Options.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan_v2_options.dart';

void main() {
  test(
    'options normalize units employees and divisions from backend aliases',
    () {
      final options = JobPlanV2Options.fromDropdowns({
        'units': [
          {'id': 'UNIT-1', 'unit_name': 'MB220S'},
        ],
        'users': [
          {'employee_id': 'EMP-1', 'fullname': 'Budi'},
        ],
        'divisions': [
          {'id': 8, 'name': 'Interior'},
        ],
      });

      expect(options.units.single.id, 'UNIT-1');
      expect(options.units.single.label, 'MB220S');
      expect(options.employees.single.id, 'EMP-1');
      expect(options.employees.single.label, 'Budi');
      expect(options.divisions.single.id, '8');
      expect(options.divisions.single.label, 'Interior');
    },
  );
}
