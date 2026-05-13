import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/product.dart';

class ProductsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  String _search = '';
  String? _categoryFilter;
  final int _pageSize = 20;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String get search => _search;

  Future<void> loadProducts(String boutiqueId, {bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _products = [];
      _hasMore = true;
    }
    if (!_hasMore || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final params = <String, dynamic>{
        'boutiqueId': boutiqueId,
        'page': _currentPage,
        'size': _pageSize,
      };
      if (_search.isNotEmpty) params['search'] = _search;
      if (_categoryFilter != null) params['categoryId'] = _categoryFilter;
      final res = await _api.get('/products', queryParameters: params);
      final data = res['data'];
      final List content = data['content'] ?? [];
      _products.addAll(content.map((e) => Product.fromJson(e)).toList());
      _hasMore = data['last'] != true && content.length >= _pageSize;
      _currentPage++;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories(String boutiqueId) async {
    try {
      final res = await _api
          .get('/categories', queryParameters: {'boutiqueId': boutiqueId});
      _categories =
          (res['data'] as List).map((e) => Category.fromJson(e)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<Product?> getProduct(String id) async {
    try {
      final res = await _api.get('/products/$id');
      final product = Product.fromJson(res['data']);
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        _products[idx] = product;
      } else {
        _products.insert(0, product);
      }
      notifyListeners();
      return product;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  void setSearch(String query, String boutiqueId) {
    _search = query;
    loadProducts(boutiqueId, refresh: true);
  }

  void setCategoryFilter(String? categoryId, String boutiqueId) {
    _categoryFilter = categoryId;
    loadProducts(boutiqueId, refresh: true);
  }

  Future<Product?> createProduct(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/products', data: data);
      final product = Product.fromJson(res['data']);
      _products.insert(0, product);
      notifyListeners();
      return product;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<Product?> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/products/$id', data: data);
      final product = Product.fromJson(res['data']);
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) _products[idx] = product;
      notifyListeners();
      return product;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _api.delete('/products/$id');
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActive(String id) async {
    try {
      final res = await _api.put('/products/$id/toggle-active');
      final product = Product.fromJson(res['data']);
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) _products[idx] = product;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<Category?> createCategory(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/categories', data: data);
      final category = Category.fromJson(res['data']);
      _categories.add(category);
      _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      notifyListeners();
      return category;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<Category?> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/categories/$id', data: data);
      final category = Category.fromJson(res['data']);
      final idx = _categories.indexWhere((c) => c.id == id);
      if (idx >= 0) _categories[idx] = category;
      _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      notifyListeners();
      return category;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await _api.delete('/categories/$id');
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }
}
