library;

class WarehouseLog {
  const WarehouseLog({
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
    this.notes,
    this.returnDate,
  });

  final String id;
  final String transactionType;
  final String itemCategory;
  final String itemName;
  final int qty;
  final String uom;
  final DateTime requestDate;
  final String itemStatus;
  final String approvalStatus;
  final String requester;
  final String division;
  final String? notes;
  final DateTime? returnDate;
}