/*
Tujuan: Entity reference catalog unit V2 untuk diagram/panel preparation.
Caller: UnitCatalogRepository dan UI Unit Preparation.
Dependensi: Tidak ada.
Main Functions: UnitCatalogReference.
Side Effects: Tidak ada.
*/

class UnitCatalogReference {
  const UnitCatalogReference({
    required this.id,
    required this.carId,
    required this.componentName,
    this.panelName,
    this.diagramImageUrl,
    this.referenceUrl,
    this.notes,
  });

  final String id;
  final String carId;
  final String componentName;
  final String? panelName;
  final String? diagramImageUrl;
  final String? referenceUrl;
  final String? notes;
}
