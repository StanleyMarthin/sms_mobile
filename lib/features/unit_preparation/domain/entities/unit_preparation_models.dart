/*
Tujuan: Model ringan untuk flow Unit Preparation catalog dan pendataan.
Caller: RemoteUnitPreparationDatasource dan halaman UnitPreparationPage.
Dependensi: Tidak ada.
Main Functions: CatalogReference, CatalogItem, CatalogMedia, CatalogMapping parser.
Side Effects: Tidak ada.
*/

Object? _pick(Map<String, dynamic> json, String snake, String camel) =>
    json[snake] ?? json[camel];

int _intValue(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double? _doubleValue(Object? value) {
  if (value == null) return null;
  return double.tryParse('$value');
}

String? _textValue(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

class CatalogMedia {
  const CatalogMedia({
    required this.id,
    required this.fileUrl,
    this.caption,
    this.sortOrder = 0,
  });

  final int id;
  final String fileUrl;
  final String? caption;
  final int sortOrder;

  factory CatalogMedia.fromJson(Map<String, dynamic> json) => CatalogMedia(
    id: _intValue(json['id']),
    fileUrl: _textValue(_pick(json, 'file_url', 'fileUrl')) ?? '',
    caption: _textValue(json['caption']),
    sortOrder: _intValue(_pick(json, 'sort_order', 'sortOrder')),
  );
}

class CatalogMapping {
  const CatalogMapping({
    required this.id,
    required this.catalogReferenceMediaId,
    required this.xPercent,
    required this.yPercent,
  });

  final int id;
  final int catalogReferenceMediaId;
  final double xPercent;
  final double yPercent;

  factory CatalogMapping.fromJson(Map<String, dynamic> json) => CatalogMapping(
    id: _intValue(json['id']),
    catalogReferenceMediaId: _intValue(
      _pick(json, 'catalog_reference_media_id', 'catalogReferenceMediaId'),
    ),
    xPercent: _doubleValue(_pick(json, 'x_percent', 'xPercent')) ?? 0,
    yPercent: _doubleValue(_pick(json, 'y_percent', 'yPercent')) ?? 0,
  );
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    this.positionCode,
    this.partNumber,
    this.partName,
    this.qtyNormal,
    this.qtyOpname,
    this.actualName,
    this.availabilityStatus = 'UNKNOWN',
    this.conditionStatus = 'UNKNOWN',
    this.actionType = 'UNDECIDED',
    this.surveyStatus = 'NOT_STARTED',
    this.location,
    this.notes,
    this.promotedPanelId,
    this.media = const [],
    this.mappings = const [],
  });

  final int id;
  final String? positionCode;
  final String? partNumber;
  final String? partName;
  final double? qtyNormal;
  final double? qtyOpname;
  final String? actualName;
  final String availabilityStatus;
  final String conditionStatus;
  final String actionType;
  final String surveyStatus;
  final String? location;
  final String? notes;
  final int? promotedPanelId;
  final List<CatalogMedia> media;
  final List<CatalogMapping> mappings;

  bool get isConfirmed => surveyStatus == 'CONFIRMED';

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
    id: _intValue(json['id']),
    positionCode: _textValue(_pick(json, 'position_code', 'positionCode')),
    partNumber: _textValue(_pick(json, 'part_number', 'partNumber')),
    partName: _textValue(_pick(json, 'part_name', 'partName')),
    qtyNormal: _doubleValue(_pick(json, 'qty_normal', 'qtyNormal')),
    qtyOpname: _doubleValue(_pick(json, 'qty_opname', 'qtyOpname')),
    actualName: _textValue(_pick(json, 'actual_name', 'actualName')),
    availabilityStatus:
        _textValue(_pick(json, 'availability_status', 'availabilityStatus')) ??
        'UNKNOWN',
    conditionStatus:
        _textValue(_pick(json, 'condition_status', 'conditionStatus')) ??
        'UNKNOWN',
    actionType:
        _textValue(_pick(json, 'action_type', 'actionType')) ?? 'UNDECIDED',
    surveyStatus:
        _textValue(_pick(json, 'survey_status', 'surveyStatus')) ??
        'NOT_STARTED',
    location: _textValue(json['location']),
    notes: _textValue(json['notes']),
    promotedPanelId: _pick(json, 'promoted_panel_id', 'promotedPanelId') == null
        ? null
        : _intValue(_pick(json, 'promoted_panel_id', 'promotedPanelId')),
    media: (json['media'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogMedia.fromJson)
        .toList(),
    mappings: (json['mappings'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogMapping.fromJson)
        .toList(),
  );
}

class CatalogReference {
  const CatalogReference({
    required this.id,
    required this.componentName,
    required this.panelName,
    this.media = const [],
    this.items = const [],
  });

  final int id;
  final String componentName;
  final String panelName;
  final List<CatalogMedia> media;
  final List<CatalogItem> items;

  factory CatalogReference.fromJson(Map<String, dynamic> json) =>
      CatalogReference(
        id: _intValue(json['id']),
        componentName:
            _textValue(_pick(json, 'component_name', 'componentName')) ?? '',
        panelName: _textValue(_pick(json, 'panel_name', 'panelName')) ?? '',
        media: (json['media'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogMedia.fromJson)
            .toList(),
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogItem.fromJson)
            .toList(),
      );
}
