/*
Tujuan: Helper ringan untuk search catalog mobile dan annotation marker foto aktual.
Caller: UnitPreparationPage dan flutter test unit preparation.
Dependensi: dart:convert dan model unit preparation.
Main Functions: buildSearchEntries(), searchEntries(), resolveMarkerName(), encode/decode annotation.
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
          entry.item.actualName,
          entry.item.partNumber,
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
    'DRAFT' => 'Draft',
    'NOT_STARTED' => 'Belum dicek',
    _ => 'Belum dicek',
  };

  static String availabilityLabel(String value) => switch (value) {
    'AVAILABLE' => 'Ada',
    'NOT_AVAILABLE' => 'Tidak ada',
    _ => 'Belum tahu',
  };

  static String conditionLabel(String value) => switch (value) {
    'GOOD' => 'Baik',
    'RESTORE' => 'Restorasi',
    'NOT_USABLE' => 'Tidak layak',
    _ => 'Belum diketahui',
  };

  static String actionLabel(String value) => switch (value) {
    'NO_ACTION' => 'Tidak perlu tindakan',
    'JOBDESC' => 'Buat pekerjaan',
    'JOBDESC_ORDER' => 'Order pekerjaan',
    _ => 'Belum diputuskan',
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
      item.partName,
      item.actualName,
      _nonNumericText(item.positionCode),
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
}

double? _doubleValue(Object? value) {
  if (value == null) return null;
  return double.tryParse('$value');
}

String _normalize(String value) => value.trim().toLowerCase();

String? _nonNumericText(String? value) {
  final text = _textValue(value);
  if (text == null) return null;
  return RegExp(r'^\d+$').hasMatch(text) ? null : text;
}

String? _textValue(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
