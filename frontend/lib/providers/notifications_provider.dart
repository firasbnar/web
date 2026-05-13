import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/notification.dart';

class NotificationsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<AppNotification> _notifications = [];
  bool _loading = false;
  int _unreadCount = 0;

  List<AppNotification> get notifications => _notifications;
  bool get loading => _loading;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications({bool refresh = false}) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/notifications', queryParameters: {'page': 0, 'size': 50});
      final data = res['data'];
      final List content = data['content'] ?? [];
      _notifications = content.map((e) => AppNotification.fromJson(e)).toList();
      _loading = false; notifyListeners();
    } catch (_) { _loading = false; notifyListeners(); }
  }

  Future<void> loadUnreadCount() async {
    try {
      final res = await _api.get('/notifications/unread-count');
      _unreadCount = (res['data'] as num).toInt();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.put('/notifications/$id/read');
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx >= 0) {
        _notifications[idx] = AppNotification(
          id: _notifications[idx].id,
          title: _notifications[idx].title,
          body: _notifications[idx].body,
          isRead: true,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.put('/notifications/read-all');
      _unreadCount = 0;
      _notifications = _notifications.map((n) => AppNotification(
        id: n.id, title: n.title, body: n.body, isRead: true,
      )).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _api.delete('/notifications/$id');
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (_) {}
  }
}
