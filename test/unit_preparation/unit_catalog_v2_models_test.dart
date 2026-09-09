/*
Tujuan: Test kontrak model Unit Catalog V2 untuk data nullable dan enum mapping.
Caller: flutter test.
Dependensi: flutter_test, unit catalog V2 models.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/unit_preparation/data/models/unit_catalog_item_model.dart';
import 'package:sm_system/features/unit_preparation/data/models/unit_catalog_reference_model.dart';
import 'package:sm_system/features/unit_preparation/domain/entities/unit_catalog_item.dart';

void main() {
  test(
    'reference parses database fields without division/category leakage',
    () {
      final reference = UnitCatalogReferenceModel.fromJson({
        'id': 9,
        'car_id': '220S',
        'component_name': 'BODY',
        'panel_name': 'FRONT BODY',
        'diagram_image_url': 'https://cdn.example.com/body.jpg',
        'reference_url': 'https://parts.example.com',
        'notes': 'EPC source',
      });

      expect(reference.id, '9');
      expect(reference.carId, '220S');
      expect(reference.componentName, 'BODY');
      expect(reference.panelName, 'FRONT BODY');
      expect(reference.diagramImageUrl, 'https://cdn.example.com/body.jpg');
    },
  );

  test('item keeps nullable part number name and qty without sentinels', () {
    final item = UnitCatalogItemModel.fromJson({
      'id': 127,
      'catalog_reference_id': 9,
      'position_code': '127',
      'part_number': null,
      'part_name': null,
      'qty_normal': null,
      'media': const [],
    });

    expect(item.id, '127');
    expect(item.positionCode, '127');
    expect(item.partNumber, isNull);
    expect(item.partName, isNull);
    expect(item.qtyNormal, isNull);
    expect(item.displayTitle, 'Item #127');
  });

  test('item title uses part number when name is empty', () {
    final item = UnitCatalogItemModel.fromJson({
      'id': '128',
      'catalogReferenceId': '9',
      'partNumber': 'A000123',
      'partName': null,
    });

    expect(item.displayTitle, 'A000123');
    expect(item.displaySubtitle, 'Nama belum diketahui');
  });

  test('enum mapping accepts database strings and writes database strings', () {
    final item = UnitCatalogItemModel.fromJson({
      'id': '1',
      'catalog_reference_id': '2',
      'availability_status': 'AVAILABLE',
      'condition_status': 'RESTORE',
      'action_type': 'JOBDESC_ORDER',
    });

    expect(item.availability, AvailabilityStatus.available);
    expect(item.condition, ConditionStatus.restore);
    expect(item.action, CatalogAction.jobdescOrder);
    expect(item.availability.dbValue, 'AVAILABLE');
    expect(item.condition.dbValue, 'RESTORE');
    expect(item.action.dbValue, 'JOBDESC_ORDER');
  });
}
