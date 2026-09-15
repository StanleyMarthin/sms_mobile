/*
Tujuan: Entity opsi dropdown Job Plan V2 dari kontrak dropdown existing.
Caller: JobPlanRepository dan form Job Plan V2.
Dependensi: Tidak ada.
Main Functions: JobPlanV2Options, JobPlanV2Option.
Side Effects: Tidak ada.
*/
library;

class JobPlanV2Options {
  const JobPlanV2Options({
    this.units = const [],
    this.panels = const [],
    this.countdowns = const [],
    this.employees = const [],
    this.divisions = const [],
  });

  factory JobPlanV2Options.fromDropdowns(Map<String, dynamic> json) {
    return JobPlanV2Options(
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

  final List<JobPlanV2Option> units;
  final List<JobPlanV2Option> panels;
  final List<JobPlanV2Option> countdowns;
  final List<JobPlanV2Option> employees;
  final List<JobPlanV2Option> divisions;

  static List<JobPlanV2Option> _items(
    Object? value,
    List<String> idKeys,
    List<String> labelKeys,
  ) {
    final rows = value is List ? value : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) {
          return JobPlanV2Option(
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

class JobPlanV2Option {
  const JobPlanV2Option({required this.id, required this.label});

  final String id;
  final String label;
}
