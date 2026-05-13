class AppNotification {
  final String id;
  final String title;
  final String? body;
  final String? type;
  final bool isRead;
  final String? createdAt;

  AppNotification({required this.id, required this.title, this.body, this.type, this.isRead = false, this.createdAt});

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'].toString(),
    title: json['title'] ?? '',
    body: json['body'],
    type: json['type'],
    isRead: json['isRead'] ?? false,
    createdAt: json['createdAt'],
  );
}
