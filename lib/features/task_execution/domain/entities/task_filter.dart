// Task filter parameters for the unified view tasks endpoint.
//
// Maps to: GET /api/v1/tasks query parameters.
// Used by all roles (OP, KD, ADV, PM) — backend filters
// data based on JWT token role regardless of filter params.
library;

import 'package:equatable/equatable.dart';

/// Available task types matching `plan_daily.type`.
enum TaskType {
  daily,
  overtime,
  plan;

  String get value => name;

  static TaskType fromString(String value) {
    return TaskType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskType.daily,
    );
  }

  String get label {
    switch (this) {
      case TaskType.daily:
        return 'Harian';
      case TaskType.overtime:
        return 'Lembur';
      case TaskType.plan:
        return 'Review';
    }
  }
}

/// Filter parameters sent to GET /api/v1/tasks.
///
/// Role-based filtering rules (applied by backend):
/// - **OP**: Only sees own tasks (ignores divisionId/unitId)
/// - **KD**: Sees division tasks (ignores divisionId — uses token)
/// - **ADV**: Sees supervised divisions; can filter by divisionId/unitId
/// - **PM**: Sees all; can filter by divisionId/unitId
class TaskFilter extends Equatable {
  /// Type of task: daily, overtime, or plan.
  final TaskType type;

  /// Target date for tasks (defaults to today).
  final DateTime date;

  /// Optional division filter (ADV/PM only — ignored for OP/KD).
  final String? divisionId;

  /// Optional unit filter (ADV/PM only).
  final String? unitId;

  /// Pagination: current page (1-based).
  final int page;

  /// Pagination: items per page.
  final int limit;

  const TaskFilter({
    this.type = TaskType.daily,
    required this.date,
    this.divisionId,
    this.unitId,
    this.page = 1,
    this.limit = 20,
  });

  /// Create a copy with updated fields.
  TaskFilter copyWith({
    TaskType? type,
    DateTime? date,
    String? divisionId,
    String? unitId,
    int? page,
    int? limit,
    bool clearDivisionId = false,
    bool clearUnitId = false,
  }) {
    return TaskFilter(
      type: type ?? this.type,
      date: date ?? this.date,
      divisionId: clearDivisionId ? null : (divisionId ?? this.divisionId),
      unitId: clearUnitId ? null : (unitId ?? this.unitId),
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  /// Convert to query parameters map for API request.
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'type': type.value,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'page': page,
      'limit': limit,
    };
    if (divisionId != null) params['divisionId'] = divisionId;
    if (unitId != null) params['unitId'] = unitId;
    return params;
  }

  @override
  List<Object?> get props => [type, date, divisionId, unitId, page, limit];
}
