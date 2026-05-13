import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  Cart? _cart;
  bool _loading = false;
  String? _error;

  Cart? get cart => _cart;
  bool get loading => _loading;
  String? get error => _error;
  int get itemCount => _cart?.itemCount ?? 0;
  double get subtotal => _cart?.subtotal ?? 0;
  List<CartItem> get items => _cart?.items ?? [];

  Future<void> loadCart(String boutiqueId) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/cart', queryParameters: {'boutiqueId': boutiqueId});
      _cart = Cart.fromJson(res['data']);
      _loading = false; notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); _loading = false; notifyListeners();
    }
  }

  Future<bool> addItem(String boutiqueId, String productId, int quantity) async {
    try {
      final res = await _api.post('/cart', data: {
        'boutiqueId': boutiqueId, 'productId': productId, 'quantity': quantity,
      });
      _cart = Cart.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  Future<bool> updateItem(String itemId, int quantity) async {
    try {
      final res = await _api.put('/cart/$itemId', data: {'quantity': quantity});
      _cart = Cart.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem(String itemId) async {
    try {
      final res = await _api.delete('/cart/$itemId');
      _cart = Cart.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  Future<bool> clearCart(String boutiqueId) async {
    try {
      await _api.delete('/cart', queryParameters: {'boutiqueId': boutiqueId});
      _cart = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }
}
