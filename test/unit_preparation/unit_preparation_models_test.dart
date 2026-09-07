/*
Tujuan: Test parser model Unit Preparation.
Caller: flutter test.
Dependensi: flutter_test dan model unit_preparation.
Main Functions: validasi unit search, component/panel parser, incomplete item, dan mapping normalized.
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/unit_preparation/domain/entities/unit_preparation_models.dart';

void main() {
  test('catalog component parses web API aliases', () {
    final component = CatalogComponent.fromJson({
      'id': 4,
      'code': 'BODY',
      'componentName': 'Body',
    });

    expect(component.id, 4);
    expect(component.code, 'BODY');
    expect(component.componentName, 'Body');
  });

  test('unit preparation unit searches name customer and plate', () {
    final unit = UnitPreparationUnit.fromJson({
      'car_id': 'MB220S_MRSANTOSO',
      'unit_name': 'MB 220S PONTON',
      'customer_name': 'Mr. SANTOSO',
      'plate_number': 'B 220 S',
      'status': 'PROSES',
      'contract_delivery_date': '2026-10-01',
    });

    expect(unit.carId, 'MB220S_MRSANTOSO');
    expect(unit.matches('ponton'), isTrue);
    expect(unit.matches('santoso'), isTrue);
    expect(unit.matches('B 220'), isTrue);
    expect(unit.matches('jaguar'), isFalse);
  });

  test('catalog item menerima part number kosong tanpa sentinel', () {
    final item = CatalogItem.fromJson({
      'id': 127,
      'part_number': null,
      'part_name': null,
      'qty_normal': null,
      'survey_status': 'NOT_STARTED',
    });

    expect(item.partNumber, isNull);
    expect(item.partName, isNull);
    expect(item.qtyNormal, isNull);
    expect(item.surveyStatus, 'NOT_STARTED');
  });

  test('catalog item parses alias name_part and code aliases', () {
    final item = CatalogItem.fromJson({
      'id': 127,
      'alias_name': '303',
      'name_part': 'Oil Dipstick Detail',
      'itemName': 'Oil Dipstick',
      'partNumber': 'A 110 010 01 72',
      'code': 'C 75 006a',
      'position': '303',
    });

    expect(item.aliasName, '303');
    expect(item.namePart, 'Oil Dipstick Detail');
    expect(item.partName, 'Oil Dipstick');
    expect(item.partNumber, 'A 110 010 01 72');
    expect(item.code, 'C 75 006a');
    expect(item.positionCode, '303');
  });

  test('catalog reference parses panel summary counts and diagram image', () {
    final reference = CatalogReference.fromJson({
      'id': 10,
      'component_name': 'BODY',
      'panel_name': 'FRONT DOOR LH',
      'diagram_image_url': 'https://cdn.example.com/front-door.jpg',
      'item_count': 45,
      'surveyed_count': 12,
    });

    expect(reference.itemCount, 45);
    expect(reference.surveyedCount, 12);
    expect(
      reference.media.single.fileUrl,
      'https://cdn.example.com/front-door.jpg',
    );
  });

  test('catalog media accepts backend image url aliases', () {
    final media = CatalogMedia.fromJson({
      'id': 12,
      'url_image': 'https://cdn.example.com/panel.jpg',
    });

    expect(media.fileUrl, 'https://cdn.example.com/panel.jpg');
  });

  test('mapping memakai koordinat normalized percent', () {
    final item = CatalogItem.fromJson({
      'id': 127,
      'surveyStatus': 'CONFIRMED',
      'mappings': [
        {
          'id': 1,
          'catalogReferenceMediaId': 5,
          'xPercent': 25.5,
          'yPercent': 75,
        },
      ],
    });

    expect(item.isConfirmed, isTrue);
    expect(item.mappings.single.catalogReferenceMediaId, 5);
    expect(item.mappings.single.xPercent, 25.5);
    expect(item.mappings.single.yPercent, 75);
  });
}
