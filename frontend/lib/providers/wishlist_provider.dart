import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/wishlist_item.dart';

class WishlistProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<WishlistItem> _items = [];
  bool _loading = false;
  String? _error;
  int _count = 0;

  List<WishlistItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  int get count => _count;

  Future<void> loadWishlist() async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/wishlist');
      _items = (res['data'] as List).map((e) => WishlistItem.fromJson(e)).toList();
      _count = _items.length;
      _loading = false; notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); _loading = false; notifyListeners();
    }
  }

  Future<bool> toggle(String productId) async {
    try {
      final res = await _api.post('/wishlist', data: {'productId': productId});
      if (res['data'] == null) {
        _items.removeWhere((i) => i.productId == productId);
      } else {
        _items.insert(0, WishlistItem.fromJson(res['data']));
      }
      _count = _items.length;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }

  Future<bool> isInWishlist(String productId) async {
    try {
      final res = await _api.get('/wishlist/check', queryParameters: {'productId': productId});
      return res['data'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadCount() async {
    try {
      final res = await _api.get('/wishlist/count');
      _count = (res['data'] as num).toInt();
      notifyListeners();
    } catch (_) {}
  }
}
