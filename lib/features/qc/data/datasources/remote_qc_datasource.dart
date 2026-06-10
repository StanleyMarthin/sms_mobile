library;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import 'qc_datasource.dart';

class RemoteQcDataSource implements QcDataSource {
  const RemoteQcDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  @override
  Future<List<Map<String, dynamic>>> getQcDivisions() async {
    final sessionDivisionId = sessionManager.divisionId;
    final sessionDivisionName = sessionManager.divisionName;
    final canSeeAllDivisions =
        sessionManager.canViewAssignedUnits || sessionManager.canViewAllUnits;

    if (!canSeeAllDivisions &&
        sessionDivisionId != null &&
        sessionDivisionName != null &&
        sessionDivisionName.isNotEmpty) {
      return [
        {
          'divisionId': sessionDivisionId.toString(),
          'divisionName': sessionDivisionName,
          'totalItem': 0,
        },
      ];
    }

    final units = await _getCountdownUnits();
    final divisionsById = <String, Map<String, dynamic>>{};

    for (final unit in units) {
      final carId = unit['car_id']?.toString() ?? '';
      if (carId.isEmpty) continue;

      final divisions = await _getCountdownDivisions(carId);
      for (final division in divisions) {
        final divisionId = division['division_id']?.toString() ?? '';
        if (divisionId.isEmpty) continue;

        divisionsById.putIfAbsent(divisionId, () {
          return {
            'divisionId': divisionId,
            'divisionName': division['division_name']?.toString() ?? '-',
            'totalItem': 0,
          };
        });
      }
    }

    return divisionsById.values.toList()..sort(
      (a, b) => '${a['divisionName']}'.compareTo('${b['divisionName']}'),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getQcItems({
    required String division,
    required bool canValidate,
  }) async {
    // Dipanggil mock local saja (karena getQcItems signature lama di abstract)
    return [];
  }

  @override
  Future<Map<String, dynamic>> getQcItemsByDivisionId({
    required String divisionId,
    String? unitId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'userId': _userId,
      'divisionId': divisionId,
      'page': page,
      'pageSize': pageSize,
    };
    if (unitId != null && unitId.isNotEmpty) {
      queryParams['unitId'] = unitId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await apiClient.get(
      ApiEndpoints.qcMonitoring,
      queryParameters: queryParams,
    );

    final raw = response.data as Map<String, dynamic>? ?? {};
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    final hasMore = data['hasMore'] as bool? ?? false;
    final total = (data['total'] as num?)?.toInt() ?? 0;

    // items from API is a flat list
    final rawItems = data['items'] as List<dynamic>? ?? [];

    // Group them exactly like the old way: Map unitId -> QcUnitGroup format
    final unitGroupMap = <String, Map<String, dynamic>>{};
    for (final rawItem in rawItems) {
      final itemMap = rawItem as Map<String, dynamic>;
      final carId = itemMap['unitId']?.toString() ?? '';
      final unitName = itemMap['unitName']?.toString() ?? '-';
      final divisionName = itemMap['divisionName']?.toString() ?? '-';

      unitGroupMap.putIfAbsent(carId, () {
        return {
          'unitId': carId,
          'unitName': unitName,
          'jobdescs': <Map<String, dynamic>>[],
        };
      });

      // mapping standard monitoring row
      (unitGroupMap[carId]!['jobdescs'] as List).add(
        _mapMonitoringRow(itemMap, division: divisionName, unitName: unitName),
      );
    }

    return {
      'hasMore': hasMore,
      'total': total,
      'groups': unitGroupMap.values.toList(),
    };
  }

  @override
  Future<void> submitQc({
    required String coreId,
    required String action,
    String? notes,
    int? inspectionDurationMinutes,
    String? photoBeforeUrl,
    String? evidencePhotoUrl,
    String? reworkDate,
    String? reworkAssignedUser,
    String? reworkDailyHours,
    String? reworkStartTime,
    String? reworkFinishTime,
    String? reworkDescription,
    bool? reworkIsOvertime,
    bool? reworkIsPriority,
  }) async {
    final body = <String, dynamic>{
      'userId': _userId,
      'coreId': coreId,
      'action': action,
    };

    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (inspectionDurationMinutes != null) {
      body['inspectionDurationMinutes'] = inspectionDurationMinutes;
    }
    if (photoBeforeUrl != null && photoBeforeUrl.isNotEmpty) {
      body['photoBeforeUrl'] = photoBeforeUrl;
    }
    if (evidencePhotoUrl != null && evidencePhotoUrl.isNotEmpty) {
      body['evidencePhotoUrl'] = evidencePhotoUrl;
    }

    if (action == 'tidak_lolos') {
      if (reworkDate != null) body['reworkDate'] = reworkDate;
      if (reworkAssignedUser != null) {
        body['reworkAssignedUser'] = reworkAssignedUser;
      }
      if (reworkDailyHours != null) body['reworkDailyHours'] = reworkDailyHours;
      if (reworkStartTime != null) body['reworkStartTime'] = reworkStartTime;
      if (reworkFinishTime != null) body['reworkFinishTime'] = reworkFinishTime;
      if (reworkDescription != null) {
        body['reworkDescription'] = reworkDescription;
      }
      if (reworkIsOvertime != null) body['reworkIsOvertime'] = reworkIsOvertime;
      if (reworkIsPriority != null) body['reworkIsPriority'] = reworkIsPriority;
    }

    await apiClient.post(ApiEndpoints.qc, data: body);
  }

  Future<Map<String, String>> getQcUploadTicket(String filename) async {
    final response = await apiClient.get(
      ApiEndpoints.qcUploadTicket,
      queryParameters: {'filename': filename},
    );
    final raw = response.data as Map<String, dynamic>? ?? {};
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;
    return {
      'upload_url': data['upload_url']?.toString() ?? '',
      'public_url': data['public_url']?.toString() ?? '',
    };
  }

  @override
  Future<Map<String, dynamic>?> findQcItemByCoreId(String coreId) async {
    return null;
  }

  Map<String, dynamic> _mapMonitoringRow(
    Map<String, dynamic> row, {
    required String division,
    required String unitName,
  }) {
    final qcLastStatus = '${row['qcLastStatus'] ?? ''}'.toUpperCase();
    final countdownStatus = '${row['status'] ?? ''}'.toUpperCase();
    final qcLevel = '${row['qcLevel'] ?? ''}'.toUpperCase();

    return {
      'qcId': row['coreId']?.toString() ?? '',
      'coreId': row['coreId']?.toString() ?? '',
      'unitId': row['unitId']?.toString() ?? '',
      'unitName': unitName,
      'panelName': row['panelName']?.toString() ?? '-',
      'jobName': row['jobName']?.toString() ?? '-',
      'mechanicDivision': division,
      'totalActualHours': 0.0,
      'targetHoursRevised': ((row['remainingHours'] as num?) ?? 0).toDouble(),
      'countdownStatus': countdownStatus,
      'qcLevel': qcLevel.isNotEmpty ? qcLevel : null,
      'qcLastStatus': qcLastStatus.isNotEmpty ? qcLastStatus : null,
      'qcNotes': null,
      'inspectionDurationMinutes': null,
      'remainingHours': ((row['remainingHours'] as num?) ?? 0).toDouble(),
      'reworkDate': null,
    };
  }

  Future<List<Map<String, dynamic>>> _getCountdownUnits() async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId},
    );
    return (response.data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getCountdownDivisions(
    String carId,
  ) async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId, 'car_id': carId},
    );
    return (response.data as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}
