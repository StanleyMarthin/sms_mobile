/// Model for Purchase Request header.
///
/// Maps to backend table `pur_pr_header` + aggregated item counts.
/// Used for both list (items empty) and detail (items populated) views.
///
/// Approval chain: PENDING_ADV → PENDING_KP → PENDING_MP → PENDING_PUR → APPROVED
/// Once APPROVED, `status` becomes OPEN → HUNTING → DONE.
import 'pr_item.dart';

class PRHeader {
  final String reqId;
  final String? prNumber;
  final String? carName;
  final String? divisionName;
  final String? requestedByName;
  final String? accTracking;
  final String? status;
  final String? notes;
  final DateTime? targetDate;
  final String? priority;
  final DateTime? createdAt;
  final int totalItems;
  final int arrivedItems;
  final int huntingItems;
  final int orderedItems;
  final int cancelledItems;
  final List<PRItem> items;

  const PRHeader({
    required this.reqId,
    this.prNumber,
    this.carName,
    this.divisionName,
    this.requestedByName,
    this.accTracking,
    this.status,
    this.notes,
    this.targetDate,
    this.priority,
    this.createdAt,
    this.totalItems = 0,
    this.arrivedItems = 0,
    this.huntingItems = 0,
    this.orderedItems = 0,
    this.cancelledItems = 0,
    this.items = const [],
  });

  factory PRHeader.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(PRItem.fromJson)
            .toList()
        : <PRItem>[];

    return PRHeader(
      reqId: '${json['reqId'] ?? json['id'] ?? ''}',
      prNumber: json['prNumber'] as String? ?? json['pr_number'] as String?,
      carName: json['car_name'] as String? ?? json['carName'] as String?,
      divisionName: json['division_name'] as String? ?? json['divisionName'] as String?,
      requestedByName: json['requested_by_name'] as String? ?? json['requestedByName'] as String?,
      accTracking: json['acc_tracking'] as String? ?? json['accTracking'] as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      targetDate: _parseDate(json['target_date'] ?? json['targetDate']),
      priority: json['priority'] as String?,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      totalItems: _toInt(json['totalItems'] ?? json['total_items']),
      arrivedItems: _toInt(json['arrivedItems'] ?? json['arrived_items']),
      huntingItems: _toInt(json['huntingItems'] ?? json['hunting_items']),
      orderedItems: _toInt(json['orderedItems'] ?? json['ordered_items']),
      cancelledItems: _toInt(json['cancelledItems'] ?? json['cancelled_items']),
      items: items,
    );
  }

  /// Display label: accTracking if still in approval, otherwise status.
  String get displayStatus {
    if (accTracking != null && accTracking != 'APPROVED') {
      return accTracking!;
    }
    return status ?? 'UNKNOWN';
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
