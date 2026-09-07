/*
Tujuan: Helper ringan untuk search catalog mobile dan marker posisi/foto.
Caller: UnitPreparationPage dan flutter test unit preparation.
Dependensi: dart:convert dan model unit preparation.
Main Functions: buildSearchEntries(), searchEntries(), item labels, batch payload, encode/decode annotation.
Side Effects: Tidak ada.
*/

import 'dart:convert';

import '../../domain/entities/unit_preparation_models.dart';

class CatalogSearchEntry {
  const CatalogSearchEntry({required this.reference, required this.item});

  final CatalogReference reference;
  final CatalogItem item;

  CatalogMedia? get catalogImage =>
      reference.media.isEmpty ? null : reference.media.first;
}

class CatalogComponentSummary {
  const CatalogComponentSummary({
    required this.componentName,
    required this.panelCount,
    required this.partCount,
    required this.doneCount,
  });

  final String componentName;
  final int panelCount;
  final int partCount;
  final int doneCount;
}

class CatalogPanelSummary {
  const CatalogPanelSummary({
    required this.reference,
    required this.panelName,
    required this.componentName,
    required this.partCount,
    required this.doneCount,
  });

  final CatalogReference reference;
  final String panelName;
  final String componentName;
  final int partCount;
  final int doneCount;
}

class CatalogAnnotationMarker {
  const CatalogAnnotationMarker({
    required this.name,
    required this.xPercent,
    required this.yPercent,
  });

  final String name;
  final double xPercent;
  final double yPercent;

  Map<String, dynamic> toJson() => {'name': name, 'x': xPercent, 'y': yPercent};

  factory CatalogAnnotationMarker.fromJson(Map<String, dynamic> json) =>
      CatalogAnnotationMarker(
        name: _textValue(json['name']) ?? '',
        xPercent: _doubleValue(json['x']) ?? 0,
        yPercent: _doubleValue(json['y']) ?? 0,
      );
}

class UnitPreparationCatalogHelper {
  static const componentFilters = [
    'ENGINE',
    'UNDERCARRIAGE',
    'ELECTRICAL',
    'BODY',
    'INTERIOR',
  ];

  static List<CatalogSearchEntry> buildSearchEntries(
    List<CatalogReference> references,
  ) {
    final entries = references
        .expand(
          (reference) => reference.items.map(
            (item) => CatalogSearchEntry(reference: reference, item: item),
          ),
        )
        .toList();

    entries.sort((left, right) {
      final confirmedOrder =
          _confirmedRank(left.item) - _confirmedRank(right.item);
      if (confirmedOrder != 0) return confirmedOrder;
      final panelOrder = left.reference.panelName.compareTo(
        right.reference.panelName,
      );
      if (panelOrder != 0) return panelOrder;
      return resolveItemLabel(
        left.item,
        left.reference,
      ).compareTo(resolveItemLabel(right.item, right.reference));
    });

    return entries;
  }

  static List<CatalogSearchEntry> searchEntries(
    List<CatalogSearchEntry> entries, {
    String query = '',
    String componentFilter = '',
    String panelFilter = '',
  }) {
    final normalizedQuery = _normalize(query);
    final normalizedComponent = _normalize(componentFilter);
    final normalizedPanel = _normalize(panelFilter);

    return entries.where((entry) {
      final component = _normalize(entry.reference.componentName);
      final panel = _normalize(entry.reference.panelName);
      final searchText = _normalize(
        [
          entry.item.partName,
          entry.item.aliasName,
          entry.item.namePart,
          entry.item.actualName,
          entry.item.partNumber,
          entry.item.code,
          entry.item.positionCode,
        ].whereType<String>().join(' '),
      );

      final matchesQuery =
          normalizedQuery.isEmpty || searchText.contains(normalizedQuery);
      final matchesComponent =
          normalizedComponent.isEmpty ||
          component.contains(normalizedComponent);
      final matchesPanel =
          normalizedPanel.isEmpty || panel.contains(normalizedPanel);
      return matchesQuery && matchesComponent && matchesPanel;
    }).toList();
  }

  static List<UnitPreparationUnit> searchUnits(
    List<UnitPreparationUnit> units,
    String query,
  ) {
    return units.where((unit) => unit.matches(query)).toList();
  }

  static List<CatalogComponentSummary> componentSummaries(
    List<CatalogReference> references,
  ) {
    final result = <CatalogComponentSummary>[];
    for (final component in componentFilters) {
      final panels = references
          .where(
            (reference) =>
                _normalize(reference.componentName) == _normalize(component),
          )
          .toList();
      if (panels.isEmpty) continue;
      result.add(
        CatalogComponentSummary(
          componentName: component,
          panelCount: panels.map((panel) => panel.id).toSet().length,
          partCount: panels.fold<int>(
            0,
            (sum, panel) => sum + _partCount(panel),
          ),
          doneCount: panels.fold<int>(
            0,
            (sum, panel) => sum + _doneCount(panel),
          ),
        ),
      );
    }
    return result;
  }

