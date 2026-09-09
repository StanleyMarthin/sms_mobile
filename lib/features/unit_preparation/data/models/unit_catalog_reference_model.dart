/*
Tujuan: Model parser reference catalog unit V2 dari response API.
Caller: UnitCatalogRepositoryImpl dan test model Unit Preparation.
Dependensi: UnitCatalogReference.
Main Functions: UnitCatalogReferenceModel.fromJson().
Side Effects: Tidak ada.
*/

import '../../domain/entities/unit_catalog_reference.dart';

class UnitCatalogReferenceModel extends UnitCatalogReference {
  const UnitCatalogReferenceModel({
    required super.id,
    required super.carId,
    required super.componentName,
    super.panelName,
    super.diagramImageUrl,
    super.referenceUrl,
    super.notes,
  });

  factory UnitCatalogReferenceModel.fromJson(Map<String, dynamic> json) {
    return UnitCatalogReferenceModel(
      id: _text(json['id']),
      carId: _text(json['car_id'] ?? json['carId']),
      componentName: _text(json['component_name'] ?? json['componentName']),
      panelName: _nullableText(json['panel_name'] ?? json['panelName']),
      diagramImageUrl: _nullableText(
        json['diagram_image_url'] ?? json['diagramImageUrl'],
      ),
      referenceUrl: _nullableText(
        json['reference_url'] ?? json['referenceUrl'],
      ),
      notes: _nullableText(json['notes']),
    );
  }
}

String _text(Object? value) => '${value ?? ''}'.trim();

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
