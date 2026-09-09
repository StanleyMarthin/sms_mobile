/*
Tujuan: Model parser item catalog unit V2 dari response API.
Caller: UnitCatalogRepositoryImpl dan test model Unit Preparation.
Dependensi: UnitCatalogItem, UnitCatalogMediaModel.
Main Functions: UnitCatalogItemModel.fromJson().
Side Effects: Tidak ada.
*/

import '../../domain/entities/unit_catalog_item.dart';
import 'unit_catalog_media_model.dart';

class UnitCatalogItemModel extends UnitCatalogItem {
  const UnitCatalogItemModel({
    required super.id,
    required super.catalogReferenceId,
    super.positionCode,
    super.partNumber,
    super.partName,
    super.qtyNormal,
    super.qtyOpname,
    super.availability,
    super.condition,
    super.action,
    super.location,
    super.notes,
    super.promotedPanelId,
    super.media,
  });

  factory UnitCatalogItemModel.fromJson(Map<String, dynamic> json) {
    return UnitCatalogItemModel(
      id: _text(json['id']),
      catalogReferenceId: _text(
        json['catalog_reference_id'] ??
            json['catalogReferenceId'] ??
            json['panel_id'],
      ),
      positionCode: _nullableText(
        json['position_code'] ?? json['positionCode'] ?? json['position'],
      ),
      partNumber: _nullableText(json['part_number'] ?? json['partNumber']),
      partName: _nullableText(
        json['part_name'] ??
            json['partName'] ??
            json['item_name'] ??
            json['itemName'] ??
            json['name_part'] ??
            json['namePart'],
      ),
      qtyNormal: _doubleValue(json['qty_normal'] ?? json['qtyNormal']),
      qtyOpname: _doubleValue(json['qty_opname'] ?? json['qtyOpname']),
      availability: AvailabilityStatusDb.fromDb(
        json['availability_status'] ?? json['availabilityStatus'],
      ),
      condition: ConditionStatusDb.fromDb(
        json['condition_status'] ?? json['conditionStatus'],
      ),
      action: CatalogActionDb.fromDb(json['action_type'] ?? json['actionType']),
      location: _nullableText(json['location']),
      notes: _nullableText(json['notes']),
      promotedPanelId: _nullableText(
        json['promoted_panel_id'] ?? json['promotedPanelId'],
      ),
      media: (json['media'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(UnitCatalogMediaModel.fromJson)
          .toList(),
    );
  }
}

String _text(Object? value) => '${value ?? ''}'.trim();

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

double? _doubleValue(Object? value) {
  if (value == null) return null;
  return double.tryParse('$value');
}
