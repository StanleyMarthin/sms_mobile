/*
Tujuan: Datasource API mobile untuk Unit Preparation catalog dan pendataan.
Caller: UnitPreparationPage dan flow mobile catalog survey.
Dependensi: ApiClient, ApiEndpoints, SessionManager, UnitPreparation models.
Main Functions: load units/components/catalog, save batch item, confirm survey, add media.
Side Effects: HTTP request ke be_sms sm_countdown.
*/

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import '../../domain/entities/unit_preparation_models.dart';

class RemoteUnitPreparationDatasource {
  RemoteUnitPreparationDatasource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  String get _userId =>
      sessionManager.userId ?? sessionManager.employeeId ?? '';

  Future<List<UnitPreparationUnit>> getUnits() async {
    final response = await apiClient.get(
      ApiEndpoints.countdown,
      queryParameters: {'user_id': _userId},
    );
    final rows = response.data is List ? response.data as List<dynamic> : [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(UnitPreparationUnit.fromJson)
        .where((unit) => unit.carId.isNotEmpty)
        .toList();
  }

  Future<List<CatalogComponent>> getComponents() async {
    final response = await apiClient.get(
      ApiEndpoints.catalogComponents,
      queryParameters: {'userId': _userId},
    );
    final data = response.data;
    final rows = data is Map<String, dynamic>
        ? data['components'] as List<dynamic>? ?? []
        : data is List
        ? data
        : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CatalogComponent.fromJson)
        .where((component) => component.code.isNotEmpty)
        .toList();
  }

  Future<List<CatalogReference>> getCatalog(String unitId) async {
    final response = await apiClient.get(
      ApiEndpoints.unitCatalog(unitId),
      queryParameters: {'userId': _userId},
    );
    final data = response.data;
    final rows = data is List
        ? data
        : data is Map<String, dynamic>
        ? data['references'] as List<dynamic>? ?? []
        : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(CatalogReference.fromJson)
        .toList();
  }

  Future<CatalogReference> getReference(String unitId, int referenceId) async {
    final response = await apiClient.get(
      ApiEndpoints.unitCatalogReference(unitId, referenceId),
      queryParameters: {'userId': _userId},
    );
    final data = response.data;
    final payload = data is Map<String, dynamic> && data['reference'] is Map
        ? Map<String, dynamic>.from(data['reference'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return CatalogReference.fromJson(payload);
  }

  Future<CatalogReference> openPanel({
    required String unitId,
    required String componentCode,
    required String panelName,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.unitCatalogOpenPanel(unitId),
      data: {
        'userId': _userId,
        'componentCode': componentCode,
        'panelName': panelName,
      },
    );
    return CatalogReference.fromJson(_extractWorkspace(response.data));
  }

  Future<CatalogReference> savePanelItemsBatch({
    required String unitId,
    required int panelId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.unitCatalogPanelItemsBatch(unitId, panelId),
      data: {'userId': _userId, 'items': items, 'deletedItemIds': []},
    );
    return CatalogReference.fromJson(_extractWorkspace(response.data));
  }

  Future<void> addPanelReferenceImage({
    required String unitId,
    required int panelId,
    required String fileUrl,
    String? caption,
  }) async {
    await apiClient.post(
      ApiEndpoints.unitCatalogPanelMedia(unitId, panelId),
      data: {
        'userId': _userId,
        'fileUrl': fileUrl,
        if (caption != null) 'caption': caption,
      },
    );
  }

  Future<Map<String, dynamic>> confirmSurvey({
    required String unitId,
    required int itemId,
    required Map<String, dynamic> survey,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.unitCatalogItemSurveyConfirm(unitId, itemId),
      data: {'userId': _userId, ...survey},
    );
    final data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> addActualPhoto({
    required String unitId,
    required int itemId,
    required String fileUrl,
    String? caption,
  }) async {
    await apiClient.post(
      ApiEndpoints.unitCatalogItemMedia(unitId, itemId),
      data: {
        'userId': _userId,
        'fileUrl': fileUrl,
        if (caption != null) 'caption': caption,
      },
    );
  }

  Map<String, dynamic> _extractWorkspace(Object? data) {
    if (data is Map<String, dynamic> && data['workspace'] is Map) {
      return Map<String, dynamic>.from(data['workspace'] as Map);
    }
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
