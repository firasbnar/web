import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/product.dart';

class PosProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final List<Product> _cartItems = [];
  Map<String, dynamic>? _activeSession;
  bool _loading = false;
  String? _error;

  List<Product> get cartItems => _cartItems;
  Map<String, dynamic>? get activeSession => _activeSession;
  bool get loading => _loading;
  String? get error => _error;

  double get cartTotal => _cartItems.fold(0, (sum, item) => sum + item.price);

  void addToCart(Product product) {
    _cartItems.add(product);
    notifyListeners();
  }

  void removeFromCart(int index) {
    _cartItems.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  Future<bool> openSession(String boutiqueId, double openingCash) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.post('/pos/sessions/open', data: {'boutiqueId': boutiqueId, 'openingCash': openingCash});
      _activeSession = res['data'];
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString(); _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> closeSession(String sessionId, double closingCash) async {
    _loading = true; notifyListeners();
    try {
      await _api.post('/pos/sessions/$sessionId/close', data: {'closingCash': closingCash});
      _activeSession = null;
      _loading = false; notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString(); _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> loadActiveSession(String boutiqueId) async {
    try {
      final res = await _api.get('/pos/sessions/active', queryParameters: {'boutiqueId': boutiqueId});
      _activeSession = res['data'];
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> createTransaction(String sessionId, List<Map<String, dynamic>> items, String paymentMethod, double total) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.post('/pos/transactions', data: {
        'sessionId': sessionId, 'items': items, 'paymentMethod': paymentMethod, 'total': total,
      });
      _loading = false; notifyListeners();
      return res['data'];
    } catch (e) {
      _error = e.toString(); _loading = false; notifyListeners();
      return null;
    }
  }
}
