class Conversation {
  final String id;
  final String boutiqueId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final String? createdAt;

  Conversation({
    required this.id,
    required this.boutiqueId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'].toString(),
    boutiqueId: json['boutiqueId'].toString(),
    customerName: json['customerName'] ?? '',
    customerEmail: json['customerEmail'] ?? '',
    customerPhone: json['customerPhone'],
    lastMessageAt: json['lastMessageAt'],
    lastMessagePreview: json['lastMessagePreview'],
    unreadCount: json['unreadCount'] ?? 0,
    createdAt: json['createdAt'],
  );
}
