/*
Tujuan: Helper hydrasi draft additional agar form edit bisa memulihkan state dari kombinasi id teknis dan label presentasional.
Caller: JobPlanPage additional form dan unit test job plan.
Dependensi: Tidak ada; hanya data draft serta master units/divisions yang sudah dimuat.
Main Functions: hydrate.
Side Effects: Tidak ada; seluruh fungsi hanya transformasi data in-memory.
*/
class JobPlanAdditionalDraftHydratedState {
  JobPlanAdditionalDraftHydratedState({
    required this.useManualInput,
    required this.manualUnitName,
    required this.manualPanelName,
    required this.manualJobDescription,
    required this.selectedUnit,
    required this.selectedPanel,
    required this.useFreeTextPanel,
    required this.freeTextPanelName,
    required this.divisionLabel,
    required this.selectedEmployeeId,
    required this.selectedJobs,
    required this.selectedCategory,
  });

  final bool useManualInput;
  final String manualUnitName;
  final String manualPanelName;
  final String manualJobDescription;
  final Map<String, dynamic>? selectedUnit;
  final String? selectedPanel;
  final bool useFreeTextPanel;
  final String freeTextPanelName;
  final String divisionLabel;
  final String? selectedEmployeeId;
  final Set<String> selectedJobs;
  final String? selectedCategory;
}

class JobPlanAdditionalDraftHelper {
  JobPlanAdditionalDraftHelper._();

  static String _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  static JobPlanAdditionalDraftHydratedState hydrate({
    required Map<String, dynamic> draft,
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> divisions,
  }) {
    final carId = _text(draft['carId']);
    final unitName = _text(draft['unitName']);
    final panelName = _text(draft['panelName']);
    final panelCustomNote = _text(
      draft['panelCustomNote'] ?? draft['panel_custom_note'],
    );
    final sectionName = _text(draft['sectionName']);
    final jobDescription = _text(
      draft['jobDescription'] ?? draft['jobdescription'],
    );
    final divisionId = _text(draft['divisionId']);
    final explicitDivisionName = _text(
      draft['divisionName'] ?? draft['assignedDivision'],
    );
    final forcedManual = draft['isManualInput'] == true ||
        draft['isManualInput'] == 1 ||
        draft['is_manual_input'] == true;

    Map<String, dynamic>? selectedUnit;
    if (carId.isNotEmpty) {
      for (final unit in units) {
        final unitId = _text(unit['id']);
        if (unitId == carId) {
          selectedUnit = unit;
          break;
        }
      }
    }
    if (selectedUnit == null && unitName.isNotEmpty) {
      for (final unit in units) {
        final unitLabel = _text(
          unit['unit_name'] ?? unit['unitName'] ?? unit['name'],
        );
        if (unitLabel.isNotEmpty && unitLabel.toLowerCase() == unitName.toLowerCase()) {
          selectedUnit = unit;
          break;
        }
      }
    }

    var divisionLabel = explicitDivisionName;
    if (divisionLabel.isEmpty && divisionId.isNotEmpty) {
      for (final division in divisions) {
        final itemId = _text(division['id']);
        if (itemId == divisionId) {
          divisionLabel = _text(division['name'] ?? division['divisionName']);
          break;
        }
      }
    }
    if (divisionLabel.isEmpty) {
      divisionLabel = divisionId;
    }

    final resolvedPanelName = panelName.isNotEmpty
        ? panelName
        : panelCustomNote;
    final shouldUseManualInput =
        forcedManual || carId.isEmpty || selectedUnit == null;
    final useFreeTextPanel = sectionName.isNotEmpty;

    return JobPlanAdditionalDraftHydratedState(
      useManualInput: shouldUseManualInput,
      manualUnitName: shouldUseManualInput ? unitName : '',
      manualPanelName: shouldUseManualInput ? resolvedPanelName : '',
      manualJobDescription: shouldUseManualInput ? jobDescription : '',
      selectedUnit: selectedUnit,
      selectedPanel:
          shouldUseManualInput || useFreeTextPanel || resolvedPanelName.isEmpty
          ? null
          : resolvedPanelName,
      useFreeTextPanel: !shouldUseManualInput && useFreeTextPanel,
      freeTextPanelName: useFreeTextPanel ? sectionName : '',
      divisionLabel: divisionLabel,
      selectedEmployeeId: _text(draft['assignedUserId']).isEmpty
          ? null
          : _text(draft['assignedUserId']),
      selectedJobs: shouldUseManualInput || jobDescription.isEmpty
          ? <String>{}
          : {jobDescription},
      selectedCategory: _text(draft['panelCategory']).isEmpty
          ? null
          : _text(draft['panelCategory']),
    );
  }
}
