/*
Tujuan: Kontrak repository Unit Catalog V2 untuk mobile Unit Preparation.
Caller: Presentation layer Unit Preparation dan test repository.
Dependensi: UnitCatalogReference, UnitCatalogItem.
Main Functions: UnitCatalogRepository methods.
Side Effects: Implementasi dapat memanggil HTTP API.
*/

import '../entities/unit_catalog_item.dart';
import '../entities/unit_catalog_reference.dart';

abstract class UnitCatalogRepository {
  Future<List<UnitCatalogReference>> fetchCatalog(String unitId);

  Future<UnitCatalogReference> fetchReference({
    required String unitId,
    required String referenceId,
  });

  Future<UnitCatalogReference> saveItemsBatch({
    required String unitId,
    required String referenceId,
    required List<Map<String, dynamic>> items,
  });

  Future<UnitCatalogItem> updateSurvey({
    required String unitId,
    required String itemId,
    double? qtyOpname,
    required AvailabilityStatus availability,
    required ConditionStatus condition,
    required CatalogAction action,
    String? location,
    String? notes,
  });

  Future<UnitCatalogMedia> uploadMedia({
    required String unitId,
    required String itemId,
    required String fileUrl,
    String? caption,
  });

  Future<String?> promote({required String unitId, required String itemId});
}
