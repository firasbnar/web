import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class MessagesProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  bool _loadingConversations = false;
  bool _loadingMessages = false;
  String? _error;

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get loadingConversations => _loadingConversations;
  bool get loadingMessages => _loadingMessages;
  String? get error => _error;

  int get unreadCount => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  Future<void> loadConversations(String boutiqueId) async {
    _loadingConversations = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get('/messages', queryParameters: {'boutiqueId': boutiqueId});
      final List data = res['data'] ?? [];
      _conversations = data.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    _loadingConversations = false;
    notifyListeners();
  }

  Future<void> loadMessages(String conversationId) async {
    _loadingMessages = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get('/messages/$conversationId');
      final List data = res['data'] ?? [];
      _messages = data.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    _loadingMessages = false;
    notifyListeners();
  }

  Future<bool> sendMessage({
    required String boutiqueId,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    required String content,
  }) async {
    try {
      await _api.post('/messages/public', queryParameters: {'boutiqueId': boutiqueId}, data: {
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'content': content,
      });
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> replyToConversation({
    required String boutiqueId,
    required String conversationId,
    required String content,
  }) async {
    try {
      final res = await _api.post('/messages/reply', queryParameters: {'boutiqueId': boutiqueId}, data: {
        'conversationId': conversationId,
        'content': content,
      });
      final msg = Message.fromJson(res['data'] as Map<String, dynamic>);
      _addOrUpdateMessage(msg);
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _api.put('/messages/$conversationId/read');
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx >= 0) {
        final old = _conversations[idx];
        _conversations[idx] = Conversation(
          id: old.id,
          boutiqueId: old.boutiqueId,
          customerName: old.customerName,
          customerEmail: old.customerEmail,
          customerPhone: old.customerPhone,
          lastMessageAt: old.lastMessageAt,
          lastMessagePreview: old.lastMessagePreview,
          unreadCount: 0,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  void addConversationFromSocket(Conversation conversation) {
    final idx = _conversations.indexWhere((c) => c.id == conversation.id);
    if (idx >= 0) {
      _conversations[idx] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    notifyListeners();
  }

  void refreshConversation(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      final old = _conversations[idx];
      _conversations[idx] = Conversation(
        id: old.id,
        boutiqueId: old.boutiqueId,
        customerName: old.customerName,
        customerEmail: old.customerEmail,
        customerPhone: old.customerPhone,
        lastMessageAt: old.lastMessageAt,
        lastMessagePreview: old.lastMessagePreview,
        unreadCount: old.unreadCount + 1,
        createdAt: old.createdAt,
      );
    }
    notifyListeners();
  }

  void addMessageFromSocket(Message message) {
    if (message.id.isNotEmpty && _messages.any((m) => m.id == message.id)) {
      return;
    }
    _messages.add(message);
    notifyListeners();
  }

  void _addOrUpdateMessage(Message message) {
    if (message.id.isNotEmpty) {
      final idx = _messages.indexWhere((m) => m.id == message.id);
      if (idx >= 0) {
        _messages[idx] = message;
        notifyListeners();
        return;
      }
    }
    _messages.add(message);
    notifyListeners();
  }
}
