library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import 'local_monitoring_datasource.dart';

class RemoteMonitoringDataSource implements MonitoringDataSource {
  const RemoteMonitoringDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _userId => sessionManager.userId ?? sessionManager.employeeId ?? '';

  @override
  Future<List<Map<String, dynamic>>> getCars() async {
    final unitsResponse = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId},
    );

    final units = unitsResponse.data as List<dynamic>? ?? [];
    final results = <Map<String, dynamic>>[];

    for (final unit in units.whereType<Map<String, dynamic>>()) {
      final carId = '${unit['car_id'] ?? ''}';
      if (carId.isEmpty) {
        continue;
      }

      final divisions = await _loadDivisions(carId);
      final remaining = divisions.fold<double>(
        0,
        (sum, item) => sum + ((item['remainingHours'] as num?)?.toDouble() ?? 0),
      );

      final unitNameRaw = '${unit['unit_name'] ?? '-'}';
      final owner = _extractOwner(unitNameRaw);
      final unitName = _extractUnitName(unitNameRaw);

      results.add({
        'carId': carId,
        'unitName': unitName,
        'owner': owner,
        'isMargin': true,
        'avgProgressPercentage': ((unit['overall_progress'] as num?) ?? 0).round(),
        'status': '${unit['status'] ?? 'PROSES'}',
        'divisions': divisions,
        'remainingWorkHours': remaining,
        'deliveryDate': _toDate(unit['contract_delivery_date']),
        'projectStartDate': null,
        'lastUpdateDate': DateTime.now().toIso8601String(),
        'nextMilestone': null,
      });
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> _loadDivisions(String carId) async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {
        'user_id': _userId,
        'car_id': carId,
      },
    );

    final rows = response.data as List<dynamic>? ?? [];
    final mapped = <Map<String, dynamic>>[];

    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final divisionId = row['division_id'];
      final divisionName = '${row['division_name'] ?? '-'}';
      final progress = ((row['division_progress'] as num?) ?? 0).round();

      var remaining = 0.0;
      var target = 0.0;
      if (divisionId != null) {
        final sectionResponse = await apiClient.get(
          ApiEndpoints.countdown,
          queryParameters: {
            'user_id': _userId,
            'car_id': carId,
            'division_id': divisionId,
          },
        );
        final sections = sectionResponse.data as List<dynamic>? ?? [];
        for (final section in sections.whereType<Map<String, dynamic>>()) {
          remaining += ((section['total_remaining_hours'] as num?) ?? 0).toDouble();
          target += ((section['total_target_hours'] as num?) ?? 0).toDouble();
        }
      }

      mapped.add({
        'divisionName': divisionName,
        'progressPercentage': progress,
        'weeklyWorkHours': (target - remaining).clamp(0, double.infinity),
        'remainingHours': remaining,
        'blockedJobs': 0,
        'overdueJobs': 0,
        'forecastFinishDate': null,
        'note': null,
      });
    }

    return mapped;
  }

  String _extractOwner(String raw) {
    final start = raw.indexOf('(');
    final end = raw.lastIndexOf(')');
    if (start >= 0 && end > start) {
      return raw.substring(start + 1, end).trim();
    }
    return '-';
  }

  String _extractUnitName(String raw) {
    final start = raw.indexOf('(');
    if (start > 0) {
      return raw.substring(0, start).trim();
    }
    return raw;
  }

  String? _toDate(Object? value) {
    if (value == null) return null;
    final raw = '$value';
    if (raw.contains('T')) return raw.split('T').first;
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }
}
