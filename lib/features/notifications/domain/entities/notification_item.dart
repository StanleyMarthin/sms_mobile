/*
Tujuan: Entity read model notifikasi mobile termasuk kategori Job Plan V2.
Caller: NotificationsRepository, NotificationInboxService, NotificationsPage.
Dependensi: Tidak ada.
Main Functions: NotificationItem, fromMap, copyWith.
Side Effects: Tidak ada.
*/
library;

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.targetRoute,
    String? category,
  }) : category = category ?? 'general';

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;
  final String targetRoute;
  final String category;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    bool? isRead,
    String? createdAt,
    String? targetRoute,
    String? category,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      targetRoute: targetRoute ?? this.targetRoute,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': createdAt,
      'targetRoute': targetRoute,
      'category': category,
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? 'Notifikasi'}',
      body: '${map['body'] ?? '-'}',
      isRead: map['isRead'] == true,
      createdAt: '${map['createdAt'] ?? DateTime.now().toIso8601String()}',
      targetRoute: '${map['targetRoute'] ?? '/notifications'}',
      category: _category(map),
    );
  }

  static String _category(Map<String, dynamic> map) {
    final explicit = '${map['category'] ?? ''}'.trim().toLowerCase();
    if (explicit.isNotEmpty && explicit != 'null') return explicit;

    final event = '${map['eventType'] ?? map['event_type'] ?? ''}'
        .trim()
        .toUpperCase();
    if ({
      'PLAN_WAITING_APPROVAL',
      'WAITING_APPROVAL',
      'PLAN_APPROVED',
      'APPROVED',
      'PLAN_REJECTED',
      'REJECTED',
      'ADJUSTMENT_REQUESTED',
      'ADJUSTMENT_KP_APPROVED',
      'ADJUSTMENT_MO_REVIEW_REQUIRED',
      'ADJUSTMENT_APPROVED',
      'ADJUSTMENT_REJECTED',
    }.contains(event)) {
      return 'approval';
    }
    if ({
      'SCHEDULE_CHANGED',
      'PIC_CHANGED',
      'DEADLINE_CHANGED',
      'PLAN_CORRECTED',
    }.contains(event)) {
      return 'job_plan';
    }
    if ({'TASK_READY', 'STARTED', 'FINISHED'}.contains(event)) {
      return 'execution';
    }
    if (event == 'VALIDATION_REQUESTED' || event == 'KD_VALIDATED') {
      return 'validation';
    }
    return 'general';
  }
}
