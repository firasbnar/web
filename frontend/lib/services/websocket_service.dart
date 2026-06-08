import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/env_config.dart';
import '../core/storage.dart';

class WebSocketService {
  StompClient? _client;
  final _storage = AppStorage();
  final StreamController<Map<String, dynamic>> _orderController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _storeConversationsController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caisseStatsController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caisseOrdersController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caisseActivitiesController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _activityController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _securityController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _conversationController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  bool _connected = false;
  dynamic _conversationSub;
  String? _pendingConversationId;

  Stream<Map<String, dynamic>> get onNewOrder => _orderController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onStoreConversations => _storeConversationsController.stream;
  Stream<Map<String, dynamic>> get onCaisseStats => _caisseStatsController.stream;
  Stream<Map<String, dynamic>> get onCaisseOrders => _caisseOrdersController.stream;
  Stream<Map<String, dynamic>> get onCaisseActivities => _caisseActivitiesController.stream;
  Stream<Map<String, dynamic>> get onActivity => _activityController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onSecurity => _securityController.stream;
  Stream<Map<String, dynamic>> get onConversationMessage => _conversationController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  Future<void> connect(String boutiqueId) async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      dev.log('[WS] No token available, skipping WebSocket connect');
      return;
    }

    // Disconnect previous client before creating a new one
    if (_client != null) {
      dev.log('[WS] Disconnecting previous client');
      _client!.deactivate();
      _client = null;
    }

    dev.log('[WS] Connecting to ${EnvConfig.wsUrl} with SockJS for boutique=$boutiqueId');
    _client = StompClient(
      config: StompConfig(
        url: EnvConfig.wsUrl,
        useSockJS: true,
        onConnect: (frame) {
          _connected = true;
          _connectionController.add(true);
          dev.log('[WS] Connected to WebSocket');
          dev.log('[WS] Subscribed to /topic/messages/$boutiqueId');
          dev.log('[WS] Subscribed to /topic/stores/$boutiqueId/conversations');
          if (_pendingConversationId != null) {
            dev.log('[WS] Pending conversation subscription: $_pendingConversationId');
            _subscribeToConversation(_pendingConversationId!);
            _pendingConversationId = null;
          }
          _client!.subscribe(
            destination: '/topic/orders/$boutiqueId',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _orderController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/messages/$boutiqueId',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  dev.log('[WS] Received /topic/messages/$boutiqueId: convId=${data['id']} name=${data['customerName']} unread=${data['unreadCount']}');
                  _messageController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/stores/$boutiqueId/conversations',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  dev.log('[WS] Received /topic/stores/$boutiqueId/conversations: type=${data['type']} convId=${data['conversationId']}');
                  _storeConversationsController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/caisse/$boutiqueId/stats',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _caisseStatsController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/caisse/$boutiqueId/orders',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _caisseOrdersController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/caisse/$boutiqueId/activities',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _caisseActivitiesController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/activity',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _activityController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/presence',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _presenceController.add(data);
                } catch (_) {}
              }
            },
          );
          _client!.subscribe(
            destination: '/topic/security',
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  _securityController.add(data);
                } catch (_) {}
              }
            },
          );
        },
        onDisconnect: (_) {
          _connected = false;
          _connectionController.add(false);
          dev.log('[WS] Disconnected from WebSocket');
        },
        onStompError: (_) {
          _connected = false;
          _connectionController.add(false);
          dev.log('[WS] STOMP error');
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void subscribeToConversation(String conversationId) {
    if (_client == null || !_connected) {
      _pendingConversationId = conversationId;
      dev.log('[WS] WS not connected, queued conversation subscription for $conversationId');
      return;
    }
    _subscribeToConversation(conversationId);
  }

  void _subscribeToConversation(String conversationId) {
    _conversationSub?.unsubscribe();
    dev.log('[WS] Subscribed to /topic/conversations/$conversationId');
    _conversationSub = _client!.subscribe(
      destination: '/topic/conversations/$conversationId',
      callback: (frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!) as Map<String, dynamic>;
            dev.log('[WS] Received message on /topic/conversations/$conversationId: senderType=${data['senderType']} content=${data['content']}');
            _conversationController.add(data);
          } catch (_) {}
        }
      },
    );
  }

  void unsubscribeConversation() {
    _conversationSub?.unsubscribe();
    _conversationSub = null;
  }

  void disconnect() {
    unsubscribeConversation();
    _client?.deactivate();
    _client = null;
    _connected = false;
  }

  bool get isConnected => _connected;

  void dispose() {
    disconnect();
    _orderController.close();
    _messageController.close();
    _storeConversationsController.close();
    _caisseStatsController.close();
    _caisseOrdersController.close();
    _caisseActivitiesController.close();
    _activityController.close();
    _presenceController.close();
    _securityController.close();
    _conversationController.close();
    _connectionController.close();
  }
}
