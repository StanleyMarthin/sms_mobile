library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalMockApiStore {
  LocalMockApiStore();

  static final jobPlansKey = 'mock_api_job_plans';
  static final taskExecutionKey = 'mock_api_task_execution';
  static final taskViewKey = 'mock_api_task_view';
  static final qcItemsKey = 'mock_api_qc_items';
  static final warehouseLogsKey = 'mock_api_warehouse_logs';
  static final workOrdersKey = 'mock_api_work_orders';
  static final countdownUnitsKey = 'mock_api_countdown_units';
  static final countdownItemsKey = 'mock_api_countdown_items';
  static final countdownDetailsKey = 'mock_api_countdown_details';
  static final notificationsKey = 'mock_api_notifications';
  static final monitoringCarsKey = 'mock_api_monitoring_cars';

  Future<List<Map<String, dynamic>>> readList({
    required String key,
    required List<Map<String, dynamic>> Function() seedBuilder,
  }) async {
    final raw = await _readRaw(
      key: key,
      seedBuilder: () => _normalize(seedBuilder()) as List<dynamic>,
    );
    return (raw as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(_deepCopyMap)
        .toList();
  }

  Future<void> writeList({
    required String key,
    required List<Map<String, dynamic>> value,
  }) async {
    await _writeRaw(key: key, value: value);
  }

  Future<Map<String, List<Map<String, dynamic>>>> readGroupedList({
    required String key,
    required Map<String, List<Map<String, dynamic>>> Function() seedBuilder,
  }) async {
    final raw = await _readRaw(
      key: key,
      seedBuilder: () => _normalize(seedBuilder()) as Map<String, dynamic>,
    );
    final map = Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);
    return map.map(
      (groupKey, value) => MapEntry(
        groupKey,
        (value as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(_deepCopyMap)
            .toList(),
      ),
    );
  }

  Future<void> writeGroupedList({
    required String key,
    required Map<String, List<Map<String, dynamic>>> value,
  }) async {
    await _writeRaw(key: key, value: value);
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<dynamic> _readRaw({
    required String key,
    required dynamic Function() seedBuilder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);
    if (stored == null || stored.isEmpty) {
      final seeded = seedBuilder();
      await prefs.setString(key, jsonEncode(seeded));
      return jsonDecode(jsonEncode(seeded));
    }
    return jsonDecode(stored);
  }

  Future<void> _writeRaw({
    required String key,
    required Object value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(_normalize(value)));
  }

  static Map<String, dynamic> _deepCopyMap(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
    );
  }

  static Object? _normalize(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _normalize(item)),
      );
    }
    if (value is List) {
      return value.map(_normalize).toList();
    }
    return value;
  }
}