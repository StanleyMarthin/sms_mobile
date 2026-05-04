library;

class WarehouseItemSuggestion {
  const WarehouseItemSuggestion({
    required this.id,
    required this.itemName,
    required this.itemCode,
    required this.itemCategory,
    required this.uom,
    this.matchedAlias,
    this.photoUrls = const [],
    this.lastLocation,
  });

  final String id;
  final String itemName;
  final String itemCode;
  final String itemCategory;
  final String uom;
  final String? matchedAlias;
  final List<String> photoUrls;
  final String? lastLocation;
}
