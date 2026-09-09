/*
Tujuan: Repository Unit Catalog V2 yang memetakan datasource raw JSON ke entity.
Caller: DI/presentation Unit Preparation dan test repository.
Dependensi: UnitCatalogDataSource, UnitCatalog model/entity.
Main Functions: fetchCatalog, fetchReference, saveItemsBatch, updateSurvey, uploadMedia, promote.
Side Effects: Memanggil datasource HTTP.
*/

import '../../domain/entities/unit_catalog_item.dart';
import '../../domain/entities/unit_catalog_reference.dart';
import '../../domain/repositories/unit_catalog_repository.dart';
import '../datasources/unit_catalog_remote_datasource.dart';
import '../models/unit_catalog_item_model.dart';
import '../models/unit_catalog_media_model.dart';
import '../models/unit_catalog_reference_model.dart';

class UnitCatalogRepositoryImpl implements UnitCatalogRepository {
  UnitCatalogRepositoryImpl({required this.datasource});

  final UnitCatalogDataSource datasource;

  @override
  Future<List<UnitCatalogReference>> fetchCatalog(String unitId) async {
    final rows = await datasource.fetchCatalog(unitId);
    return rows.map(UnitCatalogReferenceModel.fromJson).toList();
  }

  @override
  Future<UnitCatalogReference> fetchReference({
    required String unitId,
    required String referenceId,
  }) async {
    final row = await datasource.fetchReference(
      unitId: unitId,
      referenceId: referenceId,
    );
    return UnitCatalogReferenceModel.fromJson(row);
  }

  @override
  Future<UnitCatalogReference> saveItemsBatch({
    required String unitId,
    required String referenceId,
    required List<Map<String, dynamic>> items,
  }) async {
    final row = await datasource.saveItemsBatch(
      unitId: unitId,
      referenceId: referenceId,
      items: items,
    );
    return UnitCatalogReferenceModel.fromJson(row);
  }

  @override
  Future<UnitCatalogItem> updateSurvey({
    required String unitId,
    required String itemId,
    double? qtyOpname,
    required AvailabilityStatus availability,
    required ConditionStatus condition,
    required CatalogAction action,
    String? location,
    String? notes,
  }) async {
    final row = await datasource.updateSurvey(
      unitId: unitId,
      itemId: itemId,
      survey: {
        'qtyOpname': qtyOpname,
        'availabilityStatus': availability.dbValue,
        'conditionStatus': condition.dbValue,
        'actionType': action.dbValue,
        'isRestoration':
            condition == ConditionStatus.restore ||
            action == CatalogAction.jobdesc ||
            action == CatalogAction.jobdescOrder,
        'location': _emptyToNull(location),
        'notes': _emptyToNull(notes),
      },
    );
    return UnitCatalogItemModel.fromJson(row);
  }

  @override
  Future<UnitCatalogMedia> uploadMedia({
    required String unitId,
    required String itemId,
    required String fileUrl,
    String? caption,
  }) async {
    final row = await datasource.uploadMedia(
      unitId: unitId,
      itemId: itemId,
      fileUrl: fileUrl,
      caption: caption,
    );
    return UnitCatalogMediaModel.fromJson(row);
  }

  @override
  Future<String?> promote({required String unitId, required String itemId}) {
    return datasource.promote(unitId: unitId, itemId: itemId);
  }
}

String? _emptyToNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
