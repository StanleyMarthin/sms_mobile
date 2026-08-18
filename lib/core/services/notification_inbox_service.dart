import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/domain/entities/notification_item.dart';
import '../security/app_secure_storage.dart';
import '../session/session_manager.dart';

class NotificationInboxService extends ChangeNotifier {
  NotificationInboxService({this.storage = AppSecureStorage.instance});

  static const String _storagePrefix = 'notification_inbox_';
  final dynamic storage;

  List<NotificationItem> _items = [];
  String? _activeStorageKey;

  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((item) => !item.isRead).length;
  bool get hasUnread => unreadCount > 0;

  Future<void> init() async {
    await ensureLoaded();
  }

  Future<void> ensureLoaded() async {
    final storageKey = await _resolveStorageKey();
    if (_activeStorageKey == storageKey && _items.isNotEmpty) return;
    await _loadFromKey(storageKey);
  }

  Future<void> saveRemoteMessage(RemoteMessage message) async {
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    final data = Map<String, dynamic>.from(message.data);
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _upsertItem(
      _itemFromPayload(
        id: _buildMessageId(
          messageId: message.messageId,
          data: data,
          title: title,
          body: body,
          sentTime: message.sentTime,
        ),
        title: title ?? 'Notifikasi',
        body: body ?? '-',
        createdAt: message.sentTime ?? DateTime.now(),
        data: data,
      ),
    );
  }

  Future<void> markAllRead() async {
    await ensureLoaded();
    if (_items.isEmpty || _items.every((item) => item.isRead)) return;
    _items = _items
        .map((item) => item.isRead ? item : item.copyWith(isRead: true))
        .toList(growable: false);
    await _persistCurrent();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    _items = [];
    await _persistCurrent();
    notifyListeners();
  }

  static Future<void> persistBackgroundMessage(RemoteMessage message) async {
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveStorageKeyStatic(prefs);
    final raw = prefs.getString(key);
    final decoded = _decodeItems(raw);
    final data = Map<String, dynamic>.from(message.data);
    final item = _itemFromPayload(
      id: _buildMessageId(
        messageId: message.messageId,
        data: data,
        title: title,
        body: body,
        sentTime: message.sentTime,
      ),
      title: title ?? 'Notifikasi',
      body: body ?? '-',
      createdAt: message.sentTime ?? DateTime.now(),
      data: data,
    );
    final exists = decoded.any((entry) => entry.id == item.id);
    if (exists) return;
    decoded.insert(0, item);
    await prefs.setString(
      key,
      jsonEncode(decoded.map((entry) => entry.toMap()).toList()),
    );
  }

  static String resolveRoute(Map<String, dynamic> data) {
    final module = '${data['module'] ?? data['type'] ?? ''}'.toLowerCase();
    final woId = _pickFirst(data, ['reqId', 'woId']);
    final taskId = _pickFirst(data, ['plandailyId', 'taskId']);
    final qcId = _pickFirst(data, ['coreId', 'qcId']);
    final carId = _pickFirst(data, ['carId', 'unitId']);

    if (module.contains('warehouse')) {
      return '/warehouse';
    }
    if (module == 'wo' || module == 'wo_ext' || module.contains('wo')) {
      return woId == null
          ? '/work-orders'
          : '/work-orders?woId=${Uri.encodeComponent(woId)}';
    }
    if (module.contains('job_plan')) {
      return '/plans';
    }
    if (module == 'qc' || module.contains('qc')) {
      return qcId == null ? '/qc' : '/qc?qcId=${Uri.encodeComponent(qcId)}';
    }
    if (module.contains('task')) {
      return taskId == null
          ? '/tasks'
          : '/tasks?taskId=${Uri.encodeComponent(taskId)}';
    }
    if (module.contains('countdown') || module.contains('revision')) {
      return carId == null
          ? '/countdown'
          : '/countdown?carId=${Uri.encodeComponent(carId)}';
    }
    if (module.contains('pr')) {
      final reqId = _pickFirst(data, ['reqId']);
      return reqId == null ? '/pr' : '/pr?reqId=${Uri.encodeComponent(reqId)}';
    }
    if (module.contains('wov')) {
      final reqId = _pickFirst(data, ['reqId']);
      return reqId == null ? '/wov' : '/wov?reqId=${Uri.encodeComponent(reqId)}';
    }
    return '/notifications';
  }

  Future<void> _upsertItem(NotificationItem item) async {
    await ensureLoaded();
    final exists = _items.any((entry) => entry.id == item.id);
    if (exists) return;
    _items = [item, ..._items];
    await _persistCurrent();
    notifyListeners();
  }

  Future<void> _loadFromKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _activeStorageKey = key;
    _items = _decodeItems(prefs.getString(key))
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _activeStorageKey ?? await _resolveStorageKey();
    _activeStorageKey = key;
    await prefs.setString(
      key,
      jsonEncode(_items.map((item) => item.toMap()).toList()),
    );
  }

  Future<String> _resolveStorageKey() async {
    return _resolveStorageKeyStatic(storage);
  }

  static Future<String> _resolveStorageKeyStatic(dynamic storage) async {
    final userId = ((await storage.read(key: SessionManager.keyUserId)) ?? '').trim();
    final employeeId =
        ((await storage.read(key: SessionManager.keyEmployeeId)) ?? '').trim();
    final suffix = userId.isNotEmpty
        ? userId
        : employeeId.isNotEmpty
            ? employeeId
            : 'guest';
    return '$_storagePrefix$suffix';
  }

  static List<NotificationItem> _decodeItems(String? raw) {
    if (raw == null || raw.isEmpty) return <NotificationItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <NotificationItem>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(NotificationItem.fromMap)
          .toList(growable: false);
    } catch (_) {
      return <NotificationItem>[];
    }
  }

  static NotificationItem _itemFromPayload({
    required String id,
    required String title,
    required String body,
    required DateTime createdAt,
    required Map<String, dynamic> data,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      isRead: false,
      createdAt: createdAt.toIso8601String(),
      targetRoute: resolveRoute(data),
    );
  }

  static String _buildMessageId({
    required String? messageId,
    required Map<String, dynamic> data,
    required String? title,
    required String? body,
    required DateTime? sentTime,
  }) {
    if (messageId != null && messageId.trim().isNotEmpty) {
      return messageId.trim();
    }
    final primaryId = _pickFirst(
      data,
      [
        'id',
        'reqId',
        'logId',
        'plandailyId',
        'planId',
        'coreId',
        'countdownId'
      ],
    );
    final seed = [
      '${data['module'] ?? data['type'] ?? 'general'}',
      primaryId ?? '',
      title ?? '',
      body ?? '',
      '${sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
    ].join('|');
    return seed;
  }

  static String? _pickFirst(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = '${data[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}
