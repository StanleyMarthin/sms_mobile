/*
Tujuan: Datasource API mobile untuk Unit Preparation catalog dan pendataan.
Caller: UnitPreparationPage dan flow mobile yang butuh catalog/master panel.
Dependensi: ApiClient, ApiEndpoints, SessionManager, UnitPreparation models.
Main Functions: load units, load catalog, save draft, confirm survey, add media, create jobdescs.
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

  Future<CatalogItem> saveDraft({
    required String unitId,
    required int itemId,
    required Map<String, dynamic> survey,
  }) async {
    final response = await apiClient.put(
      ApiEndpoints.unitCatalogItemSurvey(unitId, itemId),
      data: {'userId': _userId, ...survey},
    );
    return CatalogItem.fromJson(_extractItem(response.data));
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

  Future<Map<String, dynamic>> getMasterPanel(
    String unitId,
    int panelId,
  ) async {
    final response = await apiClient.get(
      ApiEndpoints.unitMasterPanel(unitId, panelId),
      queryParameters: {'userId': _userId},
    );
    return response.data as Map<String, dynamic>? ?? {};
  }

  Future<List<dynamic>> createJobdescs({
    required String unitId,
    required int panelId,
    required List<Map<String, dynamic>> jobs,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.unitMasterPanelJobdescs(unitId, panelId),
      data: {'userId': _userId, 'jobs': jobs},
    );
    final data = response.data;
    return data is List
        ? data
        : data is Map<String, dynamic>
        ? data['jobdescs'] as List<dynamic>? ?? []
        : const [];
  }

  Map<String, dynamic> _extractItem(Object? data) {
    if (data is Map<String, dynamic> && data['item'] is Map) {
      return Map<String, dynamic>.from(data['item'] as Map);
    }
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
