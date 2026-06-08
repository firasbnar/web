import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/message.dart';

class PublicMessagesProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Message> _messages = [];
  bool _loading = false;
  String? _error;
  String? _conversationId;
  String? _guestToken;
  String? _customerName;

  List<Message> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;
  String? get conversationId => _conversationId;
  String? get guestToken => _guestToken;
  String? get customerName => _customerName;
  bool get hasActiveConversation => _conversationId != null && _guestToken != null;

  static String _storageKey(String storeSlug) => 'guest_chat_${storeSlug}';

  Future<void> loadFromStorage(String storeSlug) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey(storeSlug));
    if (stored != null && stored.isNotEmpty) {
      try {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        _conversationId = data['conversationId']?.toString();
        _guestToken = data['guestToken']?.toString();
        _customerName = data['customerName']?.toString();
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> _saveToStorage(String storeSlug) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'conversationId': _conversationId,
      'guestToken': _guestToken,
      'customerName': _customerName,
    });
    await prefs.setString(_storageKey(storeSlug), data);
  }

  Future<bool> sendGuestMessage({
    required String slug,
    required String customerName,
    String? email,
    String? phone,
    required String message,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.post('/public/stores/$slug/messages', data: {
        'customerName': customerName,
        'email': email,
        'phone': phone,
        'message': message,
      });

      _conversationId = res['conversationId']?.toString();
      _guestToken = res['guestToken']?.toString();
      _customerName = customerName;

      await _saveToStorage(slug);

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadConversation() async {
    if (_conversationId == null || _guestToken == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.get(
        '/public/conversations/$_conversationId',
        queryParameters: {'token': _guestToken},
      );

      final List messagesData = res['messages'] ?? [];
      _messages = messagesData
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> sendReply(String content) async {
    if (_conversationId == null || _guestToken == null) return false;

    try {
      final res = await _api.post(
        '/public/conversations/$_conversationId/reply',
        queryParameters: {'token': _guestToken},
        data: {'message': content},
      );

      final msgData = res['data'] as Map<String, dynamic>?;
      if (msgData != null) {
        _messages.add(Message.fromJson(msgData));
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> clear(String storeSlug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(storeSlug));
    _messages = [];
    _conversationId = null;
    _guestToken = null;
    _customerName = null;
    _error = null;
    notifyListeners();
  }
}
