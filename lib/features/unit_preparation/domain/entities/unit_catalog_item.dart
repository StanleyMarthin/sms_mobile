/*
Tujuan: Entity item catalog unit V2 untuk pendataan dan promote Master Panel.
Caller: UnitCatalogRepository, SurveyPage, dan widget Unit Preparation.
Dependensi: Tidak ada.
Main Functions: UnitCatalogItem, UnitCatalogMedia, enum mapping catalog survey.
Side Effects: Tidak ada.
*/

enum AvailabilityStatus { unknown, available, notAvailable }

enum ConditionStatus { unknown, good, restore, notUsable }

enum CatalogAction { undecided, noAction, jobdesc, jobdescOrder }

extension AvailabilityStatusDb on AvailabilityStatus {
  String get dbValue => switch (this) {
    AvailabilityStatus.available => 'AVAILABLE',
    AvailabilityStatus.notAvailable => 'NOT_AVAILABLE',
    AvailabilityStatus.unknown => 'UNKNOWN',
  };

  static AvailabilityStatus fromDb(Object? value) {
    return switch ('${value ?? ''}'.trim().toUpperCase()) {
      'AVAILABLE' => AvailabilityStatus.available,
      'NOT_AVAILABLE' => AvailabilityStatus.notAvailable,
      _ => AvailabilityStatus.unknown,
    };
  }
}

extension ConditionStatusDb on ConditionStatus {
  String get dbValue => switch (this) {
    ConditionStatus.good => 'GOOD',
    ConditionStatus.restore => 'RESTORE',
    ConditionStatus.notUsable => 'NOT_USABLE',
    ConditionStatus.unknown => 'UNKNOWN',
  };

  static ConditionStatus fromDb(Object? value) {
    return switch ('${value ?? ''}'.trim().toUpperCase()) {
      'GOOD' => ConditionStatus.good,
      'RESTORE' => ConditionStatus.restore,
      'NOT_USABLE' => ConditionStatus.notUsable,
      _ => ConditionStatus.unknown,
    };
  }
}

extension CatalogActionDb on CatalogAction {
  String get dbValue => switch (this) {
    CatalogAction.noAction => 'NO_ACTION',
    CatalogAction.jobdesc => 'JOBDESC',
    CatalogAction.jobdescOrder => 'JOBDESC_ORDER',
    CatalogAction.undecided => 'UNDECIDED',
  };

  static CatalogAction fromDb(Object? value) {
    return switch ('${value ?? ''}'.trim().toUpperCase()) {
      'NO_ACTION' => CatalogAction.noAction,
      'JOBDESC' => CatalogAction.jobdesc,
      'JOBDESC_ORDER' => CatalogAction.jobdescOrder,
      _ => CatalogAction.undecided,
    };
  }
}

class UnitCatalogMedia {
  const UnitCatalogMedia({
    required this.id,
    required this.fileUrl,
    this.caption,
  });

  final String id;
  final String fileUrl;
  final String? caption;
}

class UnitCatalogItem {
  const UnitCatalogItem({
    required this.id,
    required this.catalogReferenceId,
    this.positionCode,
    this.partNumber,
    this.partName,
    this.qtyNormal,
    this.qtyOpname,
    this.availability = AvailabilityStatus.unknown,
    this.condition = ConditionStatus.unknown,
    this.action = CatalogAction.undecided,
    this.location,
    this.notes,
    this.promotedPanelId,
    this.media = const [],
  });

  final String id;
  final String catalogReferenceId;
  final String? positionCode;
  final String? partNumber;
  final String? partName;
  final double? qtyNormal;
  final double? qtyOpname;
  final AvailabilityStatus availability;
  final ConditionStatus condition;
  final CatalogAction action;
  final String? location;
  final String? notes;
  final String? promotedPanelId;
  final List<UnitCatalogMedia> media;

  bool get isPromoted => promotedPanelId != null && promotedPanelId!.isNotEmpty;

  String get displayTitle {
    final name = _text(partName);
    if (name != null) return name;
    final number = _text(partNumber);
    if (number != null) return number;
    final position = _text(positionCode);
    if (position != null) return 'Item #$position';
    return 'Item #$id';
  }

  String get displaySubtitle {
    final number = _text(partNumber);
    if (number != null && number != displayTitle) return number;
    if (_text(partName) == null) return 'Nama belum diketahui';
    return '';
  }
}

String? _text(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
