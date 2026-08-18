import 'dart:convert';

class QcDivision {
  final String divisionId;
  final String divisionName;
  final int totalItem;

  QcDivision({
    required this.divisionId,
    required this.divisionName,
    required this.totalItem,
  });
}

class QcItem {
  QcItem({
    required this.qcId,
    required this.coreId,
    required this.unitId,
    required this.unitName,
    required this.panelName,
    required this.jobName,
    required this.mechanicDivision,
    required this.totalActualHours,
    required this.targetHoursRevised,
    required this.countdownStatus,
    this.qcLevel,
    this.qcLastStatus,
    this.qcNotes,
    this.inspectionDurationMinutes,
    this.remainingHours,
    this.reworkDate,
  });

  final String qcId;
  final String coreId;
  final String unitId;
  final String unitName;
  final String panelName;
  final String jobName;
  final String mechanicDivision;
  final double totalActualHours;
  final double targetHoursRevised;
  final String countdownStatus;

  /// Level QC tertinggi yang sudah pernah dilakukan pada countdown ini.
  final String? qcLevel;

  /// LOLOS / TIDAK_LOLOS — hasil QC terakhir
  final String? qcLastStatus;

  final String? qcNotes;
  final int? inspectionDurationMinutes;
  final double? remainingHours;
  final String? reworkDate;

  String toJson() => jsonEncode({
        'qcId': qcId,
        'coreId': coreId,
        'unitId': unitId,
        'unitName': unitName,
        'panelName': panelName,
        'jobName': jobName,
        'mechanicDivision': mechanicDivision,
        'totalActualHours': totalActualHours,
        'targetHoursRevised': targetHoursRevised,
        'countdownStatus': countdownStatus,
        'qcLevel': qcLevel,
        'qcLastStatus': qcLastStatus,
        'qcNotes': qcNotes,
        'inspectionDurationMinutes': inspectionDurationMinutes,
        'remainingHours': remainingHours,
        'reworkDate': reworkDate,
      });

  factory QcItem.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return QcItem(
      qcId: map['qcId'] as String,
      coreId: map['coreId'] as String,
      unitId: map['unitId'] as String,
      unitName: map['unitName'] as String,
      panelName: map['panelName'] as String,
      jobName: map['jobName'] as String,
      mechanicDivision: map['mechanicDivision'] as String,
      totalActualHours: (map['totalActualHours'] as num).toDouble(),
      targetHoursRevised: (map['targetHoursRevised'] as num).toDouble(),
      countdownStatus: map['countdownStatus'] as String,
      qcLevel: map['qcLevel'] as String?,
      qcLastStatus: map['qcLastStatus'] as String?,
      qcNotes: map['qcNotes'] as String?,
      inspectionDurationMinutes: map['inspectionDurationMinutes'] as int?,
      remainingHours: (map['remainingHours'] as num?)?.toDouble(),
      reworkDate: map['reworkDate'] as String?,
    );
  }
}

class QcUnitGroup {
  QcUnitGroup({
    required this.unitId,
    required this.unitName,
    required this.jobdescs,
  });

  final String unitId;
  final String unitName;
  final List<QcItem> jobdescs;
}

class QcPagedResponse {
  final List<QcUnitGroup> groups;
  final bool hasMore;
  final int page;
  final int total;

  QcPagedResponse({
    required this.groups,
    required this.hasMore,
    required this.page,
    required this.total,
  });
}
