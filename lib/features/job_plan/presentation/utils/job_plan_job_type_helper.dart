/*
Tujuan: Helper pemuatan dan normalisasi master jobdesc agar dropdown additional konsisten dengan kontrak backend per divisi.
Caller: JobPlanPage additional form dan unit test job plan.
Dependensi: Tidak ada; hanya callback loader dropdown.
Main Functions: normalizeJobTypeNames, loadAdditionalJobTypeNames.
Side Effects: Tidak ada; seluruh fungsi hanya transformasi data in-memory.
*/
class JobPlanJobTypeHelper {
  const JobPlanJobTypeHelper._();

  static String? _pickJobTypeName(Map<String, dynamic> item) {
    final raw =
        (item['name'] ??
                item['job_name'] ??
                item['jobName'] ??
                item['label'] ??
                '')
            .toString()
            .trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    return raw;
  }

  static List<String> normalizeJobTypeNames(Iterable<dynamic> items) {
    final names = <String>[];
    final seen = <String>{};

    for (final item in items.whereType<Map<String, dynamic>>()) {
      final name = _pickJobTypeName(item);
      if (name == null) continue;

      final dedupeKey = name.toUpperCase();
      if (seen.add(dedupeKey)) {
        names.add(name);
      }
    }

    return names;
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
    return normalizeJobTypeNames(dropdowns['jobTypes'] as List? ?? const []);
  }
}
