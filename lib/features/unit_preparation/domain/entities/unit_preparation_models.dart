/*
Tujuan: Model ringan untuk flow Unit Preparation catalog dan pendataan.
Caller: RemoteUnitPreparationDatasource dan halaman UnitPreparationPage.
Dependensi: Tidak ada.
Main Functions: CatalogComponent, CatalogReference, CatalogItem, CatalogMedia, CatalogMapping parser.
Side Effects: Tidak ada.
*/

Object? _pick(Map<String, dynamic> json, String snake, String camel) =>
    json[snake] ?? json[camel];

Object? _pickAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json[key] != null) return json[key];
  }
  return null;
}

int _intValue(Object? value) => int.tryParse('${value ?? 0}') ?? 0;

double? _doubleValue(Object? value) {
  if (value == null) return null;
  return double.tryParse('$value');
}

String? _textValue(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

class UnitPreparationUnit {
  const UnitPreparationUnit({
    required this.carId,
    required this.unitName,
    this.customerName,
    this.plateNumber,
    this.status,
    this.deliveryDate,
  });

  final String carId;
  final String unitName;
  final String? customerName;
  final String? plateNumber;
  final String? status;
  final String? deliveryDate;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      carId,
      unitName,
      customerName,
      plateNumber,
    ].whereType<String>().join(' ').toLowerCase().contains(normalized);
  }

  factory UnitPreparationUnit.fromJson(Map<String, dynamic> json) {
    final carId =
        _textValue(
          json['car_id'] ?? json['carId'] ?? json['id'] ?? json['unitId'],
        ) ??
        '';
    return UnitPreparationUnit(
      carId: carId,
      unitName:
          _textValue(
            json['unit_name'] ?? json['unitName'] ?? json['carName'],
          ) ??
          carId,
      customerName: _textValue(
        json['customer_name'] ?? json['customerName'] ?? json['owner'],
      ),
      plateNumber: _textValue(
        json['plate_number'] ?? json['plateNumber'] ?? json['plate'],
      ),
      status: _textValue(json['status']),
      deliveryDate: _textValue(
        json['contract_delivery_date'] ??
            json['deliveryDate'] ??
            json['targetDelivery'],
      ),
    );
  }
}

class CatalogComponent {
  const CatalogComponent({
    required this.id,
    required this.code,
    required this.componentName,
  });

  final int id;
  final String code;
  final String componentName;

  factory CatalogComponent.fromJson(Map<String, dynamic> json) =>
      CatalogComponent(
        id: _intValue(json['id']),
        code: _textValue(json['code']) ?? '',
        componentName:
            _textValue(_pick(json, 'component_name', 'componentName')) ?? '',
      );
}

class CatalogBatchItemRow {
  const CatalogBatchItemRow({
    this.code,
    this.partNumber,
    this.itemName,
    this.position,
    this.qtyNormal,
  });

  final String? code;
  final String? partNumber;
  final String? itemName;
  final String? position;
  final String? qtyNormal;
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
    this.code,
    this.aliasName,
    this.namePart,
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
  final String? code;
  final String? aliasName;
  final String? namePart;
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
    code: _textValue(json['code']),
    aliasName: _textValue(_pick(json, 'alias_name', 'aliasName')),
    namePart: _textValue(_pick(json, 'name_part', 'namePart')),
    positionCode: _textValue(
      _pickAny(json, ['position_code', 'positionCode', 'position']),
    ),
    partNumber: _textValue(_pick(json, 'part_number', 'partNumber')),
    partName: _textValue(
      _pickAny(json, ['part_name', 'partName', 'item_name', 'itemName']),
    ),
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
    this.itemCount = 0,
    this.surveyedCount = 0,
    this.media = const [],
    this.items = const [],
  });

  final int id;
  final String componentName;
  final String panelName;
  final int itemCount;
  final int surveyedCount;
  final List<CatalogMedia> media;
  final List<CatalogItem> items;

  factory CatalogReference.fromJson(Map<String, dynamic> json) {
    final panel = json['panel'] is Map
        ? Map<String, dynamic>.from(json['panel'] as Map)
        : const <String, dynamic>{};
    final mediaRows =
        json['media'] as List<dynamic>? ??
        json['panelImages'] as List<dynamic>? ??
        const [];
    final media = mediaRows
        .whereType<Map<String, dynamic>>()
        .map(CatalogMedia.fromJson)
        .toList();
    final diagramImage = _textValue(
      json['diagram_image_url'] ?? json['diagramImageUrl'] ?? json['imageUrl'],
    );
    if (diagramImage != null && media.isEmpty) {
      media.add(CatalogMedia(id: 0, fileUrl: diagramImage));
    }
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogItem.fromJson)
        .toList();
    final countValue = _intValue(_pick(json, 'item_count', 'itemCount'));
    return CatalogReference(
      id: _intValue(json['id'] ?? panel['id']),
      componentName:
          _textValue(
            _pick(json, 'component_name', 'componentName') ??
                _pick(panel, 'component_name', 'componentName'),
          ) ??
          '',
      panelName:
          _textValue(
            _pick(json, 'panel_name', 'panelName') ??
                _pick(panel, 'panel_name', 'panelName'),
          ) ??
          '',
      itemCount: countValue == 0 ? items.length : countValue,
      surveyedCount: _intValue(
        _pick(json, 'surveyed_count', 'surveyedCount') ??
            json['restorationCount'],
      ),
      media: media,
      items: items,
    );
  }
}