  static List<CatalogComponent> componentsFromReferences(
    List<CatalogReference> references,
  ) {
    final names = references
        .map((reference) => reference.componentName.trim().toUpperCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    return componentFilters
        .where(names.contains)
        .map(
          (name) => CatalogComponent(
            id: componentFilters.indexOf(name) + 1,
            code: name,
            componentName: name,
          ),
        )
        .toList();
  }

  static List<CatalogPanelSummary> panelSummaries(
    List<CatalogReference> references,
    String component, {
    String query = '',
  }) {
    final normalizedComponent = _normalize(component);
    final normalizedQuery = _normalize(query);
    final panels = references
        .where((reference) {
          final sameComponent =
              normalizedComponent.isEmpty ||
              _normalize(reference.componentName) == normalizedComponent;
          final matchesQuery =
              normalizedQuery.isEmpty ||
              _normalize(reference.panelName).contains(normalizedQuery);
          return sameComponent && matchesQuery;
        })
        .map((reference) {
          return CatalogPanelSummary(
            reference: reference,
            panelName: reference.panelName,
            componentName: reference.componentName,
            partCount: _partCount(reference),
            doneCount: _doneCount(reference),
          );
        })
        .toList();
    panels.sort((left, right) => left.panelName.compareTo(right.panelName));
    return panels;
  }

  static List<CatalogSearchEntry> panelPartEntries(
    List<CatalogSearchEntry> entries, {
    required int referenceId,
    String query = '',
  }) {
    return searchEntries(
      entries.where((entry) => entry.reference.id == referenceId).toList(),
      query: query,
    );
  }

  static List<CatalogSearchEntry> globalCatalogSearch(
    List<CatalogSearchEntry> entries,
    String query,
  ) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];
    return entries.where((entry) {
      final haystack = _normalize(
        [
          entry.reference.componentName,
          entry.reference.panelName,
          entry.item.partName,
          entry.item.aliasName,
          entry.item.namePart,
          entry.item.actualName,
          entry.item.partNumber,
          entry.item.code,
          entry.item.positionCode,
        ].whereType<String>().join(' '),
      );
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  static String hierarchyLabel(CatalogSearchEntry entry) =>
      '${entry.reference.componentName} > ${entry.reference.panelName}';

  static String itemPrimaryLabel(
    CatalogItem item,
    CatalogReference reference,
  ) =>
      _textValue(item.aliasName) ??
      _textValue(item.partName) ??
      _nonNumericText(item.positionCode) ??
      reference.panelName;

  static String itemSecondaryLabel(CatalogItem item) =>
      _textValue(item.partNumber) ?? '-';

  static String itemDetailLabel(CatalogItem item) =>
      _textValue(item.namePart) ?? _textValue(item.code) ?? '';

  static String itemOriginalLabel(CatalogItem item) =>
      _textValue(item.namePart) ?? _textValue(item.partName) ?? '-';

  static List<Map<String, dynamic>> batchItemPayloads(
    List<CatalogBatchItemRow> rows,
  ) {
    return rows
        .map((row) {
          final payload = {
            'id': null,
            'clientRowId': null,
            'code': _textValue(row.code),
            'partNumber': _textValue(row.partNumber),
            'itemName': _textValue(row.itemName),
            'position': _textValue(row.position),
            'qtyNormal': _doubleValue(row.qtyNormal),
            'isRestoration': false,
          };
          final empty =
              payload['code'] == null &&
              payload['partNumber'] == null &&
              payload['itemName'] == null &&
              payload['position'] == null &&
              payload['qtyNormal'] == null;
          return empty ? null : payload;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static List<String> panelOptions(List<CatalogReference> references) {
    final panels =
        references
            .map((reference) => reference.panelName.trim())
            .where((panel) => panel.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return panels;
  }

  static CatalogSearchEntry? nextSurveyEntry(
    List<CatalogSearchEntry> entries,
    int currentItemId,
  ) {
    final currentIndex = entries.indexWhere(
      (entry) => entry.item.id == currentItemId,
    );
    if (currentIndex < 0) {
      return entries.where((entry) => !entry.item.isConfirmed).firstOrNull;
    }
    for (var index = currentIndex + 1; index < entries.length; index++) {
      if (!entries[index].item.isConfirmed) return entries[index];
    }
    for (var index = 0; index < currentIndex; index++) {
      if (!entries[index].item.isConfirmed) return entries[index];
    }
    return null;
  }

  static String surveyStatusLabel(String value) => switch (value) {
    'CONFIRMED' || 'DONE' => 'Sudah didata',
    'DRAFT' => 'Belum didata',
    'NOT_STARTED' => 'Belum dicek',
    _ => 'Belum dicek',
  };

  static String availabilityLabel(String value) => switch (value) {
    'AVAILABLE' => 'Ada',
    'NOT_AVAILABLE' => 'Tidak Ada',
    _ => 'Tidak Ditemukan',
  };

  static String conditionLabel(String value) => switch (value) {
    'GOOD' => 'Layak',
    'RESTORE' => 'Restorasi',
    'NOT_USABLE' => 'Tidak Layak',
    _ => 'Tidak Ditemukan',
  };

  static String errorLabel({
    int? statusCode,
    bool network = false,
    String fallback = 'Gagal memuat data.',
  }) {
    if (statusCode == 401) return 'Sesi berakhir. Silakan masuk kembali.';
    if (statusCode == 403) return 'Anda tidak memiliki akses.';
    if (statusCode == 404) return 'Unit tidak ditemukan.';
    if (network) return 'Tidak dapat terhubung ke server.';
    return fallback;
  }

  static String resolveItemLabel(CatalogItem item, CatalogReference reference) {
    final values = [
      item.aliasName,
      item.partName,
      item.namePart,
      item.actualName,
      _nonNumericText(item.positionCode),
      item.code,
      reference.panelName,
      item.partNumber,
      reference.componentName,
    ];

    for (final value in values) {
      final text = _textValue(value);
      if (text != null) return text;
    }

    return 'Item ${item.id}';
  }

  static String resolveMarkerName(
    CatalogItem item,
    CatalogReference reference,
  ) {
    final values = [
      item.partName,
      item.aliasName,
      item.namePart,
      item.actualName,
      reference.panelName,
      reference.componentName,
      _nonNumericText(item.positionCode),
    ];

    for (final value in values) {
      final text = _textValue(value);
      if (text != null) return text;
    }

    return 'Item ${item.id}';
  }

  static String encodePositionMarker(CatalogMapping marker) {
    return jsonEncode({
      'x': (marker.xPercent / 100).clamp(0.0, 1.0).toDouble(),
      'y': (marker.yPercent / 100).clamp(0.0, 1.0).toDouble(),
    });
  }

  static CatalogMapping? decodePositionMarker(String? position) {
    final text = _textValue(position);
    if (text == null) return null;
    try {
      final payload = jsonDecode(text);
      if (payload is! Map<String, dynamic>) return null;
      final x = _doubleValue(payload['x']);
      final y = _doubleValue(payload['y']);
      if (x == null || y == null) return null;
      return CatalogMapping(
        id: 0,
        catalogReferenceMediaId: 0,
        xPercent: (x * 100).clamp(0.0, 100.0).toDouble(),
        yPercent: (y * 100).clamp(0.0, 100.0).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static String encodeActualPhotoCaption(
    List<CatalogAnnotationMarker> markers,
  ) {
    return jsonEncode({
      'markers': markers.map((marker) => marker.toJson()).toList(),
    });
  }

  static List<CatalogAnnotationMarker> decodeActualPhotoMarkers(
    List<CatalogMedia> media,
  ) {
    final latest = pickActualPhoto(media);
    return latest == null ? const [] : decodeActualPhotoCaption(latest.caption);
  }

  static List<CatalogAnnotationMarker> decodeActualPhotoCaption(
    String? caption,
  ) {
    final text = _textValue(caption);
    if (text == null) return const [];

    try {
      final payload = jsonDecode(text);
      if (payload is! Map<String, dynamic>) return const [];
      final markers = payload['markers'];
      if (markers is! List) return const [];
      return markers
          .whereType<Map<String, dynamic>>()
          .map(CatalogAnnotationMarker.fromJson)
          .where((marker) => marker.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static CatalogMedia? pickActualPhoto(List<CatalogMedia> media) {
    if (media.isEmpty) return null;
    return media.last;
  }

  static int _confirmedRank(CatalogItem item) => item.isConfirmed ? 1 : 0;

  static int _partCount(CatalogReference reference) =>
      reference.items.isNotEmpty ? reference.items.length : reference.itemCount;

  static int _doneCount(CatalogReference reference) =>
      reference.items.isNotEmpty
      ? reference.items.where((item) => item.isConfirmed).length
      : reference.surveyedCount;
}

double? _doubleValue(Object? value) {
  if (value == null) return null;
  return double.tryParse('$value');
}

String _normalize(String value) => value.trim().toLowerCase();

String? _nonNumericText(String? value) {
  final text = _textValue(value);
  if (text == null) return null;
  if (text.startsWith('{') || text.startsWith('[')) return null;
  return RegExp(r'^\d+$').hasMatch(text) ? null : text;
}

String? _textValue(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
