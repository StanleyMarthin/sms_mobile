/*
Tujuan: Helper pemuatan dan normalisasi master jobdesc agar dropdown additional konsisten dengan kontrak backend per divisi.
Caller: JobPlanPage additional form dan unit test job plan.
Dependensi: Tidak ada; hanya callback loader dropdown.
Main Functions: normalizeJobTypeNames, normalizeJobTypeChoices, loadAdditionalJobTypeNames.
Side Effects: Tidak ada; seluruh fungsi hanya transformasi data in-memory.
*/
class JobPlanJobTypeChoice {
  const JobPlanJobTypeChoice({required this.id, required this.name});

  final String id;
  final String name;
}

class JobPlanJobTypeHelper {
  JobPlanJobTypeHelper._();

  static String _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  static String? _pickJobTypeName(Map<String, dynamic> item) {
    final raw = _text(
      item['name'] ?? item['job_name'] ?? item['jobName'] ?? item['label'],
    );
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    return raw;
  }

  static String _pickJobTypeId(Map<String, dynamic> item) {
    return _text(item['id'] ?? item['jobTypeId'] ?? item['job_type_id']);
  }

  static List<String> normalizeJobTypeNames(Iterable<dynamic> items) {
    return normalizeJobTypeChoices(items).map((item) => item.name).toList();
  }

  static List<JobPlanJobTypeChoice> normalizeJobTypeChoices(
    Iterable<dynamic> items,
  ) {
    final seen = <String>{};
    final choices = <JobPlanJobTypeChoice>[];

    for (final item in items.whereType<Map<String, dynamic>>()) {
      final name = _pickJobTypeName(item);
      if (name == null) continue;

      final dedupeKey = name.toUpperCase();
      if (seen.add(dedupeKey)) {
        choices.add(JobPlanJobTypeChoice(id: _pickJobTypeId(item), name: name));
      }
    }

    return choices;
  }

  static Future<List<String>> loadAdditionalJobTypeNames({
    required String divisionId,
    required Future<Map<String, dynamic>> Function({String? divisionId})
    loadDropdowns,
  }) async {
    final normalizedDivisionId = divisionId.trim();
    final dropdowns = await loadDropdowns(
      divisionId: normalizedDivisionId.isEmpty ? null : normalizedDivisionId,
    );
    return normalizeJobTypeNames(dropdowns['jobTypes'] as List? ?? []);
  }

  static Future<List<JobPlanJobTypeChoice>> loadAdditionalJobTypeChoices({
    required String divisionId,
    required Future<Map<String, dynamic>> Function({String? divisionId})
    loadDropdowns,
  }) async {
    final normalizedDivisionId = divisionId.trim();
    final dropdowns = await loadDropdowns(
      divisionId: normalizedDivisionId.isEmpty ? null : normalizedDivisionId,
    );
    return normalizeJobTypeChoices(dropdowns['jobTypes'] as List? ?? []);
  }

  static JobPlanJobTypeChoice? findChoiceByName(
    Iterable<JobPlanJobTypeChoice> choices,
    String name,
  ) {
    final needle = name.trim().toUpperCase();
    if (needle.isEmpty) return null;
    for (final choice in choices) {
      if (choice.name.trim().toUpperCase() == needle) return choice;
    }
    return null;
  }
}
