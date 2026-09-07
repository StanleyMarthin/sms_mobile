/*
Tujuan: Test parser model Unit Preparation.
Caller: flutter test.
Dependensi: flutter_test dan model unit_preparation.
Main Functions: validasi unit search, reference summary, incomplete item, dan mapping normalized.
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/unit_preparation/domain/entities/unit_preparation_models.dart';

void main() {
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
