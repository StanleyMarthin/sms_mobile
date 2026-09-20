/*
Tujuan: Entity opsi dropdown Job Plan dari kontrak dropdown existing.
Caller: JobPlanRepository dan form Job Plan.
Dependensi: Tidak ada.
Main Functions: JobPlanOptions, JobPlanOption.
Side Effects: Tidak ada.
*/
library;

class JobPlanOptions {
  const JobPlanOptions({
    this.units = const [],
    this.panels = const [],
    this.countdowns = const [],
    this.employees = const [],
    this.divisions = const [],
  });

  factory JobPlanOptions.fromDropdowns(Map<String, dynamic> json) {
    return JobPlanOptions(
      units: _items(
        json['units'] ?? json['cars'],
        const ['id', 'unitId', 'carId'],
        const ['unitName', 'unit_name', 'carName', 'name'],
      ),
      panels: _items(
        json['panels'],
        const ['panelId', 'panel_id', 'id'],
        const ['panelName', 'panel_name', 'namaPanel', 'name'],
      ),
      countdowns: _items(
        json['countdowns'] ?? json['cores'],
        const ['coreId', 'core_id', 'countdownId', 'id'],
        const ['countdownName', 'countdown_name', 'jobdescription', 'name'],
      ),
      employees: _items(
        json['users'] ?? json['employees'],
        const ['employeeId', 'employee_id', 'id'],
        const ['employeeName', 'fullname', 'name'],
      ),
      divisions: _items(
        json['divisions'],
        const ['id', 'divisionId'],
        const ['divisionName', 'division_name', 'name'],
      ),
    );
  }

  final List<JobPlanOption> units;
  final List<JobPlanOption> panels;
  final List<JobPlanOption> countdowns;
  final List<JobPlanOption> employees;
  final List<JobPlanOption> divisions;

  static List<JobPlanOption> _items(
    Object? value,
    List<String> idKeys,
    List<String> labelKeys,
  ) {
    final rows = value is List ? value : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) {
          return JobPlanOption(
            id: _first(row, idKeys),
            label: _first(row, labelKeys),
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final text = row[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}

class JobPlanOption {
  const JobPlanOption({required this.id, required this.label});

  final String id;
  final String label;
}
