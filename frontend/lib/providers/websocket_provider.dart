import 'dart:async';
import 'dart:developer' as dev;
import '../services/websocket_service.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'package:flutter/material.dart';
import 'messages_provider.dart';

class WebSocketProvider extends ChangeNotifier {
  final WebSocketService _service = WebSocketService();
  bool _connected = false;
  StreamSubscription? _messageSub;
  StreamSubscription? _storeConvSub;
  StreamSubscription? _conversationSub;
  StreamSubscription? _connectionSub;
  MessagesProvider? _messagesProvider;

  bool get isConnected => _connected;

  Future<void> connect(String boutiqueId, MessagesProvider messagesProvider) async {
    _messagesProvider = messagesProvider;
    await _service.connect(boutiqueId);
    _connected = _service.isConnected;
    dev.log('[WS Provider] connect() done, client connected=$_connected');

    // Listen for connection changes
    _connectionSub?.cancel();
    _connectionSub = _service.onConnectionChange.listen((connected) {
      if (connected != _connected) {
        dev.log('[WS Provider] Connection state changed: $_connected -> $connected');
        _connected = connected;
        notifyListeners();
      }
    });

    // Listen for conversation list updates from /topic/messages/{boutiqueId}
    _messageSub?.cancel();
    _messageSub = _service.onNewMessage.listen((data) {
      try {
        dev.log('[WS Provider] Received conversation update via /topic/messages: id=${data['id']} name=${data['customerName']} unread=${data['unreadCount']}');
        final conv = Conversation.fromJson(data);
        _messagesProvider?.addConversationFromSocket(conv);
      } catch (e) {
        dev.log('[WS Provider] Error parsing onNewMessage: $e');
      }
    });

    // Listen for conversation alerts from /topic/stores/{storeId}/conversations
    _storeConvSub?.cancel();
    _storeConvSub = _service.onStoreConversations.listen((data) {
      try {
        final type = data['type'] ?? '';
        final convId = data['conversationId']?.toString() ?? '';
        final name = data['customerName'] ?? '';
        dev.log('[WS Provider] Store conversation alert: type=$type convId=$convId name=$name');
        if (convId.isNotEmpty && type == 'NEW_CONVERSATION') {
          dev.log('[WS Provider] Refreshing conversation $convId via store alert');
          _messagesProvider?.refreshConversation(convId);
        }
      } catch (e) {
        dev.log('[WS Provider] Error parsing onStoreConversations: $e');
      }
    });

    // Listen for real-time conversation messages from /topic/conversations/{conversationId}
    _conversationSub?.cancel();
    _conversationSub = _service.onConversationMessage.listen((data) {
      try {
        dev.log('[WS Provider] Received message via /topic/conversations: type=${data['type']} sender=${data['senderType']}');
        final msg = Message.fromJson(data);
        _messagesProvider?.addMessageFromSocket(msg);
      } catch (e) {
        dev.log('[WS Provider] Error parsing onConversationMessage: $e');
      }
    });

    notifyListeners();
  }

  void subscribeToConversation(String conversationId) {
    _service.subscribeToConversation(conversationId);
  }

  void unsubscribeConversation() {
    _service.unsubscribeConversation();
  }

  void disconnect() {
    _connectionSub?.cancel();
    _messageSub?.cancel();
    _storeConvSub?.cancel();
    _conversationSub?.cancel();
    _service.disconnect();
    _connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
