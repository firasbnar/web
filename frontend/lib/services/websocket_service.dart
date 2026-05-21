import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/env_config.dart';
import '../core/storage.dart';

class WebSocketService {
  StompClient? _client;
  final _storage = AppStorage();
  final StreamController<Map<String, dynamic>> _orderController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caisseStatsController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caisseOrdersController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _caisseActivitiesController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _activityController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _securityController = StreamController.broadcast();
  bool _connected = false;

  Stream<Map<String, dynamic>> get onNewOrder => _orderController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onCaisseStats => _caisseStatsController.stream;
  Stream<Map<String, dynamic>> get onCaisseOrders => _caisseOrdersController.stream;
  Stream<Map<String, dynamic>> get onCaisseActivities => _caisseActivitiesController.stream;
  Stream<Map<String, dynamic>> get onActivity => _activityController.stream;
  Stream<Map<String, dynamic>> get onPresence => _presenceController.stream;
  Stream<Map<String, dynamic>> get onSecurity => _securityController.stream;

  Future<void> connect(String boutiqueId) async {
    final token = await _storage.getAccessToken();
    if (token == null) return;

    _client = StompClient(
      config: StompConfig(
        url: EnvConfig.wsUrl,
        onConnect: (frame) {
          _connected = true;
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
                  _messageController.add(data);
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
        onDisconnect: (_) => _connected = false,
        onStompError: (_) => _connected = false,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _connected = false;
  }

  bool get isConnected => _connected;

  void dispose() {
    disconnect();
    _orderController.close();
    _messageController.close();
    _caisseStatsController.close();
    _caisseOrdersController.close();
    _caisseActivitiesController.close();
    _activityController.close();
    _presenceController.close();
    _securityController.close();
  }
}
