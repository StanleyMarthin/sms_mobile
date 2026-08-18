library;

import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/session/session_manager.dart';
import 'notifications_datasource.dart';

class RemoteNotificationsDataSource implements NotificationsDataSource {
  RemoteNotificationsDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final SessionManager sessionManager;

  @override
  Future<List<Map<String, dynamic>>> getNotifications({
    required String? role,
  }) async {
    final employeeId = sessionManager.employeeId ?? sessionManager.userId ?? '';
    if (employeeId.isEmpty) return <Map<String, dynamic>>[];

    final response = await apiClient.get(
      ApiEndpoints.notifications,
      queryParameters: {'employee_id': employeeId, 'page': 1, 'limit': 50},
    );

    final list = _extractNotificationList(response.data);
    return list.map(_normalizeItem).toList();
  }

  List<Map<String, dynamic>> _extractNotificationList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    if (data is Map<String, dynamic>) {
      final fromItems = data['items'];
      if (fromItems is List) {
        return fromItems.whereType<Map<String, dynamic>>().toList();
      }

      final fromNotifications = data['notifications'];
      if (fromNotifications is List) {
        return fromNotifications.whereType<Map<String, dynamic>>().toList();
      }

      final nestedData = data['data'];
      if (nestedData is List) {
        return nestedData.whereType<Map<String, dynamic>>().toList();
      }
      if (nestedData is Map<String, dynamic>) {
        final nestedItems = nestedData['items'];
        if (nestedItems is List) {
          return nestedItems.whereType<Map<String, dynamic>>().toList();
        }
        final nestedNotifications = nestedData['notifications'];
        if (nestedNotifications is List) {
          return nestedNotifications.whereType<Map<String, dynamic>>().toList();
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> item) {
    final data = _extractDataPayload(item);

    final module = '${data['module'] ?? item['module'] ?? ''}'.toLowerCase();

    return {
      'id':
          '${item['id'] ?? item['notificationId'] ?? DateTime.now().microsecondsSinceEpoch}',
      'title': '${item['title'] ?? 'Notifikasi'}',
      'body': '${item['body'] ?? item['message'] ?? '-'}',
      'isRead': item['isRead'] == true || item['is_read'] == 1,
      'createdAt': _toReadableDate(
        '${item['createdAt'] ?? item['created_at'] ?? DateTime.now().toIso8601String()}',
      ),
      'targetRoute': _resolveTargetRoute(module),
    };
  }

  Map<String, dynamic> _extractDataPayload(Map<String, dynamic> item) {
    final direct = item['data'];
    if (direct is Map<String, dynamic>) return direct;

    final payload = item['dataPayload'] ?? item['data_payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    return <String, dynamic>{};
  }

  String _resolveTargetRoute(String module) {
    if (module.contains('wo')) return '/work-orders';
    if (module.contains('warehouse')) return '/warehouse';
    if (module.contains('countdown')) return '/countdown';
    if (module.contains('qc')) return '/qc';
    if (module.contains('job_plan')) return '/plans';
    if (module.contains('task')) return '/tasks';
    return '/notifications';
  }

  String _toReadableDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}
