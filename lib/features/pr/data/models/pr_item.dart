/// Model for a single item within a Purchase Request.
///
/// Maps to backend table `pur_pr_items`.
/// Statuses: HUNTING → ORDERED → ARRIVED | NOT_FOUND | CANCELLED
class PRItem {
  final String id;
  final String prId;
  final String? itemName;
  final String? description;
  final String? originType; // LOKAL | LN
  final double? qty;
  final String? uom;
  final double? estimatedPrice;
  final double? actualPrice;
  final String? vendorId;
  final String? vendorName;
  final String? photoUrl;
  final String? huntingNotes;
  final String? status; // HUNTING|ORDERED|ARRIVED|NOT_FOUND|CANCELLED
  final DateTime? arrivalDate;
  final DateTime? createdAt;

  const PRItem({
    required this.id,
    required this.prId,
    this.itemName,
    this.description,
    this.originType,
    this.qty,
    this.uom,
    this.estimatedPrice,
    this.actualPrice,
    this.vendorId,
    this.vendorName,
    this.photoUrl,
    this.huntingNotes,
    this.status,
    this.arrivalDate,
    this.createdAt,
  });

  factory PRItem.fromJson(Map<String, dynamic> json) {
    return PRItem(
      id: '${json['id'] ?? ''}',
      prId: '${json['pr_id'] ?? json['prId'] ?? ''}',
      itemName: json['item_name'] as String? ?? json['itemName'] as String?,
      description: json['description'] as String?,
      originType: json['origin_type'] as String? ?? json['originType'] as String?,
      qty: _toDouble(json['qty']),
      uom: json['uom'] as String?,
      estimatedPrice: _toDouble(json['estimated_price'] ?? json['estimatedPrice']),
      actualPrice: _toDouble(json['actual_price'] ?? json['actualPrice']),
      vendorId: json['vendor_id'] as String? ?? json['vendorId'] as String?,
      vendorName: json['vendor_name'] as String? ?? json['vendorName'] as String?,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      huntingNotes: json['hunting_notes'] as String? ?? json['huntingNotes'] as String?,
      status: json['status'] as String?,
      arrivalDate: _parseDate(json['arrival_date'] ?? json['arrivalDate']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  /// Serialize for create/update payloads (camelCase for backend).
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'itemId': id,
      if (itemName != null) 'itemName': itemName,
      if (description != null) 'description': description,
      if (originType != null) 'originType': originType,
      if (qty != null) 'qty': qty,
      if (uom != null) 'uom': uom,
      if (estimatedPrice != null) 'estimatedPrice': estimatedPrice,
      if (actualPrice != null) 'actualPrice': actualPrice,
      if (vendorId != null) 'vendorId': vendorId,
      if (vendorName != null) 'vendorName': vendorName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (huntingNotes != null) 'huntingNotes': huntingNotes,
      if (status != null) 'status': status,
      if (arrivalDate != null) 'arrivalDate': arrivalDate!.toIso8601String().split('T').first,
    };
  }

  PRItem copyWith({
    String? id,
    String? prId,
    String? itemName,
    String? description,
    String? originType,
    double? qty,
    String? uom,
    double? estimatedPrice,
    double? actualPrice,
    String? vendorId,
    String? vendorName,
    String? photoUrl,
    String? huntingNotes,
    String? status,
    DateTime? arrivalDate,
  }) {
    return PRItem(
      id: id ?? this.id,
      prId: prId ?? this.prId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      originType: originType ?? this.originType,
      qty: qty ?? this.qty,
      uom: uom ?? this.uom,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      actualPrice: actualPrice ?? this.actualPrice,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      photoUrl: photoUrl ?? this.photoUrl,
      huntingNotes: huntingNotes ?? this.huntingNotes,
      status: status ?? this.status,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      createdAt: createdAt,
    );
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
