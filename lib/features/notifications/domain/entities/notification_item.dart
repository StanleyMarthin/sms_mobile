library;

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.targetRoute,
  });

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;
  final String targetRoute;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    bool? isRead,
    String? createdAt,
    String? targetRoute,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      targetRoute: targetRoute ?? this.targetRoute,
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
    );
  }
}
