import 'package:flutter/material.dart';
import '../core/api_client.dart';

class AiProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> get messages => _messages;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> sendMessage(String message) async {
    _messages.add({'role': 'user', 'content': message});
    _loading = true; notifyListeners();
    try {
      final res = await _api.post('/ai/chat', data: {'message': message});
      final data = res['data'];
      _messages.add({'role': 'assistant', 'content': data['reply']});
      _loading = false; notifyListeners();
    } catch (e) {
      _messages.add({'role': 'assistant', 'content': 'Désolé, une erreur est survenue.'});
      _error = e.toString();
      _loading = false; notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    try {
      final res = await _api.get('/ai/history');
      _messages = (res['data'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      await _api.delete('/ai/history');
      _messages.clear();
      notifyListeners();
    } catch (_) {}
  }
}
