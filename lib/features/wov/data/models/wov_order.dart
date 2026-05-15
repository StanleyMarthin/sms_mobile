/// Model for Work Order Vendor (WOV).
///
/// Maps to backend table `vnd_wo_vendor`.
/// Approval chain: PENDING_ADV → PENDING_KP → PENDING_PM → APPROVED
/// Once APPROVED, status lifecycle: OPEN → SENT → PROSES_VENDOR → DONE_VENDOR → RECEIVED
///
/// Note: `unitPartEntryId` has been removed from the backend schema.
class WOVOrder {
  final String reqId;
  final String? wovNumber;
  final String? carName;
  final String? vendorName;
  final String? picVendor;
  final String? itemName;
  final double? quantity;
  final String? uom;
  final String? accTracking;
  final String? status;
  final String? qcStatus;
  final String? goodsConditionOut;
  final String? goodsConditionIn;
  final double? estimatedCost;
  final double? actualCost;
  final String? remarks;
  final DateTime? dateOut;
  final DateTime? targetDateReturn;
  final DateTime? dateIn;
  final DateTime? createdAt;

  const WOVOrder({
    required this.reqId,
    this.wovNumber,
    this.carName,
    this.vendorName,
    this.picVendor,
    this.itemName,
    this.quantity,
    this.uom,
    this.accTracking,
    this.status,
    this.qcStatus,
    this.goodsConditionOut,
    this.goodsConditionIn,
    this.estimatedCost,
    this.actualCost,
    this.remarks,
    this.dateOut,
    this.targetDateReturn,
    this.dateIn,
    this.createdAt,
  });

  factory WOVOrder.fromJson(Map<String, dynamic> json) {
    return WOVOrder(
      reqId: '${json['reqId'] ?? json['id'] ?? ''}',
      wovNumber: json['wov_number'] as String? ?? json['wovNumber'] as String?,
      carName: json['car_name'] as String? ?? json['carName'] as String?,
      vendorName: json['vendor_name'] as String? ?? json['vendorName'] as String?,
      picVendor: json['pic_vendor'] as String? ?? json['picVendor'] as String?,
      itemName: json['item_name'] as String? ?? json['itemName'] as String?,
      quantity: _toDouble(json['quantity']),
      uom: json['uom'] as String?,
      accTracking: json['acc_tracking'] as String? ?? json['accTracking'] as String?,
      status: json['status'] as String?,
      qcStatus: json['qc_status'] as String? ?? json['qcStatus'] as String?,
      goodsConditionOut: json['goods_condition_out'] as String? ?? json['goodsConditionOut'] as String?,
      goodsConditionIn: json['goods_condition_in'] as String? ?? json['goodsConditionIn'] as String?,
      estimatedCost: _toDouble(json['estimated_cost'] ?? json['estimatedCost']),
      actualCost: _toDouble(json['actual_cost'] ?? json['actualCost']),
      remarks: json['remarks'] as String?,
      dateOut: _parseDate(json['date_out'] ?? json['dateOut']),
      targetDateReturn: _parseDate(json['target_date_return'] ?? json['targetDateReturn']),
      dateIn: _parseDate(json['date_in'] ?? json['dateIn']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  /// Display label: accTracking if still in approval, otherwise status.
  String get displayStatus {
    if (accTracking != null && accTracking != 'APPROVED') {
      return accTracking!;
    }
    return status ?? 'UNKNOWN';
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
