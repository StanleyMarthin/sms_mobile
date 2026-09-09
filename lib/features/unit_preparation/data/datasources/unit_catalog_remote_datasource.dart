/*
Tujuan: Datasource Unit Catalog V2 yang memakai ApiClient existing.
Caller: UnitCatalogRepositoryImpl.
Dependensi: ApiClient, ApiEndpoints, SessionManager.
Main Functions: fetchCatalog, fetchReference, saveItemsBatch, updateSurvey, uploadMedia, promote.
Side Effects: HTTP request ke gateway Unit Preparation.
*/

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';

abstract class UnitCatalogDataSource {
  Future<List<Map<String, dynamic>>> fetchCatalog(String unitId);

  Future<Map<String, dynamic>> fetchReference({
    required String unitId,
    required String referenceId,
  });

  Future<Map<String, dynamic>> saveItemsBatch({
    required String unitId,
    required String referenceId,
    required List<Map<String, dynamic>> items,
  });

  Future<Map<String, dynamic>> updateSurvey({
    required String unitId,
    required String itemId,
    required Map<String, dynamic> survey,
  });

  Future<Map<String, dynamic>> uploadMedia({
    required String unitId,
    required String itemId,
    required String fileUrl,
    String? caption,
  });

  Future<String?> promote({required String unitId, required String itemId});
}

class UnitCatalogRemoteDataSource implements UnitCatalogDataSource {
  UnitCatalogRemoteDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  @override
  Future<List<Map<String, dynamic>>> fetchCatalog(String unitId) async {
    final response = await apiClient.get(
      ApiEndpoints.unitCatalog(unitId),
      queryParameters: {'userId': _userId},
    );
    final data = response.data;
    final rows = data is Map<String, dynamic>
        ? data['references'] as List<dynamic>? ?? []
        : data is List
        ? data
        : const [];
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>> fetchReference({
    required String unitId,
    required String referenceId,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.unitCatalogReference(unitId, int.parse(referenceId)),
      queryParameters: {'userId': _userId},
    );
    return _extractMap(response.data, 'reference');
  }

  @override
  Future<Map<String, dynamic>> saveItemsBatch({
    required String unitId,
    required String referenceId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.unitCatalogReferenceItemsBatch(unitId, referenceId),
      data: {'userId': _userId, 'items': items},
    );
    return _extractMap(response.data, 'reference');
  }

  @override
  Future<Map<String, dynamic>> updateSurvey({
    required String unitId,
    required String itemId,
    required Map<String, dynamic> survey,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.unitCatalogItemSurvey(unitId, int.parse(itemId)),
      data: {'userId': _userId, ...survey},
    );
    return _extractMap(response.data, 'item');
  }

  @override
  Future<Map<String, dynamic>> uploadMedia({
    required String unitId,
    required String itemId,
    required String fileUrl,
    String? caption,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.unitCatalogItemMedia(unitId, int.parse(itemId)),
      data: {
        'userId': _userId,
        'fileUrl': fileUrl,
        if (caption != null) 'caption': caption,
      },
    );
    return _extractMap(response.data, '');
  }

  @override
  Future<String?> promote({
    required String unitId,
    required String itemId,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.unitCatalogItemPromote(unitId, int.parse(itemId)),
      data: {'userId': _userId},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return _text(
        data['promotedPanelId'] ??
            data['promoted_panel_id'] ??
            data['panelId'] ??
            data['id'],
      );
    }
    return null;
  }

  Map<String, dynamic> _extractMap(Object? data, String key) {
    if (data is Map<String, dynamic>) {
      final nested = key.isEmpty ? null : data[key];
      if (nested is Map<String, dynamic>) return nested;
      if (data['workspace'] is Map<String, dynamic>) {
        return data['workspace'] as Map<String, dynamic>;
      }
      return data;
    }
    return <String, dynamic>{};
  }
}

String? _text(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
