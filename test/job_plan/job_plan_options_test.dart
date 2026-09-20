/*
Tujuan: Mengunci normalisasi dropdown/options Job Plan dari kontrak dropdown existing.
Caller: Flutter test runner.
Dependensi: JobPlanOptions.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan_options.dart';

void main() {
  test(
    'options normalize units employees and divisions from backend aliases',
    () {
      final options = JobPlanOptions.fromDropdowns({
        'cars': [
          {'id': 'UNIT-1', 'unit_name': 'MB220S'},
        ],
        'panels': [
          {'panel_id': 'PANEL-1', 'panelName': 'Door RH'},
        ],
        'countdowns': [
          {
            'core_id': 'CORE-1',
            'countdownName': 'Painting Door RH',
            'panel_id': 'PANEL-1',
          },
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
      expect(options.panels.single.id, 'PANEL-1');
      expect(options.panels.single.label, 'Door RH');
      expect(options.countdowns.single.id, 'CORE-1');
      expect(options.countdowns.single.label, 'Painting Door RH');
      expect(options.employees.single.id, 'EMP-1');
      expect(options.employees.single.label, 'Budi');
      expect(options.divisions.single.id, '8');
      expect(options.divisions.single.label, 'Interior');
    },
  );
}
