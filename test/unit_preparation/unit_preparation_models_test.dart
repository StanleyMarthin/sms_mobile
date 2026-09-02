/*
Tujuan: Test parser model Unit Preparation.
Caller: flutter test.
Dependensi: flutter_test dan model unit_preparation.
Main Functions: validasi incomplete item dan mapping normalized.
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/unit_preparation/domain/entities/unit_preparation_models.dart';

void main() {
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
