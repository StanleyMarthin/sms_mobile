/*
Tujuan: Mengunci search-first catalog dan annotation marker untuk mobile survey.
Caller: flutter test.
Dependensi: flutter_test, UnitPreparationCatalogHelper, model unit preparation.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/unit_preparation/domain/entities/unit_preparation_models.dart';
import 'package:sm_system/features/unit_preparation/presentation/utils/unit_preparation_catalog_helper.dart';

CatalogReference _reference({
  required int id,
  required String component,
  required String panel,
  required List<Map<String, dynamic>> items,
  List<Map<String, dynamic>> media = const [],
}) {
  return CatalogReference.fromJson({
    'id': id,
    'componentName': component,
    'panelName': panel,
    'items': items,
    'media': media,
  });
}

void main() {
  final references = [
    _reference(
      id: 1,
      component: 'BODY',
      panel: 'FRONT FENDER LH',
      media: const [
        {'id': 10, 'fileUrl': 'https://cdn.example.com/fender.jpg'},
      ],
      items: const [
        {
          'id': 11,
          'partName': 'Front Fender Trim',
          'partNumber': '1248810301',
          'positionCode': 'FF-LH-01',
        },
        {'id': 12, 'partNumber': '998877', 'positionCode': '42'},
      ],
    ),
    _reference(
      id: 2,
      component: 'INTERIOR',
      panel: 'DOOR TRIM RH',
      items: const [
        {
          'id': 21,
          'partName': 'Door Trim Clip',
          'partNumber': 'CLIP-7788',
          'positionCode': 'DR-RH-02',
        },
      ],
    ),
  ];

  test('search finds item by part name prefix', () {
    final entries = UnitPreparationCatalogHelper.searchEntries(
      UnitPreparationCatalogHelper.buildSearchEntries(references),
      query: 'fend',
    );

    expect(entries, hasLength(1));
    expect(entries.single.item.id, 11);
  });

  test('search finds item by part number', () {
    final entries = UnitPreparationCatalogHelper.searchEntries(
      UnitPreparationCatalogHelper.buildSearchEntries(references),
      query: '1248810301',
    );

    expect(entries, hasLength(1));
    expect(entries.single.item.id, 11);
  });

  test('search filters by component and panel text', () {
    final entries = UnitPreparationCatalogHelper.searchEntries(
      UnitPreparationCatalogHelper.buildSearchEntries(references),
      componentFilter: 'inter',
      panelFilter: 'door',
    );

    expect(entries, hasLength(1));
    expect(entries.single.item.id, 21);
  });

  test('search finds item by position code with combined filters', () {
    final entries = UnitPreparationCatalogHelper.searchEntries(
      UnitPreparationCatalogHelper.buildSearchEntries(references),
      query: 'DR-RH-02',
      componentFilter: 'INTERIOR',
      panelFilter: 'DOOR',
    );

    expect(entries, hasLength(1));
    expect(entries.single.item.id, 21);
  });

  test('uses fixed workshop component chips', () {
    expect(UnitPreparationCatalogHelper.componentFilters, [
      'ENGINE',
      'UNDERCARRIAGE',
      'ELECTRICAL',
      'BODY',
      'INTERIOR',
    ]);
  });

  test('builds distinct sorted panel filter options', () {
    expect(UnitPreparationCatalogHelper.panelOptions(references), [
      'DOOR TRIM RH',
      'FRONT FENDER LH',
    ]);
  });

  test('maps backend status values to Indonesian labels', () {
    expect(
      UnitPreparationCatalogHelper.surveyStatusLabel('NOT_STARTED'),
      'Belum dicek',
    );
    expect(UnitPreparationCatalogHelper.surveyStatusLabel('DRAFT'), 'Draft');
    expect(
      UnitPreparationCatalogHelper.surveyStatusLabel('CONFIRMED'),
      'Sudah didata',
    );
    expect(
      UnitPreparationCatalogHelper.availabilityLabel('UNKNOWN'),
      'Belum tahu',
    );
    expect(
      UnitPreparationCatalogHelper.conditionLabel('NOT_USABLE'),
      'Tidak layak',
    );
    expect(
      UnitPreparationCatalogHelper.actionLabel('UNDECIDED'),
      'Belum diputuskan',
    );
  });

  test('finds next unchecked item after confirmation', () {
    final entries = UnitPreparationCatalogHelper.buildSearchEntries(references);
    final next = UnitPreparationCatalogHelper.nextSurveyEntry(
      entries,
      entries.first.item.id,
    );

    expect(next?.item.id, 12);
  });

  test('marker name prefers panel or item label instead of numeric code', () {
    final name = UnitPreparationCatalogHelper.resolveMarkerName(
      references.first.items[1],
      references.first,
    );

    expect(name, 'FRONT FENDER LH');
  });

  test('annotation caption round-trips markers', () {
    final caption = UnitPreparationCatalogHelper.encodeActualPhotoCaption([
      const CatalogAnnotationMarker(
        name: 'Front Fender LH',
        xPercent: 35.2,
        yPercent: 52.1,
      ),
    ]);

    final markers = UnitPreparationCatalogHelper.decodeActualPhotoMarkers([
      CatalogMedia(
        id: 1,
        fileUrl: 'https://cdn.example.com/actual.jpg',
        caption: caption,
      ),
    ]);

    expect(markers, hasLength(1));
    expect(markers.single.name, 'Front Fender LH');
    expect(markers.single.xPercent, 35.2);
    expect(markers.single.yPercent, 52.1);
  });

  test('latest actual photo caption controls visible markers', () {
    final markers = UnitPreparationCatalogHelper.decodeActualPhotoMarkers([
      CatalogMedia(
        id: 1,
        fileUrl: 'https://cdn.example.com/actual-old.jpg',
        caption: UnitPreparationCatalogHelper.encodeActualPhotoCaption([
          const CatalogAnnotationMarker(
            name: 'Front Fender LH',
            xPercent: 35.2,
            yPercent: 52.1,
          ),
        ]),
      ),
      const CatalogMedia(
        id: 2,
        fileUrl: 'https://cdn.example.com/actual-new.jpg',
      ),
    ]);

    expect(markers, isEmpty);
  });

  test('maps API and network errors to workshop-safe messages', () {
    expect(
      UnitPreparationCatalogHelper.errorLabel(statusCode: 401),
      'Sesi berakhir. Silakan masuk kembali.',
    );
    expect(
      UnitPreparationCatalogHelper.errorLabel(statusCode: 403),
      'Anda tidak memiliki akses.',
    );
    expect(
      UnitPreparationCatalogHelper.errorLabel(statusCode: 404),
      'Unit tidak ditemukan.',
    );
    expect(
      UnitPreparationCatalogHelper.errorLabel(network: true),
      'Tidak dapat terhubung ke server.',
    );
  });
}
