class Message {
  final String id;
  final String conversationId;
  final String senderType;
  final String content;
  final bool isRead;
  final String? createdAt;

  Message({
    this.id = '',
    required this.conversationId,
    required this.senderType,
    required this.content,
    this.isRead = false,
    this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['messageId']?.toString() ?? json['id']?.toString() ?? '',
    conversationId: (json['conversationId'] ?? '').toString(),
    senderType: json['senderType'] ?? 'CUSTOMER',
    content: json['content'] ?? '',
    isRead: json['isRead'] ?? false,
    createdAt: json['createdAt'],
  );
}
