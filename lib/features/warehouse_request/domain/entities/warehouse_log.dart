library;

class WarehouseLog {
  WarehouseLog({
    required this.id,
    required this.transactionType,
    required this.itemCategory,
    required this.itemName,
    required this.qty,
    required this.uom,
    required this.requestDate,
    required this.itemStatus,
    required this.approvalStatus,
    required this.requester,
    required this.division,
    this.employeeId,
    this.divisionId,
    this.itemMasterId,
    this.itemAliasUsed,
    this.carId,
    this.coreId,
    this.unitName,
    this.panelName,
    this.jobdesc,
    this.stockCardId,
    this.itemCondition,
    this.qtyReturned,
    this.storageLocationId,
    this.locationDetail,
    this.picWarehouseName,
    this.accKdName,
    this.targetSearchDate,
    this.actualReleaseDate,
    this.deadlineDate,
    this.actualReturnDate,
    this.photoUrls,
    this.notes,
    this.approvalHistory = const [],
  });

  final String id;
  final String transactionType;
  final String itemCategory;
  final String itemName;
  final double qty;
  final String uom;
  final DateTime requestDate;
  final String itemStatus;
  final String approvalStatus;
  final String requester;
  final String division;

  // relational
  final String? employeeId;
  final int? divisionId;
  final String? itemMasterId;
  final String? itemAliasUsed;
  final String? carId;
  final String? coreId;
  final String? unitName;
  final String? panelName;
  final String? jobdesc;
  final String? stockCardId;

  // return / storage
  final String? itemCondition;
  final double? qtyReturned;
  final int? storageLocationId;
  final String? locationDetail;
  final String? picWarehouseName;
  final String? accKdName;

  // dates
  final DateTime? targetSearchDate;
  final DateTime? actualReleaseDate;
  final DateTime? deadlineDate;
  final DateTime? actualReturnDate;

  // media
  final List<String>? photoUrls;
  final String? notes;
  final List<WarehouseApprovalStep> approvalHistory;

  // ── computed ──────────────────────────────────────────────
  bool get isPendingKd => approvalStatus == 'PENDING_KD';
  bool get isPendingWh => approvalStatus == 'PENDING_KEPALA_GUDANG';
  bool get isPendingPpic => approvalStatus == 'PENDING_PPIC';
  bool get isAnyPending => isPendingKd || isPendingWh || isPendingPpic;
  bool get isApproved => approvalStatus == 'APPROVED';
  bool get isRejected => approvalStatus == 'REJECTED';
  bool get isPenyimpanan => transactionType == 'PENYIMPANAN';
  String get normalizedItemStatus {
    final status = itemStatus.trim().toUpperCase();
    if (status.isNotEmpty) return status;
    if (isApproved && !isPenyimpanan) return 'OPEN';
    return status;
  }

  bool get isOpen => normalizedItemStatus == 'OPEN';
  bool get isReady => normalizedItemStatus == 'READY';
  bool get isReleased => normalizedItemStatus == 'RELEASED';
  bool get isReturned => normalizedItemStatus == 'RETURNED';
  bool get isInstalled => normalizedItemStatus == 'INSTALLED';
  bool get isStored => normalizedItemStatus == 'STORED';
  bool get isInstallToUnit => (notes ?? '').contains('[INSTALL_TO_UNIT]');
  bool get needsLocate =>
      isPenyimpanan &&
      isStored &&
      storageLocationId == null &&
      (locationDetail == null || locationDetail!.trim().isEmpty);

  String get displayStatus {
    if (isRejected) return 'DITOLAK';
    if (isAnyPending) return approvalStatus.replaceAll('_', ' ');
    if (isReady) return 'READY';
    return normalizedItemStatus;
  }
}

class WarehouseApprovalStep {
  WarehouseApprovalStep({
    required this.stage,
    required this.action,
    this.userId,
    this.name,
    this.notes,
    this.timestamp,
  });

  final String stage;
  final String action;
  final String? userId;
  final String? name;
  final String? notes;
  final DateTime? timestamp;
}
