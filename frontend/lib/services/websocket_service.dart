import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/storage.dart';

class WebSocketService {
  StompClient? _client;
  final _storage = AppStorage();
  final StreamController<Map<String, dynamic>> _orderController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  bool _connected = false;

  Stream<Map<String, dynamic>> get onNewOrder => _orderController.stream;
  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;

  Future<void> connect(String boutiqueId) async {
    final token = await _storage.getAccessToken();
    if (token == null) return;

    _client = StompClient(
      config: StompConfig(
        url: 'http://localhost:8080/ws',
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
  }
}
