/*
Tujuan: Mengunci hydrasi draft additional agar edit form tetap terisi saat draft hanya menyimpan ID teknis.
Caller: flutter test.
Dependensi: flutter_test, JobPlanAdditionalDraftHelper.
Main Functions: test hydrate.
Side Effects: Tidak ada; hanya assertion unit test.
*/
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_additional_draft_helper.dart';

void main() {
  group('JobPlanAdditionalDraftHelper', () {
    test('hydrates picker mode draft using division and unit ids', () {
      final state = JobPlanAdditionalDraftHelper.hydrate(
        draft: const {
          'carId': 'car-1',
          'unitName': 'Ferrari Test',
          'panelName': 'Dashboard',
          'panelId': 77,
          'jobDescription': 'Pasang Dashboard',
          'divisionId': '12',
          'assignedUserId': 'emp-1',
        },
        units: const [
          {'id': 'car-1', 'unit_name': 'Ferrari Test'},
        ],
        divisions: const [
          {'id': '12', 'name': 'INTERIOR'},
        ],
      );

      expect(state.useManualInput, isFalse);
      expect(state.divisionLabel, 'INTERIOR');
      expect(state.selectedUnit?['id'], 'car-1');
      expect(state.selectedPanel, 'Dashboard');
      expect(state.selectedPanelId, 77);
      expect(state.selectedJobs, {'Pasang Dashboard'});
      expect(state.selectedEmployeeId, 'emp-1');
    });

    test('falls back to manual mode when unit master is unavailable', () {
      final state = JobPlanAdditionalDraftHelper.hydrate(
        draft: const {
          'carId': 'missing-car',
          'unitName': 'Jaguar Manual',
          'panelName': 'Custom Panel',
          'jobDescription': 'Custom Job',
          'divisionName': 'BODY',
          'sectionName': 'Custom Panel',
        },
        units: const [],
        divisions: const [],
      );

      expect(state.useManualInput, isTrue);
      expect(state.manualUnitName, 'Jaguar Manual');
      expect(state.manualPanelName, 'Custom Panel');
      expect(state.manualJobDescription, 'Custom Job');
      expect(state.divisionLabel, 'BODY');
    });

    test('keeps DB unit when manual draft is marked manual', () {
      final state = JobPlanAdditionalDraftHelper.hydrate(
        draft: const {
          'carId': 'car-1',
          'unitName': 'Ferrari Test',
          'panelName': 'Custom Panel',
          'jobDescription': 'Custom Job',
          'divisionId': '12',
          'assignedUserId': 'emp-1',
          'isManualInput': true,
        },
        units: const [
          {'id': 'car-1', 'unit_name': 'Ferrari Test'},
        ],
        divisions: const [
          {'id': '12', 'name': 'INTERIOR'},
        ],
      );

      expect(state.useManualInput, isTrue);
      expect(state.selectedUnit?['id'], 'car-1');
      expect(state.manualPanelName, 'Custom Panel');
      expect(state.manualJobDescription, 'Custom Job');
    });
  });
}
