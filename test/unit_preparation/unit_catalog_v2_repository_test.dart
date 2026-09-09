/*
Tujuan: Test repository Unit Catalog V2 agar mapping API tidak bocor ke UI.
Caller: flutter test.
Dependensi: flutter_test, UnitCatalogRepositoryImpl, fake datasource.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/unit_preparation/data/datasources/unit_catalog_remote_datasource.dart';
import 'package:sm_system/features/unit_preparation/data/repositories/unit_catalog_repository_impl.dart';
import 'package:sm_system/features/unit_preparation/domain/entities/unit_catalog_item.dart';

void main() {
  test('fetchCatalog maps references from datasource payload', () async {
    final datasource = _FakeCatalogDatasource();
    final repository = UnitCatalogRepositoryImpl(datasource: datasource);

    final references = await repository.fetchCatalog('220S');

    expect(datasource.fetchCatalogCalls, 1);
    expect(references.single.componentName, 'BODY');
    expect(references.single.panelName, 'FRONT BODY');
  });

  test('updateSurvey sends database enum values', () async {
    final datasource = _FakeCatalogDatasource();
    final repository = UnitCatalogRepositoryImpl(datasource: datasource);

    final item = await repository.updateSurvey(
      unitId: '220S',
      itemId: '127',
      qtyOpname: 1,
      availability: AvailabilityStatus.available,
      condition: ConditionStatus.good,
      action: CatalogAction.noAction,
      location: 'Rak A',
      notes: 'checked',
    );

    expect(datasource.lastSurvey?['availabilityStatus'], 'AVAILABLE');
    expect(datasource.lastSurvey?['conditionStatus'], 'GOOD');
    expect(datasource.lastSurvey?['actionType'], 'NO_ACTION');
    expect(item.qtyOpname, 1);
  });

  test('upload media and promote return parsed records', () async {
    final datasource = _FakeCatalogDatasource();
    final repository = UnitCatalogRepositoryImpl(datasource: datasource);

    final media = await repository.uploadMedia(
      unitId: '220S',
      itemId: '127',
      fileUrl: 'https://cdn.example.com/part.jpg',
      caption: 'Foto Part',
    );
    final promotedPanelId = await repository.promote(
      unitId: '220S',
      itemId: '127',
    );

    expect(media.fileUrl, 'https://cdn.example.com/part.jpg');
    expect(promotedPanelId, '9001');
  });
}

class _FakeCatalogDatasource implements UnitCatalogDataSource {
  int fetchCatalogCalls = 0;
  Map<String, dynamic>? lastSurvey;

  @override
  Future<List<Map<String, dynamic>>> fetchCatalog(String unitId) async {
    fetchCatalogCalls += 1;
    return [
      {
        'id': 9,
        'car_id': unitId,
        'component_name': 'BODY',
        'panel_name': 'FRONT BODY',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchReference({
    required String unitId,
    required String referenceId,
  }) async {
    return {
      'id': referenceId,
      'car_id': unitId,
      'component_name': 'BODY',
      'panel_name': 'FRONT BODY',
      'items': const [],
    };
  }

  @override
  Future<Map<String, dynamic>> saveItemsBatch({
    required String unitId,
    required String referenceId,
    required List<Map<String, dynamic>> items,
  }) async {
    return {'items': items};
  }

  @override
  Future<Map<String, dynamic>> updateSurvey({
    required String unitId,
    required String itemId,
    required Map<String, dynamic> survey,
  }) async {
    lastSurvey = survey;
    return {
      'id': itemId,
      'catalog_reference_id': '9',
      'qty_opname': survey['qtyOpname'],
      'availability_status': survey['availabilityStatus'],
      'condition_status': survey['conditionStatus'],
      'action_type': survey['actionType'],
    };
  }

  @override
  Future<Map<String, dynamic>> uploadMedia({
    required String unitId,
    required String itemId,
    required String fileUrl,
    String? caption,
  }) async {
    return {'id': 1, 'file_url': fileUrl, 'caption': caption};
  }

  @override
  Future<String?> promote({
    required String unitId,
    required String itemId,
  }) async {
    return '9001';
  }
}
