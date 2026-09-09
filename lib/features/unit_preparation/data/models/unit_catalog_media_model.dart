/*
Tujuan: Model parser media item catalog unit dari response API.
Caller: UnitCatalogItemModel dan UnitCatalogRepositoryImpl.
Dependensi: UnitCatalogMedia.
Main Functions: UnitCatalogMediaModel.fromJson().
Side Effects: Tidak ada.
*/

import '../../domain/entities/unit_catalog_item.dart';

class UnitCatalogMediaModel extends UnitCatalogMedia {
  const UnitCatalogMediaModel({
    required super.id,
    required super.fileUrl,
    super.caption,
  });

  factory UnitCatalogMediaModel.fromJson(Map<String, dynamic> json) {
    return UnitCatalogMediaModel(
      id: '${json['id'] ?? ''}',
      fileUrl: _text(json['file_url'] ?? json['fileUrl'] ?? json['url_image']),
      caption: _nullableText(json['caption']),
    );
  }
}

String _text(Object? value) => '${value ?? ''}'.trim();

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
