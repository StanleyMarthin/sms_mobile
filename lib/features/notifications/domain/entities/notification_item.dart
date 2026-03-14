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
}